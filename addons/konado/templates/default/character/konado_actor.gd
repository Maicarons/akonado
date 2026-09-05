@tool
extends Control
class_name KonadoActor

## Konado对话角色类，用于在对话中显示角色

## 演员进场动画完成信号
signal actor_entered
## 演员退场动画完成信号
signal actor_exited
## 演员移动动画完成信号
signal actor_moved
## 演员舞台动作开始信号
signal actor_motion_started(motion_name: String)
## 演员舞台动作完成信号
signal actor_motion_finished(motion_name: String)
## 角色状态转场开始
signal actor_status_change_started(status_name: String)
## 角色状态已应用；淡入动画可能仍在进行
signal actor_status_applied(status_name: String)
## 角色状态转场被后续请求或生命周期操作取消
signal actor_status_change_cancelled(status_name: String)
## 角色状态转场完成
signal actor_status_change_finished(status_name: String, succeeded: bool)

## 是否使用补间动画，将会在角色移动时显示动画效果
@export var use_tween: bool = true

## 动画时间，为0时则等于禁用动画效果
@export var animation_time: float = 0.5:
	set(value):
		if animation_time != value:
			animation_time = max(value, 0)

@export var texture_rect: TextureRect
@export var motion_layer: KonadoActorMotionLayer

## 屏幕横向分块数，不得小于2，将屏幕宽度分为从左到右递增的块，每个块大小相同
@export var horizontal_division: int = 5:
	set(value):
		if horizontal_division != value:
			horizontal_division = clamp(value, 2, 5)
			if not _suspend_layout_update:
				_on_resized()

## 当前角色横向位置所在区块分割线索引，从0开始，从左到右递增
@export var horizontal_position: int = 3:
	set(value):
		if horizontal_position != value:
			horizontal_position = clamp(value, 0, horizontal_division)
			if not _suspend_layout_update:
				_on_resized()

## 是否使用偏移动画（短距离移动+淡入），否则使用边缘进场动画（从屏幕外飞入）
@export var use_offset: bool = true

@export var slot: Control

var _status_node: KonadoCharacterSceneBase = null
var _move_tween: Tween
var _suspend_layout_update := false
var _is_visible := false
var _status_transition: KonadoActorStateTransitionController
var _visual_setup_serial := 0
var _character_status_request_serial := 0


## 判断角色是否在左侧区域（用于确定进场/退场方向）
func _is_left_side() -> bool:
	return horizontal_position <= horizontal_division / 2


## 获取进场动画名称
func _get_enter_animation_name() -> String:
	return (
		"left_enter_offset"
		if (use_offset and _is_left_side())
		else (
			"right_enter_offset"
			if use_offset
			else "left_enter" if _is_left_side() else "right_enter"
		)
	)


## 获取退场动画名称
func _get_exit_animation_name() -> String:
	return (
		"left_exit_offset"
		if (use_offset and _is_left_side())
		else "right_exit_offset" if use_offset else "left_exit" if _is_left_side() else "right_exit"
	)


## 判断是否为进场动画
func _is_enter_motion(motion_name: String) -> bool:
	return motion_name.begins_with("left_enter") or motion_name.begins_with("right_enter")


## 判断是否为退场动画
func _is_exit_motion(motion_name: String) -> bool:
	return motion_name.begins_with("left_exit") or motion_name.begins_with("right_exit")


func _ready() -> void:
	_ensure_status_transition()
	if texture_rect:
		texture_rect.modulate.a = 1.0
		texture_rect.visible = true
	_bind_motion_layer_signals()
	_on_resized()
	_is_visible = true


func _exit_tree() -> void:
	if _status_transition:
		_status_transition.cancel()


func _on_resized(duration_override: float = -1.0) -> void:
	if not slot:
		print("警告：slot未赋值")
		actor_moved.emit()
		return

	if _move_tween:
		_move_tween.kill()
		_move_tween = null

	var duration := duration_override if duration_override >= 0.0 else animation_time
	if use_tween and duration > 0.0:
		var tween: Tween = slot.create_tween()
		_move_tween = tween
		tween.set_parallel(true)
		tween.tween_property(
			slot,
			"position:x",
			(
				-size.x / horizontal_division * (horizontal_division - horizontal_position)
				+ slot.size.x / 2
			),
			duration
		)
		await tween.finished
		if _move_tween != tween:
			return
		_move_tween = null
		_layout_status_node()
		actor_moved.emit()
	else:
		slot.position.x = (
			-size.x / horizontal_division * (horizontal_division - horizontal_position)
			+ slot.size.x / 2
		)

		_layout_status_node()
		actor_moved.emit()


