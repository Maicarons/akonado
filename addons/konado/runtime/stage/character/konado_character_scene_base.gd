extends Node
class_name KonadoCharacterSceneBase

## 角色场景基类。
## 主链路只调用这些公开入口，具体图片、视频、Spine、Live2D 等表现由子场景自己实现。
## 子类通常只覆写下划线开头的钩子方法，避免绕过当前状态记录和信号派发。

signal status_applied(status_name: String, resolved_status_name: String)
signal action_started(action_name: String)
signal action_finished(action_name: String)
signal character_scene_reset

## 状态别名用于将剧本里的语义名映射为具体资源里的动画名。
## 使用数组条目而不是 Dictionary，是为了在 Inspector 中展开后直接填写两个字符串。
@export var status_aliases: Array[KonadoCharacterStatusAlias] = []

## 记录原始状态名和解析后的状态名，方便存档、调试面板或扩展节点读取。
var current_status_name: String = ""
var current_resolved_status_name: String = ""
var current_action_name: String = ""
var _status_change_serial := 0


## 状态是角色的持续表现，例如表情、待机动画、视频片段或 Live2D expression。
## 对话系统只传入语义状态名，不关心子场景如何呈现。
## 在提交状态时重新校验，并明确返回是否成功。转场控制器会在接收请求时先校验，
## 转场结束、真正提交状态时再校验一次，以处理等待期间资源或可用性发生的变化。
func apply_status(status_name: String) -> bool:
	if status_name.is_empty():
		return false
	var observed_serial := _status_change_serial
	var resolved_status_name := resolve_status_name(status_name)
	if observed_serial != _status_change_serial or resolved_status_name.is_empty():
		return false
	if not _has_status(resolved_status_name, status_name):
		return false
	# 校验钩子允许自定义资源查询，也可能同步触发其他状态请求。只有通过校验且仍是
	# 最新的请求才能取得所有权；无效的重入请求不会打断外层有效状态。
	if observed_serial != _status_change_serial:
		return false
	_status_change_serial += 1
	var request_serial := _status_change_serial
	# 保持 apply_status 的既有语义：覆写钩子执行时即可读取目标状态。
	# 可用性已经在变更公开状态前完成校验，缺失状态不会污染状态记录。
	current_status_name = status_name
	current_resolved_status_name = resolved_status_name
	_apply_status(resolved_status_name, status_name)
	if request_serial != _status_change_serial:
		return false
	status_applied.emit(status_name, resolved_status_name)
	return request_serial == _status_change_serial


## 只校验状态是否可用，不修改角色场景。
## _has_status 可能在请求接收和最终提交两个阶段分别调用，因此必须无副作用、幂等，
## 不应在其中播放媒体、修改节点或发起新的状态请求。
func can_apply_status(status_name: String) -> bool:
	if status_name.is_empty():
		return false
	var observed_serial := _status_change_serial
	var resolved_status_name := resolve_status_name(status_name)
	if observed_serial != _status_change_serial or resolved_status_name.is_empty():
		return false
	return (
		_has_status(resolved_status_name, status_name) and observed_serial == _status_change_serial
	)


## 为当前状态交融提供无副作用的纯渲染帧。
## 默认不猜测或复制场景；需要真正交融的场景应覆写对应的两个帧钩子。
## 无法安全提供帧时返回 null，系统会自动使用串行淡出/淡入。
func get_current_status_transition_frame(target_space: CanvasItem) -> RefCounted:
	if target_space == null:
		return null
	if current_resolved_status_name.is_empty():
		return null
	return _get_current_status_transition_frame(target_space)


## 为指定的目标状态交融提供无副作用的纯渲染帧。
func get_status_transition_frame(status_name: String, target_space: CanvasItem) -> RefCounted:
	if status_name.is_empty() or target_space == null:
		return null
	var resolved_status_name := resolve_status_name(status_name)
	# 调用方会先通过 can_apply_status 校验；目标帧钩子本身也应在资源不存在时返回 null。
	# 这里不重复调用 _has_status，避免自定义校验的日志或昂贵查询执行两遍。
	if resolved_status_name.is_empty():
		return null
	return _get_status_transition_frame(resolved_status_name, status_name, target_space)


