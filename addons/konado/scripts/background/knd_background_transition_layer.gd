@tool
extends Control
class_name KND_BackgroundTransitionLayer

## 背景场景转场层。
## 旧版背景 shader 需要 current_texture / target_texture 两张纹理。
## 图片场景会优先直接提供纹理；视频、Live2D、Spine 等动态场景则用两个 SubViewport
## 分别承载旧背景场景和新背景场景，再把两个 ViewportTexture 交给 shader 合成。

signal transition_finished(old_background: KND_BackgroundSceneBase, new_background: KND_BackgroundSceneBase)

const TRANSITION_CONFIGS := {
	"erase": {
		"shader": preload("res://addons/konado/shader/bg_trans_effects/erase_effect.gdshader"),
		"duration": 1.0,
		"progress_target": 1.0,
		"tween_trans": Tween.TRANS_LINEAR,
	},
	"blinds": {
		"shader": preload("res://addons/konado/shader/bg_trans_effects/blinds_effect.gdshader"),
		"duration": 1.0,
		"progress_target": 1.0,
		"tween_trans": Tween.TRANS_LINEAR,
	},
	"wave": {
		"shader": preload("res://addons/konado/shader/bg_trans_effects/wave_effect.gdshader"),
		"duration": 1.0,
		"progress_target": 1.8,
		"tween_trans": Tween.TRANS_LINEAR,
	},
	"fade": {
		"shader": preload("res://addons/konado/shader/bg_trans_effects/alpha_fade_effect.gdshader"),
		"duration": 1.0,
		"progress_target": 1.0,
		"tween_trans": Tween.TRANS_LINEAR,
	},
	"vortex": {
		"shader": preload("res://addons/konado/shader/bg_trans_effects/vortex_swap_effect.gdshader"),
		"duration": 1.0,
		"progress_target": 1.0,
		"tween_trans": Tween.TRANS_LINEAR,
	},
	"windmill": {
		"shader": preload("res://addons/konado/shader/bg_trans_effects/windmill_effect.gdshader"),
		"duration": 1.0,
		"progress_target": 1.0,
		"tween_trans": Tween.TRANS_LINEAR,
	},
	"cyberglitch": {
		"shader": preload("res://addons/konado/shader/bg_trans_effects/cyber_glitch_effect.gdshader"),
		"duration": 1.0,
		"progress_target": 1.0,
		"tween_trans": Tween.TRANS_LINEAR,
	},
	"blink": {
		"shader": preload("res://addons/konado/shader/bg_trans_effects/blink_effect.gdshader"),
		"duration": 3.0,
		"progress_target": 1.0,
		"tween_trans": Tween.TRANS_LINEAR,
	},
}

var _current_viewport: SubViewport
var _target_viewport: SubViewport
var _current_root: Control
var _target_root: Control
var _current_fallback: ColorRect
var _shader_rect: ColorRect
var _shader_material: ShaderMaterial
var _transition_tween: Tween
var _fallback_texture: Texture2D
var _old_background: KND_BackgroundSceneBase
var _new_background: KND_BackgroundSceneBase
var _is_transitioning: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_ensure_nodes()
	_sync_viewport_size()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_viewport_size()

func supports_effect(effect_name: String) -> bool:
	return TRANSITION_CONFIGS.has(effect_name)

func is_transitioning() -> bool:
	return _is_transitioning

func play_transition(old_background: KND_BackgroundSceneBase, new_background: KND_BackgroundSceneBase, effect_name: String) -> void:
	if not supports_effect(effect_name):
		push_error("背景 shader 转场不存在：" + effect_name)
		transition_finished.emit(old_background, new_background)
		return
	if _is_transitioning:
		cancel_transition(true)
	else:
		cancel_transition(false)
	_ensure_nodes()
	_sync_viewport_size()

	_old_background = old_background
	_new_background = new_background
	_is_transitioning = true
	visible = true
	_shader_rect.visible = false

	var current_texture := _get_transition_texture(_old_background)
	var target_texture := _get_transition_texture(_new_background)
	if target_texture and (current_texture or _old_background == null):
		_start_shader_transition_with_textures(
			effect_name,
			current_texture if current_texture else _get_fallback_texture(),
			target_texture
		)
		return

	_prepare_viewport_root(_current_root)
	_prepare_viewport_root(_target_root)
	if _old_background:
		_move_background_to_root(_old_background, _current_root)
	else:
		_current_root.add_child(_current_fallback)
		_set_full_rect(_current_fallback, _current_viewport.size)
		_current_fallback.show()
	_move_background_to_root(_new_background, _target_root)

	call_deferred("_start_shader_transition", effect_name)

func cancel_transition(queue_backgrounds: bool = true) -> void:
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null
	visible = false
	_is_transitioning = false
	if _shader_rect:
		_shader_rect.visible = false
	if queue_backgrounds:
		if _old_background and is_instance_valid(_old_background):
			_old_background.queue_free()
		if _new_background and is_instance_valid(_new_background):
			_new_background.queue_free()
	_old_background = null
	_new_background = null
	if _current_fallback and _current_fallback.get_parent():
		_current_fallback.get_parent().remove_child(_current_fallback)

