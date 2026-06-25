@tool
extends Control
class_name KND_ActorMotionLayer

## 演员动作层。
## Slot 负责角色站位，MotionLayer 只负责临时舞台动作，例如震动、跳跃、弹一下。

signal motion_started(motion_name: String)
signal motion_finished(motion_name: String)

## 播放 AnimationPlayer 中的同名动画，方便用户在编辑器里可视化制作动作。
@export var animation_player: AnimationPlayer
## 角色场景挂载点。动画建议作用在这个节点上，避免影响 Slot 的站位。
@export var mount_node: Node

var _active_motion_name: String = ""

func _ready() -> void:
	if animation_player == null:
		animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if mount_node == null:
		mount_node = get_node_or_null("CharacterMount")
	if animation_player and not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)

func get_mount_node() -> Node:
	if mount_node:
		return mount_node
	return self

func play_motion(motion_name: String, _params: Dictionary = {}) -> void:
	if motion_name.is_empty():
		motion_finished.emit(motion_name)
		return
	_active_motion_name = motion_name
	motion_started.emit(motion_name)

	if animation_player and animation_player.has_animation(motion_name):
		_reset_motion_target()
		animation_player.play(motion_name)
		return

	push_warning("未找到演员动作：%s，可用 AnimationPlayer 动画：%s" % [motion_name, _get_animation_names_text()])
	_finish_motion(motion_name)

func stop_motion() -> void:
	if animation_player:
		animation_player.stop()
	_reset_motion_target()
	_active_motion_name = ""

func _finish_motion(motion_name: String) -> void:
	_active_motion_name = ""
	motion_finished.emit(motion_name)

func _on_animation_finished(animation_name: StringName) -> void:
	if str(animation_name) != _active_motion_name:
		return
	_finish_motion(_active_motion_name)

func _reset_motion_target() -> void:
	var target := _get_motion_target()
	target.set("position", Vector2.ZERO)
	target.set("scale", Vector2.ONE)
	target.set("rotation", 0.0)

func _get_motion_target() -> Node:
	var target := get_mount_node()
	if target is Control or target is Node2D:
		return target
	return self

func _get_animation_names_text() -> String:
	if animation_player == null:
		return "未配置 AnimationPlayer"
	var names := PackedStringArray()
	for animation_name in animation_player.get_animation_list():
		names.append(str(animation_name))
	if names.is_empty():
		return "无"
	return ", ".join(names)