func set_stage_position(
	target_h_division: int, target_h_character_position: int, duration: float = -1.0
) -> bool:
	var next_horizontal_division: int = clamp(target_h_division, 2, 5)
	var next_position: int = clamp(target_h_character_position, 0, next_horizontal_division)
	if horizontal_division == next_horizontal_division and horizontal_position == next_position:
		return false
	_suspend_layout_update = true
	horizontal_division = next_horizontal_division
	horizontal_position = next_position
	_suspend_layout_update = false
	_on_resized(duration)
	return true


## 返回舞台位置补间是否仍在进行。目标值会在补间开始时立即提交，调用方不能仅通过
## horizontal_division/horizontal_position 判断角色是否已经真正到达目标位置。
func _is_stage_position_moving() -> bool:
	return _move_tween != null and _move_tween.is_valid()


## 高亮
func set_highlight(highlight: bool) -> void:
	if _status_node and _status_node.has_method("set_highlight"):
		_status_node.call("set_highlight", highlight)
		return
	var visual := _get_status_visual()
	if visual == null:
		return
	if highlight:
		visual.set_modulate(Color(1.0, 1.0, 1.0))
	else:
		visual.set_modulate(Color(0.35, 0.35, 0.35, 1.0))


## 角色进场动画
## 根据角色位置自动判断进场方向（左/右），优先使用motion_layer的移动进场动画
func enter_actor(play_anim: bool = true, duration_override: float = -1.0) -> void:
	if not play_anim:
		emit_signal("actor_entered")
		return

	var visual := _get_status_visual()
	if visual == null:
		print("警告：角色状态节点未赋值，无法执行进场动画")
		emit_signal("actor_entered")
		return

	if motion_layer and motion_layer.animation_player:
		var anim_name: StringName = _get_enter_animation_name()
		if motion_layer.animation_player.has_animation(anim_name):
			_is_visible = false
			_set_visibility(false)
			var params := {}
			if duration_override >= 0.0:
				params["duration"] = duration_override
			play_actor_motion(anim_name, params)
			return

	visual.visible = true
	visual.modulate.a = 0.0

	var tween: Tween = visual.create_tween()
	tween.set_parallel(true)
	var duration := duration_override if duration_override >= 0.0 else animation_time
	tween.tween_property(visual, "modulate:a", 1.0, duration)
	tween.finished.connect(_on_enter_animation_finished)
	tween.play()


## 角色退场动画
## 根据角色位置自动判断退场方向（左/右），优先使用motion_layer的移动退场动画
func exit_actor(play_anim: bool = true, duration_override: float = -1.0) -> void:
	if not play_anim:
		emit_signal("actor_exited")
		self.queue_free()
		return

	var visual := _get_status_visual()
	if visual == null:
		print("警告：角色状态节点未赋值，无法执行退场动画")
		emit_signal("actor_exited")
		self.queue_free()
		return

	if motion_layer and motion_layer.animation_player:
		var anim_name := _get_exit_animation_name()
		if motion_layer.animation_player.has_animation(anim_name):
			var params := {}
			if duration_override >= 0.0:
				params["duration"] = duration_override
			play_actor_motion(anim_name, params)
			return

	var tween: Tween = visual.create_tween()
	var duration := duration_override if duration_override >= 0.0 else animation_time
	tween.tween_property(visual, "modulate:a", 0.0, duration)
	tween.finished.connect(func(): self.queue_free())
	tween.play()


## 设置可见性
func _set_visibility(visible: bool) -> void:
	var visual := _get_status_visual()
	if visual:
		visual.visible = visible


## 进场动画完成回调
func _on_enter_animation_finished() -> void:
	actor_entered.emit()


