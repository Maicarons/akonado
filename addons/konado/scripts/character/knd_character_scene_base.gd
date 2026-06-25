extends Node
class_name KND_CharacterSceneBase

## 角色场景基类。
## 主链路只调用这些公开入口，具体图片、视频、Spine、Live2D 等表现由子场景自己实现。
## 子类通常只覆写下划线开头的钩子方法，避免绕过当前状态记录和信号派发。

signal status_applied(status_name: String, resolved_status_name: String)
signal action_started(action_name: String)
signal action_finished(action_name: String)
signal character_scene_reset

## 状态别名用于兼容剧本里的语义名和具体资源里的动画名。
## 使用数组条目而不是 Dictionary，是为了在 Inspector 中展开后直接填写两个字符串。
@export var status_aliases: Array[KND_CharacterStatusAlias] = []

## 记录原始状态名和解析后的状态名，方便存档、调试面板或扩展节点读取。
var current_status_name: String = ""
var current_resolved_status_name: String = ""
var current_action_name: String = ""

## 状态是角色的持续表现，例如表情、待机动画、视频片段或 Live2D expression。
## 对话系统只传入语义状态名，不关心子场景如何呈现。
func apply_status(status_name: String) -> void:
	if status_name.is_empty():
		return
	var resolved_status_name := resolve_status_name(status_name)
	current_status_name = status_name
	current_resolved_status_name = resolved_status_name
	_apply_status(resolved_status_name, status_name)
	status_applied.emit(status_name, resolved_status_name)

## 角色场景内部动作是一次性表现，例如挥手、眨眼、播放一段 Spine 动画。
## 它和 status 分离，是为了不破坏当前表情状态；震动、跳跃等整体舞台动作交给 KND_ActorMotionLayer。
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
	current_status_name = ""
	current_resolved_status_name = ""
	current_action_name = ""
	_reset_character_scene()
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
func _apply_status(resolved_status_name: String, original_status_name: String) -> void:
	pass

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
