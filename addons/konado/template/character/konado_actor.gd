@tool
extends Control
class_name KND_Actor

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

## 是否使用补间动画，将会在角色移动时显示动画效果
@export var use_tween: bool = true

## 动画时间，为0时则等于禁用动画效果
@export var animation_time: float = 0.2:
	set(value):
		if animation_time != value:
			animation_time = max(value, 0)

@export var texture_rect: TextureRect
@export var motion_layer: KND_ActorMotionLayer
var _status_node: Node = null
var _move_tween: Tween
var _suspend_layout_update := false

## 屏幕横向分块数，不得小于2，将屏幕宽度分为从左到右递增的块，每个块大小相同
@export var h_division: int = 5:
	set(value):
		if h_division != value:
			h_division = clamp(value, 2, 5)
			if not _suspend_layout_update:
				_on_resized()

## 当前角色横向位置所在区块分割线索引，从0开始，从左到右递增
@export var h_character_position: int = 3:
	set(value):
		if h_character_position != value:
			h_character_position = clamp(value, 0, h_division)
			if not _suspend_layout_update:
				_on_resized()

func _ready() -> void:
	# 初始化透明度为1（确保初始状态正常）
	if texture_rect:
		texture_rect.modulate.a = 1.0
		texture_rect.visible = true
	_bind_motion_layer_signals()
	# 初始化位置
	_on_resized()

func _on_resized() -> void:
	if not slot:
		print("警告：slot未赋值")
		actor_moved.emit()
		return

	if _move_tween:
		_move_tween.kill()
		_move_tween = null
	
	if use_tween and animation_time > 0.0:
		var tween: Tween = slot.create_tween()
		_move_tween = tween
		tween.set_parallel(true)
		tween.tween_property(slot, "position:x", -size.x / h_division * (h_division - h_character_position ) + slot.size.x/2, animation_time)
		await tween.finished
		if _move_tween != tween:
			return
		_move_tween = null
		_layout_status_node()
		actor_moved.emit()
	else:
		slot.position.x = -size.x / h_division * (h_division - h_character_position ) + slot.size.x/2
	
		_layout_status_node()
		actor_moved.emit()

func set_stage_position(target_h_division: int, target_h_character_position: int) -> bool:
	var next_h_division: int = clamp(target_h_division, 2, 5)
	var next_position: int = clamp(target_h_character_position, 0, next_h_division)
	if h_division == next_h_division and h_character_position == next_position:
		return false
	_suspend_layout_update = true
	h_division = next_h_division
	h_character_position = next_position
	_suspend_layout_update = false
	_on_resized()
	return true

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
	pass

## 角色进场动画（透明度从0过渡到1）
func enter_actor(play_anim: bool = true) -> void:
	var visual := _get_status_visual()
	if visual == null:
		print("警告：角色状态节点未赋值，无法执行进场动画")
		emit_signal("actor_entered")
		return
	
	# 重置基础状态
	visual.visible = true
	visual.modulate.a = 0.0
	
	# 创建补间动画
	var tween: Tween = visual.create_tween()
	# 并行执行多个动画轨道
	tween.set_parallel(true)
	
	# 透明度动画（核心进场效果）
	tween.tween_property(visual, "modulate:a", 1.0, animation_time)
	
	tween.finished.connect(_on_enter_animation_finished)
	tween.play()

## 角色退场动画（透明度从1过渡到0）
func exit_actor(play_anim: bool = true) -> void:
	var visual := _get_status_visual()
	if visual == null:
		print("警告：角色状态节点未赋值，无法执行退场动画")
		emit_signal("actor_exited")
		return
	
	# 创建补间动画
	var tween: Tween = visual.create_tween()
	# 透明度淡出动画
	tween.tween_property(visual, "modulate:a", 0.0, animation_time)
	
	# 动画完成后删除节点
	tween.finished.connect(func(): self.queue_free())
	tween.play()

## 进场动画完成回调
func _on_enter_animation_finished() -> void:
	actor_entered.emit()

func set_character_scene(scene: PackedScene, initial_status: String = "") -> void:
	_clear_status_node()
	var mount := _get_character_mount()
	if mount == null:
		return
	if scene == null:
		push_error("正在试图设置一个空角色场景")
		return
	if texture_rect:
		texture_rect.texture = null
		texture_rect.visible = false
	var instance := scene.instantiate()
	_status_node = instance
	mount.add_child(instance)
	_layout_status_node()
	if instance is CanvasItem:
		instance.visible = true
	if not initial_status.is_empty():
		apply_character_status(initial_status)

## 演员节点只负责把剧本里的状态名转发给角色场景。
## 这里不判断图片、Spine、Live2D 或视频，避免主链路重新绑定到某一种媒体类型。
func apply_character_status(status_name: String) -> void:
	if status_name.is_empty():
		return
	if _status_node == null:
		push_error("角色场景节点未创建，无法切换状态：" + status_name)
		return
	# 优先使用正式协议；后面的 has_method 分支用于兼容未继承基类的用户场景。
	if _status_node is KND_CharacterSceneBase:
		(_status_node as KND_CharacterSceneBase).apply_status(status_name)
		return
	elif _status_node.has_method("apply_status"):
		_status_node.call("apply_status", status_name)
		return
	if _status_node.has_method("change_status"):
		_status_node.call("change_status", status_name)
		return
	if _status_node.has_method("set_status"):
		_status_node.call("set_status", status_name)
		return
	push_warning("角色场景未实现 apply_status：" + status_name)

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

func set_character_texture(texture: Texture) -> void:
	_clear_status_node()
	if not texture_rect:
		return
	if texture == null:
		push_error("正在试图设置一个空角色图像")
	texture_rect.visible = true
	texture_rect.texture = texture

func _clear_status_node() -> void:
	if _status_node and is_instance_valid(_status_node):
		_status_node.queue_free()
	_status_node = null

func set_motion_layer_scene(scene: PackedScene) -> void:
	if scene == null:
		return
	if slot == null:
		push_error("slot未赋值，无法替换演员动作层")
		return
	_clear_status_node()
	if motion_layer and is_instance_valid(motion_layer):
		motion_layer.queue_free()
	var instance := scene.instantiate()
	if not (instance is KND_ActorMotionLayer):
		push_error("演员动作层场景必须继承 KND_ActorMotionLayer")
		instance.queue_free()
		return
	motion_layer = instance as KND_ActorMotionLayer
	slot.add_child(motion_layer)
	if motion_layer is Control:
		motion_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect = _find_texture_rect(motion_layer)
	_bind_motion_layer_signals()

func _bind_motion_layer_signals() -> void:
	if motion_layer == null:
		return
	if not motion_layer.motion_started.is_connected(_on_motion_layer_started):
		motion_layer.motion_started.connect(_on_motion_layer_started)
	if not motion_layer.motion_finished.is_connected(_on_motion_layer_finished):
		motion_layer.motion_finished.connect(_on_motion_layer_finished)

func _on_motion_layer_started(motion_name: String) -> void:
	actor_motion_started.emit(motion_name)

func _on_motion_layer_finished(motion_name: String) -> void:
	actor_motion_finished.emit(motion_name)

func _layout_status_node() -> void:
	var mount := _get_character_mount()
	if _status_node == null or mount == null:
		return
	# Control 场景适合铺满角色槽；Node2D 场景适合以槽中心作为立绘锚点。
	# 具体缩放和内部偏移仍由角色场景自己控制。
	if _status_node is Control:
		var control := _status_node as Control
		control.set_anchors_preset(Control.PRESET_FULL_RECT)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	elif _status_node is Node2D:
		var node_2d := _status_node as Node2D
		if mount is Control:
			node_2d.position = (mount as Control).size * 0.5

func _get_status_visual() -> CanvasItem:
	if _status_node:
		if _status_node is CanvasItem:
			return _status_node as CanvasItem
		var canvas_item := _find_canvas_item(_status_node)
		if canvas_item:
			return canvas_item
	if texture_rect:
		return texture_rect
	return null

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

@export var slot: Control


			
#@tool
#extends Control
#
#@onready var control: Control = $Slot
#
#@export var division:= 3:
	#set(value):
		#if division != value:
			#division = clamp(value,2,15)
			#_on_resized()
#
#@export var character_position := 2:
	#set(value):
		#if character_position!= value:
			#character_position = clamp(value,0,division)
			#_on_resized()
			#
#
#func _on_resized() -> void:
	#if control:
		#control.position.x = -size.x /division * (division - character_position )+ control.size.x/2