## 创建角色场景并应用初始状态。返回 false 时不会替换当前有效场景。
func set_character_scene(scene: PackedScene, initial_status: String = "") -> bool:
	var observed_serial := _visual_setup_serial
	return _set_character_scene_internal(scene, initial_status, observed_serial)


func _set_character_scene_internal(
	scene: PackedScene, initial_status: String, observed_serial: int
) -> bool:
	var mount := _get_character_mount()
	if mount == null:
		return false
	var instance := _prepare_character_scene_candidate(
		scene, initial_status, mount, observed_serial
	)
	if instance == null:
		return false
	# @ready、状态校验和用户状态钩子都可能重入设置新场景。此时外层候选已经过期，
	# 不能覆盖内层刚提交的结果。
	if observed_serial != _visual_setup_serial:
		_discard_character_scene_candidate(instance)
		return false

	_visual_setup_serial += 1
	var setup_serial := _visual_setup_serial
	if _status_transition:
		_status_transition.cancel()
	if setup_serial != _visual_setup_serial:
		_discard_character_scene_candidate(instance)
		return false
	var previous_status_node := _status_node
	_status_node = instance
	if previous_status_node and is_instance_valid(previous_status_node):
		var previous_parent := previous_status_node.get_parent()
		if previous_parent:
			previous_parent.remove_child(previous_status_node)
		previous_status_node.queue_free()
	if texture_rect:
		texture_rect.texture = null
		texture_rect.visible = false
	_layout_status_node()
	var instance_node: Node = instance
	if instance_node is CanvasItem:
		(instance_node as CanvasItem).visible = true
	return true


func _prepare_character_scene_candidate(
	scene: PackedScene, initial_status: String, mount: Node, observed_serial: int
) -> KonadoCharacterSceneBase:
	if scene == null:
		push_error("正在试图设置一个空角色场景")
		return null
	var instance := scene.instantiate()
	if instance == null:
		push_error("角色场景实例化失败")
		return null
	if not instance is KonadoCharacterSceneBase:
		push_error("角色场景必须继承 KonadoCharacterSceneBase")
		instance.free()
		return null
	if instance is CanvasItem:
		(instance as CanvasItem).visible = false
	# 先让候选场景完整进入树，确保 @onready/_ready 已完成，再校验初始状态。
	# 提交前不改写 _status_node，因此失败不会破坏当前有效角色场景。
	mount.add_child(instance)
	# 初始状态钩子可能依据 Control 的实际尺寸或 Node2D 的锚点位置布置内容。
	# 候选场景虽然仍保持隐藏，也必须先完成与正式场景相同的布局。
	_layout_character_scene_node(instance, mount)
	if observed_serial != _visual_setup_serial:
		_discard_character_scene_candidate(instance)
		return null
	if (
		not initial_status.is_empty()
		and not _apply_character_status_to_node(instance, initial_status)
	):
		_discard_character_scene_candidate(instance)
		return null
	return instance as KonadoCharacterSceneBase


func _discard_character_scene_candidate(instance: KonadoCharacterSceneBase) -> void:
	if instance == null or not is_instance_valid(instance):
		return
	var parent := instance.get_parent()
	if parent:
		parent.remove_child(instance)
	instance.free()


## 演员节点只负责把剧本里的状态名转发给角色场景。
## 这里不判断图片、Spine、Live2D 或视频，避免主链路重新绑定到某一种媒体类型。
func apply_character_status(
	status_name: String, transition_duration: float = 0.0, completion: Callable = Callable()
) -> bool:
	return _request_character_status(status_name, transition_duration, completion)


## 协议入口由 Konado 自身持有：无论自定义演员是否覆写公共便捷方法，运行时都必须
## 经过校验、重入所有权和完成回调约束。扩展异步表现应覆写
## _submit_character_status_request()，而不是覆写此入口。
func _request_character_status(
	status_name: String, transition_duration: float, completion: Callable
) -> bool:
	_ensure_status_transition()
	var observed_request_serial := _character_status_request_serial
	if not _can_apply_character_status(status_name):
		if completion.is_valid():
			completion.call(false)
		return false
	if observed_request_serial != _character_status_request_serial:
		if completion.is_valid():
			completion.call(false)
		return false
	_character_status_request_serial += 1
	var request_serial := _character_status_request_serial
	return (
		request_serial == _character_status_request_serial
		and _submit_character_status_request(status_name, transition_duration, completion)
	)


