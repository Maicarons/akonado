@tool
extends Control
class_name KND_ActorMotionLayer

## 演员动作层。
## Slot 负责角色站位，MotionLayer 只负责临时舞台动作，例如震动、跳跃、弹一下。

signal motion_started(motion_name: String)
signal motion_finished(motion_name: String)

## 优先播放 AnimationPlayer 中的同名动画，方便用户在编辑器里可视化制作动作。
@export var animation_player: AnimationPlayer
## 角色场景挂载点。动画建议作用在这个节点上，避免影响 Slot 的站位。
@export var mount_node: Node

@export var fallback_duration: float = 0.28
@export var fallback_distance: float = 32.0

var _active_motion_name: String = ""
var _fallback_tween: Tween = null

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

func play_motion(motion_name: String, params: Dictionary = {}) -> void:
	if motion_name.is_empty():
		motion_finished.emit(motion_name)
		return
	_stop_fallback_tween()
	_active_motion_name = motion_name
	motion_started.emit(motion_name)

	if animation_player and animation_player.has_animation(motion_name):
		_reset_motion_target()
		animation_player.play(motion_name)
		return

	_play_builtin_motion(motion_name, params)

func stop_motion() -> void:
	_stop_fallback_tween()
	if animation_player:
		animation_player.stop()
	_reset_motion_target()
	_active_motion_name = ""

func _play_builtin_motion(motion_name: String, params: Dictionary) -> void:
	match motion_name:
		"shake":
			_play_shake(params)
		"jump":
			_play_jump(params, 1)
		"jump_twice":
			_play_jump(params, 2)
		"bounce":
			_play_bounce(params)
		_:
			push_warning("未找到演员动作：%s，可用 AnimationPlayer 动画：%s" % [motion_name, _get_animation_names_text()])
			_finish_motion(motion_name)

func _play_shake(params: Dictionary) -> void:
	var target := _get_motion_target()
	var distance: float = float(params.get("distance", fallback_distance * 0.35))
	var duration: float = float(params.get("duration", fallback_duration))
	var times: int = int(params.get("times", 4))
	var step: float = duration / float(max(times * 2 + 1, 1))
	_reset_motion_target()
	_fallback_tween = create_tween()
	for index in range(times):
		var direction: float = 1.0 if index % 2 == 0 else -1.0
		_fallback_tween.tween_property(target, "position:x", direction * distance, step)
		_fallback_tween.tween_property(target, "position:x", -direction * distance, step)
	_fallback_tween.tween_property(target, "position:x", 0.0, step)
	_fallback_tween.finished.connect(_finish_motion.bind(_active_motion_name))

func _play_jump(params: Dictionary, times: int) -> void:
	var target := _get_motion_target()
	var distance: float = float(params.get("distance", fallback_distance))
	var duration: float = float(params.get("duration", fallback_duration))
	var step: float = duration / float(max(times * 2, 1))
	_reset_motion_target()
	_fallback_tween = create_tween()
	for _index in range(times):
		_fallback_tween.tween_property(target, "position:y", -distance, step).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_fallback_tween.tween_property(target, "position:y", 0.0, step).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_fallback_tween.finished.connect(_finish_motion.bind(_active_motion_name))

func _play_bounce(params: Dictionary) -> void:
	var target := _get_motion_target()
	var scale_value: float = float(params.get("scale", 1.08))
	var duration: float = float(params.get("duration", fallback_duration))
	_reset_motion_target()
	_fallback_tween = create_tween()
	_fallback_tween.tween_property(target, "scale", Vector2(scale_value, scale_value), duration * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fallback_tween.tween_property(target, "scale", Vector2.ONE, duration * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_fallback_tween.finished.connect(_finish_motion.bind(_active_motion_name))

func _finish_motion(motion_name: String) -> void:
	_reset_motion_target()
	_active_motion_name = ""
	_fallback_tween = null
	motion_finished.emit(motion_name)

func _on_animation_finished(animation_name: StringName) -> void:
	if str(animation_name) != _active_motion_name:
		return
	_finish_motion(_active_motion_name)

func _stop_fallback_tween() -> void:
	if _fallback_tween and _fallback_tween.is_valid():
		_fallback_tween.kill()
	_fallback_tween = null

func _get_motion_target() -> Node:
	var target := get_mount_node()
	if target is Control or target is Node2D:
		return target
	return self

func _reset_motion_target() -> void:
	var target := _get_motion_target()
	target.set("position", Vector2.ZERO)
	target.set("scale", Vector2.ONE)
	target.set("rotation", 0.0)

func _get_animation_names_text() -> String:
	if animation_player == null:
		return "未配置 AnimationPlayer"
	var names := PackedStringArray()
	for animation_name in animation_player.get_animation_list():
		names.append(str(animation_name))
	if names.is_empty():
		return "无"
	return ", ".join(names)
