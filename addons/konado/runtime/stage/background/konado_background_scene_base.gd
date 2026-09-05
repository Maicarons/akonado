@tool
extends Control
class_name KonadoBackgroundSceneBase

## 背景场景基类。
## 背景切换时，系统只调用 enter/exit；具体是图片、视频、Spine、Live2D 或 shader，由场景内部决定。
## 内置的双纹理背景转场 shader 由 KonadoBackgroundTransitionLayer 统一处理；
## 这里更适合放背景自己的入场、退场、循环表现和自定义 effect 动画。

signal background_enter_finished
signal background_exit_finished

enum TransitionRenderMode {
	VIEWPORT_CAPTURE,
	DIRECT_TEXTURE,
}

## 可选动画播放器。存在 enter_<effect> 或 exit_<effect> 动画时优先播放。
@export var animation_player: AnimationPlayer
## 当没有对应动画时，非 none 效果默认用淡入淡出兜底，避免剧情卡住。
@export var use_default_fade: bool = true
@export var default_transition_duration: float = 0.35
## 内置 shader 转场的渲染方式。
## 默认使用 SubViewport 捕获完整场景，确保材质、染色、布局、相机和动态节点不会丢失。
## 只有当背景最终画面与 get_transition_texture() 返回的原始纹理完全等价时，
## 才能显式选择 DIRECT_TEXTURE 快速路径。
@export var transition_render_mode: TransitionRenderMode = TransitionRenderMode.VIEWPORT_CAPTURE

## 场景独立的染色加权系数（1.0 为默认，0 彻底无染色），没有特殊需求不用调整
@export var scene_tint_intensity: float = 1.0:
	set(value):
		scene_tint_intensity = clamp(value, 0.0, 2.0)

## 当无法从纹理中提取色调时，使用的默认环境色
@export var default_env_color: Color = Color.WHITE

var _transition_tween: Tween
var _active_animation: StringName = &""
var _active_phase: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if animation_player == null:
		animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if (
		animation_player
		and not animation_player.animation_finished.is_connected(_on_animation_finished)
	):
		animation_player.animation_finished.connect(_on_animation_finished)


func setup_background(_background_name: String, _params: Dictionary = {}) -> void:
	pass


## 给系统内置 shader 转场的显式快速路径和场景代表色计算使用的静态纹理。
## 默认会递归寻找第一个 TextureRect / Sprite2D。
## 注意：这里只返回原始纹理资源，不包含布局、变换、modulate、材质 shader 等场景表现。
func get_transition_texture() -> Texture2D:
	return _find_transition_texture(self)


## 是否明确允许转场层绕过场景捕获并直接使用原始纹理。
## 这是性能优化契约，而不是自动推断：自定义场景如有布局、裁剪、相机、动画、
## 多个可绘制节点、材质或染色，必须保持默认的 VIEWPORT_CAPTURE。
func can_use_direct_transition_texture() -> bool:
	return (
		transition_render_mode == TransitionRenderMode.DIRECT_TEXTURE
		and get_transition_texture() != null
	)


## 保留语义明确的查询接口，供转场层和自定义背景使用。
func requires_viewport_capture() -> bool:
	return not can_use_direct_transition_texture()


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


func _play_transition(phase: String, effect_name: String, params: Dictionary) -> void:
	stop_background_transition()
	_active_phase = phase
	var duration := float(params.get("duration", -1.0))
	if _play_animation_for_phase(phase, effect_name, duration):
		return
	if use_default_fade and effect_name != "none":
		_play_default_fade(phase, duration)
		return
	_finish_transition(phase)


func _play_animation_for_phase(phase: String, effect_name: String, duration: float) -> bool:
	if animation_player == null:
		return false
	var candidates := PackedStringArray()
	if not effect_name.is_empty():
		candidates.append("%s_%s" % [phase, effect_name])
	candidates.append(phase)
	for animation_name in candidates:
		if animation_player.has_animation(animation_name):
			_active_animation = StringName(animation_name)
			if duration == 0.0:
				_finish_transition(phase)
				return true
			var custom_speed := 1.0
			var animation := animation_player.get_animation(animation_name)
			if duration > 0.0 and animation != null and animation.length > 0.0:
				custom_speed = animation.length / duration
			animation_player.play(animation_name, -1.0, custom_speed)
			return true
	return false


func _play_default_fade(phase: String, duration_override: float = -1.0) -> void:
	var from_alpha := 0.0 if phase == "enter" else modulate.a
	var to_alpha := 1.0 if phase == "enter" else 0.0
	modulate.a = from_alpha
	_transition_tween = create_tween()
	var duration := duration_override if duration_override >= 0.0 else default_transition_duration
	_transition_tween.tween_property(self, "modulate:a", to_alpha, duration)
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


## 返回当前背景场景的代表色（环境光颜色）
func get_scene_tint_color() -> Color:
	var tex = get_transition_texture()
	if tex == null:
		return default_env_color
	return _calculate_average_color(tex)


## 从 Texture2D 中计算全图平均色
func _calculate_average_color(texture: Texture2D) -> Color:
	var img = texture.get_image()
	if img == null or img.is_empty():
		return Color.WHITE
	# 缩小到 1x1 线性插值，直接得到平均色
	img.resize(1, 1, Image.INTERPOLATE_BILINEAR)
	return img.get_pixel(0, 0)