## 自定义演员的受控扩展点。调用前状态已经校验，返回 false 时必须同步调用
## completion(false)；返回 true 后则必须最终且仅调用一次 completion。
func _submit_character_status_request(
	status_name: String, transition_duration: float, completion: Callable
) -> bool:
	return _status_transition.request(status_name, transition_duration, completion, true)


func _cancel_character_status_transition() -> void:
	if _status_transition:
		_status_transition.cancel()


func _apply_character_status_immediately(status_name: String) -> bool:
	if status_name.is_empty():
		return false
	if _status_node == null:
		push_error("角色场景节点未创建，无法切换状态：" + status_name)
		return false
	return _apply_character_status_to_node(_status_node, status_name)


func _apply_character_status_to_node(character_node: Node, status_name: String) -> bool:
	if character_node == null or status_name.is_empty():
		return false
	if not character_node is KonadoCharacterSceneBase:
		return false
	return (character_node as KonadoCharacterSceneBase).apply_status(status_name)


func _ensure_status_transition() -> void:
	if _status_transition:
		return
	_status_transition = KonadoActorStateTransitionController.new(
		self,
		_get_status_transition_visual,
		_apply_character_status_immediately,
		_get_character_transition_frame,
		_can_apply_character_status
	)
	_status_transition.transition_started.connect(
		func(status_name: String): actor_status_change_started.emit(status_name)
	)
	_status_transition.status_applied.connect(
		func(status_name: String): actor_status_applied.emit(status_name)
	)
	_status_transition.transition_cancelled.connect(
		func(status_name: String): actor_status_change_cancelled.emit(status_name)
	)
	_status_transition.transition_finished.connect(
		func(status_name: String, succeeded: bool):
			actor_status_change_finished.emit(status_name, succeeded)
	)


## 舞台层动作，例如 shake、jump_twice、bounce。
## 这些动作作用在 MotionLayer 上，和角色场景内部的表情、Live2D motion、视频切换分开。
func play_actor_motion(motion_name: String, params: Dictionary = {}) -> void:
	if motion_name.is_empty():
		actor_motion_finished.emit(motion_name)
		return
	if motion_layer == null:
		push_error("演员动作层未配置，无法播放动作：" + motion_name)
		actor_motion_finished.emit(motion_name)
		return
	motion_layer.play_motion(motion_name, params)


func can_play_actor_motion(motion_name: String) -> bool:
	return motion_layer != null and motion_layer.has_motion(motion_name)


func _clear_status_node() -> void:
	var status_node := _status_node
	if _status_transition:
		_status_transition.cancel()
	# cancel() 会同步调用完成回调，回调可能已经提交了新的角色场景。
	# 只清理调用前的快照，绝不能误删重入后产生的新节点。
	if _status_node != status_node:
		return
	_status_node = null
	if status_node and is_instance_valid(status_node):
		var parent := status_node.get_parent()
		if parent:
			parent.remove_child(status_node)
		status_node.queue_free()


## 替换演员动作层。返回 false 时保留当前有效动作层。
func set_motion_layer_scene(scene: PackedScene) -> bool:
	return _set_motion_layer_scene_internal(scene)


func _set_motion_layer_scene_internal(scene: PackedScene) -> bool:
	if scene == null:
		return true
	if slot == null:
		push_error("slot未赋值，无法替换演员动作层")
		return false
	var observed_serial := _visual_setup_serial
	var instance := scene.instantiate()
	if not (instance is KonadoActorMotionLayer):
		push_warning("演员动作层场景必须继承 KonadoActorMotionLayer")
		if instance != null:
			instance.free()
		return false

	# 先完整实例化并验证新层，再提交替换。错误配置不能破坏仍在使用的动作层与角色状态。
	if observed_serial != _visual_setup_serial:
		instance.free()
		return false
	_visual_setup_serial += 1
	var setup_serial := _visual_setup_serial
	_clear_status_node()
	if setup_serial != _visual_setup_serial:
		instance.free()
		return false
	var previous_motion_layer := motion_layer
	if previous_motion_layer and is_instance_valid(previous_motion_layer):
		var previous_parent := previous_motion_layer.get_parent()
		if previous_parent:
			previous_parent.remove_child(previous_motion_layer)
		previous_motion_layer.queue_free()
	motion_layer = instance as KonadoActorMotionLayer
	slot.add_child(motion_layer)
	if motion_layer is Control:
		motion_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_rect = _find_texture_rect(motion_layer)
	_bind_motion_layer_signals()
	return true