func _ensure_nodes() -> void:
	if _current_viewport == null:
		_current_viewport = _create_viewport("CurrentViewport")
		add_child(_current_viewport)
	if _current_root == null:
		_current_root = _create_viewport_root("CurrentRoot")
		_current_viewport.add_child(_current_root)
	if _target_viewport == null:
		_target_viewport = _create_viewport("TargetViewport")
		add_child(_target_viewport)
	if _target_root == null:
		_target_root = _create_viewport_root("TargetRoot")
		_target_viewport.add_child(_target_root)
	if _current_fallback == null:
		_current_fallback = ColorRect.new()
		_current_fallback.name = "CurrentFallback"
		_current_fallback.color = Color.BLACK
		_current_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _shader_rect == null:
		_shader_rect = ColorRect.new()
		_shader_rect.name = "ShaderRect"
		_shader_rect.color = Color.WHITE
		_shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shader_rect.visible = false
		_shader_material = ShaderMaterial.new()
		_shader_rect.material = _shader_material
		add_child(_shader_rect)
		_set_full_rect(_shader_rect)
	elif _shader_material == null:
		_shader_material = _shader_rect.material as ShaderMaterial
		if _shader_material == null:
			_shader_material = ShaderMaterial.new()
			_shader_rect.material = _shader_material

func _create_viewport(node_name: String) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = node_name
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	return viewport

func _create_viewport_root(node_name: String) -> Control:
	var root := Control.new()
	root.name = node_name
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_full_rect(root, _get_transition_size())
	return root

func _prepare_viewport_root(root: Control) -> void:
	for child in root.get_children():
		root.remove_child(child)
	_set_full_rect(root, _get_transition_size())

func _move_background_to_root(background: KND_BackgroundSceneBase, root: Control) -> void:
	if background == null:
		return
	var parent := background.get_parent()
	if parent:
		parent.remove_child(background)
	root.add_child(background)
	background.show()
	background.modulate.a = 1.0
	_set_full_rect(background, root.size)

func _start_shader_transition(effect_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not _is_transitioning:
		return
	var config: Dictionary = TRANSITION_CONFIGS[effect_name]
	_shader_material.shader = config["shader"]
	_shader_material.set_shader_parameter("progress", 0.0)
	_shader_material.set_shader_parameter("current_texture", _current_viewport.get_texture())
	_shader_material.set_shader_parameter("target_texture", _target_viewport.get_texture())
	_shader_rect.visible = true

	_play_shader_tween(config)

func _start_shader_transition_with_textures(effect_name: String, current_texture: Texture2D, target_texture: Texture2D) -> void:
	var config: Dictionary = TRANSITION_CONFIGS[effect_name]
	_shader_material.shader = config["shader"]
	_shader_material.set_shader_parameter("progress", 0.0)
	_shader_material.set_shader_parameter("current_texture", current_texture)
	_shader_material.set_shader_parameter("target_texture", target_texture)
	_shader_rect.visible = true
	_play_shader_tween(config)

func _play_shader_tween(config: Dictionary) -> void:
	var duration := float(config["duration"])
	var progress_target := float(config["progress_target"])
	if duration <= 0.0:
		_finish_shader_transition()
		return
	_transition_tween = create_tween()
	_transition_tween.tween_property(
		_shader_material,
		"shader_parameter/progress",
		progress_target,
		duration
	)
	_transition_tween.set_trans(config["tween_trans"])
	_transition_tween.finished.connect(_finish_shader_transition, ConnectFlags.CONNECT_ONE_SHOT)

func _finish_shader_transition() -> void:
	if not _is_transitioning:
		return
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null
	visible = false
	_shader_rect.visible = false
	_is_transitioning = false
	var old_background := _old_background
	var new_background := _new_background
	_old_background = null
	_new_background = null
	if _current_fallback and _current_fallback.get_parent():
		_current_fallback.get_parent().remove_child(_current_fallback)
	transition_finished.emit(old_background, new_background)

func _sync_viewport_size() -> void:
	if _current_viewport == null or _target_viewport == null:
		return
	var viewport_size := _get_transition_size()
	_current_viewport.size = viewport_size
	_target_viewport.size = viewport_size
	_set_full_rect(_current_root, viewport_size)
	_set_full_rect(_target_root, viewport_size)
	for child in _current_root.get_children():
		_set_full_rect(child as Control, viewport_size)
	for child in _target_root.get_children():
		_set_full_rect(child as Control, viewport_size)
	_set_full_rect(_shader_rect, Vector2(viewport_size))

func _get_transition_size() -> Vector2i:
	var rect_size := size
	var parent_control := get_parent() as Control
	if (rect_size.x < 2.0 or rect_size.y < 2.0) and parent_control:
		rect_size = parent_control.size
	if rect_size.x < 2.0 or rect_size.y < 2.0:
		rect_size = get_viewport_rect().size
	return Vector2i(max(2, int(rect_size.x)), max(2, int(rect_size.y)))

func _get_transition_texture(background: KND_BackgroundSceneBase) -> Texture2D:
	if background == null:
		return null
	return background.get_transition_texture()

func _get_fallback_texture() -> Texture2D:
	if _fallback_texture:
		return _fallback_texture
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	_fallback_texture = ImageTexture.create_from_image(image)
	return _fallback_texture

func _set_full_rect(control: Control, target_size: Vector2 = Vector2.ZERO) -> void:
	if control == null:
		return
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.position = Vector2.ZERO
	if target_size != Vector2.ZERO:
		control.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
		control.size = target_size
	else:
		control.set_anchors_preset(Control.PRESET_FULL_RECT, true)
		control.offset_left = 0.0
		control.offset_top = 0.0
		control.offset_right = 0.0
		control.offset_bottom = 0.0
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL
