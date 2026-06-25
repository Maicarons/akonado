@tool
extends Control
class_name KND_BackgroundSceneBase

## 背景场景基类。
## 背景切换时，系统只调用 enter/exit；具体是图片、视频、Spine、Live2D 或 shader，由场景内部决定。
## 内置的双纹理背景转场 shader 由 KND_BackgroundTransitionLayer 统一处理；
## 这里更适合放背景自己的入场、退场、循环表现和自定义 effect 动画。

signal background_enter_finished
signal background_exit_finished

## 可选动画播放器。存在 enter_<effect> 或 exit_<effect> 动画时优先播放。
@export var animation_player: AnimationPlayer
## 当没有对应动画时，非 none 效果默认用淡入淡出兜底，避免剧情卡住。
@export var use_default_fade: bool = true
@export var default_transition_duration: float = 0.35

var _transition_tween: Tween
var _active_animation: StringName = &""
var _active_phase: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if animation_player == null:
		animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player and not animation_player.animation_finished.is_connected(_on_animation_finished):
		animation_player.animation_finished.connect(_on_animation_finished)

func setup_background(_background_name: String, _params: Dictionary = {}) -> void:
	pass

## 给系统内置 shader 转场使用的静态纹理。
## 图片背景默认会递归寻找第一个 TextureRect / Sprite2D；视频、Live2D、Spine 等动态场景可保持为空，
## 交给 KND_BackgroundTransitionLayer 使用 SubViewport 渲染。
func get_transition_texture() -> Texture2D:
	return _find_transition_texture(self)

func play_enter(effect_name: String = "none", params: Dictionary = {}) -> void:
	_play_transition("enter", effect_name, params)

func play_exit(effect_name: String = "none", params: Dictionary = {}) -> void:
	_play_transition("exit", effect_name, params)

func stop_background_transition() -> void:
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null
	if animation_player:
		animation_player.stop()
	_active_animation = &""
	_active_phase = ""

func _play_transition(phase: String, effect_name: String, _params: Dictionary) -> void:
	stop_background_transition()
	_active_phase = phase
	if _play_animation_for_phase(phase, effect_name):
		return
	if use_default_fade and effect_name != "none":
		_play_default_fade(phase)
		return
	_finish_transition(phase)

func _play_animation_for_phase(phase: String, effect_name: String) -> bool:
	if animation_player == null:
		return false
	var candidates := PackedStringArray()
	if not effect_name.is_empty():
		candidates.append("%s_%s" % [phase, effect_name])
	candidates.append(phase)
	for animation_name in candidates:
		if animation_player.has_animation(animation_name):
			_active_animation = StringName(animation_name)
			animation_player.play(animation_name)
			return true
	return false

func _play_default_fade(phase: String) -> void:
	var from_alpha := 0.0 if phase == "enter" else modulate.a
	var to_alpha := 1.0 if phase == "enter" else 0.0
	modulate.a = from_alpha
	_transition_tween = create_tween()
	_transition_tween.tween_property(self, "modulate:a", to_alpha, default_transition_duration)
	_transition_tween.finished.connect(_finish_transition.bind(phase))

func _finish_transition(phase: String) -> void:
	_transition_tween = null
	_active_animation = &""
	_active_phase = ""
	if phase == "enter":
		background_enter_finished.emit()
	else:
		background_exit_finished.emit()

func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name != _active_animation:
		return
	_finish_transition(_active_phase)

func _find_transition_texture(node: Node) -> Texture2D:
	if node is TextureRect:
		var texture_rect := node as TextureRect
		if texture_rect.texture:
			return texture_rect.texture
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.texture:
			return sprite.texture
	for child in node.get_children():
		var texture := _find_transition_texture(child)
		if texture:
			return texture
	return null