func _bind_motion_layer_signals() -> void:
	if motion_layer == null:
		return
	if not motion_layer.motion_started.is_connected(_on_motion_layer_started):
		motion_layer.motion_started.connect(_on_motion_layer_started)
	if not motion_layer.motion_finished.is_connected(_on_motion_layer_finished):
		motion_layer.motion_finished.connect(_on_motion_layer_finished)


func _on_motion_layer_started(motion_name: String) -> void:
	actor_motion_started.emit(motion_name)
	if _is_enter_motion(motion_name):
		_is_visible = true
		_set_visibility(true)


func _on_motion_layer_finished(motion_name: String) -> void:
	actor_motion_finished.emit(motion_name)
	if _is_enter_motion(motion_name):
		actor_entered.emit()
	if _is_exit_motion(motion_name):
		_is_visible = false
		_set_visibility(false)
		if motion_layer:
			motion_layer.stop_motion()
		emit_signal("actor_exited")
		self.queue_free()


func _layout_status_node() -> void:
	var mount := _get_character_mount()
	if _status_node == null or mount == null:
		return
	_layout_character_scene_node(_status_node, mount)


func _layout_character_scene_node(character_scene: Node, mount: Node) -> void:
	if character_scene == null or mount == null:
		return
	# Control 场景适合铺满角色槽；Node2D 场景适合以槽中心作为立绘锚点。
	# 具体缩放和内部偏移仍由角色场景自己控制。
	if character_scene is Control:
		var control := character_scene as Control
		# 只设置 anchors 会保留场景原有 offsets，初始状态钩子仍可能读到 0 尺寸。
		# 同时归零 offsets，确保候选节点在状态校验和应用前已经取得挂载层尺寸。
		control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	elif character_scene is Node2D:
		var node_2d := character_scene as Node2D
		if mount is Control:
			node_2d.position = (mount as Control).size * 0.5


func _get_status_visual() -> CanvasItem:
	if _status_node:
		var status_node: Node = _status_node
		if status_node is CanvasItem:
			return status_node as CanvasItem
		var canvas_item := _find_canvas_item(status_node)
		if canvas_item:
			return canvas_item
	if texture_rect:
		return texture_rect
	return null


## 状态切换优先作用在稳定的角色挂载层，避免角色场景切换内部子节点后 Tween 失效。
func _get_status_transition_visual() -> CanvasItem:
	var mount := _get_character_mount()
	if mount is CanvasItem:
		return mount as CanvasItem
	return _get_status_visual()


func _get_character_transition_frame(status_name: String) -> RefCounted:
	if not (_status_node is KonadoCharacterSceneBase):
		return null
	var target_space := _get_status_transition_visual()
	if target_space == null:
		return null
	var character_scene := _status_node as KonadoCharacterSceneBase
	if status_name.is_empty():
		return character_scene.get_current_status_transition_frame(target_space)
	return character_scene.get_status_transition_frame(status_name, target_space)


func _can_apply_character_status(status_name: String) -> bool:
	if status_name.is_empty() or _status_node == null:
		return false
	return _status_node.can_apply_status(status_name)


func _get_character_mount() -> Node:
	if motion_layer:
		return motion_layer.get_mount_node()
	return slot


func _find_canvas_item(node: Node) -> CanvasItem:
	for child in node.get_children():
		if child is CanvasItem:
			return child as CanvasItem
		var nested := _find_canvas_item(child)
		if nested:
			return nested
	return null


func _find_texture_rect(node: Node) -> TextureRect:
	if node is TextureRect:
		return node as TextureRect
	for child in node.get_children():
		var texture := _find_texture_rect(child)
		if texture:
			return texture
	return null


## 整体设置整个Actor容器（slot）全部子UI/角色的modulate，全局统一染色
func set_actor_modulate(color: Color) -> void:
	if slot:
		slot.modulate = color