## 角色场景内部动作是一次性表现，例如挥手、眨眼、播放一段 Spine 动画。
## 它和 status 分离，是为了不破坏当前表情状态；震动、跳跃等整体舞台动作交给 KonadoActorMotionLayer。
func play_action(action_name: String) -> void:
	if action_name.is_empty():
		return
	current_action_name = action_name
	action_started.emit(action_name)
	_play_action(action_name)


## 子类的异步动作完成后调用这个方法，外部可以用 action_finished 继续剧情。
func finish_action(action_name: String = "") -> void:
	var finished_action_name := action_name
	if finished_action_name.is_empty():
		finished_action_name = current_action_name
	action_finished.emit(finished_action_name)


## 高亮是舞台层对角色的通用要求，子场景可覆写成更适合自己的效果。
## 例如 Live2D 可以调材质参数，视频角色可以调承载节点的 modulate。
func set_highlight(highlight: bool) -> void:
	_set_highlight(highlight)


## 给读档、重播或重新入场预留的重置入口，具体资源由子场景决定如何复位。
func reset_character_scene() -> void:
	_status_change_serial += 1
	var reset_serial := _status_change_serial
	current_status_name = ""
	current_resolved_status_name = ""
	current_action_name = ""
	_reset_character_scene()
	# 自定义重置钩子可能同步应用新状态。此时新的请求已经接管场景，旧重置不得再
	# 派发一个语义过期的 reset 信号，否则监听方会把刚应用的状态再次清空。
	if reset_serial != _status_change_serial:
		return
	character_scene_reset.emit()


## 子类可以覆写这个方法，把剧本里的语义名映射到具体媒体资源的名字。
func resolve_status_name(status_name: String) -> String:
	for alias in status_aliases:
		if alias == null:
			continue
		if alias.status_name == status_name:
			if alias.resolved_status_name.is_empty():
				return status_name
			return alias.resolved_status_name
	return status_name


## 子类覆写：根据解析后的状态名更新内部表现。
## original_status_name 保留给日志和错误提示，避免别名解析后丢失剧本原文。
## 自定义场景若能校验状态，应同时覆写 _has_status，使失败切换可以安全回滚。
func _apply_status(_resolved_status_name: String, _original_status_name: String) -> void:
	pass


## 子类覆写：目标状态是否可用。实现必须无副作用且幂等；一次延迟转场通常会在
## 接收请求与最终提交时各调用一次。默认接受任意非空状态名；需要严格资源校验的
## 场景必须覆写该方法。
func _has_status(_resolved_status_name: String, _original_status_name: String) -> bool:
	return true


## 子类覆写：返回当前实际显示的纯纹理帧，且不得修改实时角色状态。
## 可使用 KonadoCharacterTransitionFrame.from_animated_sprite / from_sprite 创建帧。
## 每次调用必须返回独立帧，不能复用并改写上一次返回的可变对象。
func _get_current_status_transition_frame(_target_space: CanvasItem) -> RefCounted:
	return null


## 子类覆写：返回目标状态的纯纹理帧，且不得修改实时角色状态。
## 每次调用必须返回独立帧，不能与当前状态帧共享同一个对象。
func _get_status_transition_frame(
	_resolved_status_name: String, _original_status_name: String, _target_space: CanvasItem
) -> RefCounted:
	return null


## 子类覆写：播放一次性动作。同步完成的动作可以直接调用 finish_action。
func _play_action(action_name: String) -> void:
	finish_action(action_name)


## 默认高亮只找第一个可显示节点，给简单场景兜底。
## 复杂场景建议覆写此方法，精确控制哪些节点被压暗或恢复。
func _set_highlight(highlight: bool) -> void:
	var canvas_item := _find_canvas_item(self)
	if canvas_item == null:
		return
	if highlight:
		canvas_item.modulate = Color(1.0, 1.0, 1.0, canvas_item.modulate.a)
	else:
		canvas_item.modulate = Color(0.35, 0.35, 0.35, canvas_item.modulate.a)


func _reset_character_scene() -> void:
	pass


## 基类继承 Node，是为了允许根节点是普通 Node、Node2D 或 Control。
## 因此默认视觉处理需要递归寻找 CanvasItem，而不是假设根节点可显示。
func _find_canvas_item(node: Node) -> CanvasItem:
	if node is CanvasItem:
		return node as CanvasItem
	for child in node.get_children():
		var canvas_item := _find_canvas_item(child)
		if canvas_item:
			return canvas_item
	return null
