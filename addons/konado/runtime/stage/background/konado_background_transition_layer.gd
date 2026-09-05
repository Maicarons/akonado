@tool
extends Control

## 背景场景转场层。
## 旧版背景 shader 需要 current_texture / target_texture 两张纹理。
## 默认用两个 SubViewport 分别捕获旧背景和新背景的完整画面，再交给 shader 合成。
## 只有显式声明 DIRECT_TEXTURE 且能提供有效纹理的简单静态背景才绕过场景捕获。

signal transition_finished(
	old_background: KonadoBackgroundSceneBase, new_background: KonadoBackgroundSceneBase
)

const TRANSITION_CONFIGS := {
	"erase":
	{
		"shader":
		preload("res://addons/konado/assets/shaders/background_transitions/erase_effect.gdshader"),
		"duration": 1.0,
		"progress_target": 1.0,
		"tween_trans": Tween.TRANS_LINEAR,
	},
	"blinds":
	{
		"shader":
		preload("res://addons/konado/assets/shaders/background_transitions/blinds_effect.gdshader"),
		"duration": 1.0,
		"progress_target": 1.0,
		"tween_trans": Tween.TRANS_LINEAR,
	},
	"wave":
	{
		"shader":
		preload("res://addons/konado/assets/shaders/background_transitions/wave_effect.gdshader"),
		"duration": 1.0,
		"progress_target": 1.8,
		"tween_trans": Tween.TRANS_LINEAR,
	},
	"fade":
	{
		"shader":
		preload(
			"res://addons/konado/assets/shaders/background_transitions/alpha_fade_effect.gdshader"
		),
		"duration": 1.0,
		"progress_target": 1.0,
		"tween_trans": Tween.TRANS_LINEAR,
	},
	"vortex":
	{
		"shader":
		preload(
			"res://addons/konado/assets/shaders/background_transitions/vortex_swap_effect.gdshader"
		),
		"duration": 1.0,
		"progress_target": 1.0,
		"tween_trans": Tween.TRANS_LINEAR,
	},
	"windmill":
	{
		"shader":
		preload(
			"res://addons/konado/assets/shaders/background_transitions/windmill_effect.gdshader"
		),
		"duration": 1.0,
		"progress_target": 1.0,
		"tween_trans": Tween.TRANS_LINEAR,
	},
	"cyberglitch":
	{
		"shader":
		preload(
			"res://addons/konado/assets/shaders/background_transitions/cyber_glitch_effect.gdshader"
		),
		"duration": 1.0,
		"progress_target": 1.0,
		"tween_trans": Tween.TRANS_LINEAR,
	},
	"blink":
	{
		"shader":
		preload("res://addons/konado/assets/shaders/background_transitions/blink_effect.gdshader"),
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
var _old_background: KonadoBackgroundSceneBase
var _new_background: KonadoBackgroundSceneBase
var _is_transitioning: bool = false
var _transition_generation: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_ensure_shader_nodes()
	_sync_viewport_size()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_viewport_size()


func supports_effect(effect_name: String) -> bool:
	return TRANSITION_CONFIGS.has(effect_name)


func is_transitioning() -> bool:
	return _is_transitioning


func play_transition(
	old_background: KonadoBackgroundSceneBase,
	new_background: KonadoBackgroundSceneBase,
	effect_name: String,
	duration: float = -1.0
) -> void:
	if not supports_effect(effect_name):
		push_error("背景 shader 转场不存在：" + effect_name)
		transition_finished.emit(old_background, new_background)
		return
	if _is_transitioning:
		cancel_transition(true)
	else:
		cancel_transition(false)
	_ensure_shader_nodes()
	_sync_viewport_size()

	_old_background = old_background
	_new_background = new_background
	var generation := _transition_generation
	_is_transitioning = true
	visible = true
	_shader_rect.visible = false

	# 纹理快速路径必须由背景显式声明。默认使用 SubViewport 捕获完整场景，
	# 避免自动猜测漏掉布局、变换、相机、自定义绘制或运行时生成的视觉节点。
	if (
		_can_use_direct_transition_texture(_old_background)
		and _can_use_direct_transition_texture(_new_background)
	):
		var current_texture := _get_transition_texture(_old_background)
		var target_texture := _get_transition_texture(_new_background)
		if target_texture and (current_texture or _old_background == null):
			_set_viewport_capture_active(false)
			_start_shader_transition_with_textures(
				effect_name,
				current_texture if current_texture else _get_fallback_texture(),
				target_texture,
				generation,
				duration
			)
			return

	_ensure_capture_nodes()
	_sync_viewport_size()
	_set_viewport_capture_active(true)
	_prepare_viewport_root(_current_root)
	_prepare_viewport_root(_target_root)
	# 新背景先进 SubViewport 预热，旧背景此时仍留在舞台上，
	# 避免转场真正开始前舞台空出来闪几帧黑。
	_move_background_to_root(_new_background, _target_root)

	call_deferred("_start_shader_transition", effect_name, generation, duration)


func cancel_transition(queue_backgrounds: bool = true) -> void:
	# 先使所有已排队或正在 await 的旧任务失效，避免它们误操作下一次转场。
	_transition_generation += 1
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null
	_set_viewport_capture_active(false)
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


func _exit_tree() -> void:
	# 节点可能在两帧捕获预热期间离开场景树。统一取消会推进 generation，
	# 使已经连接到 process_frame 的旧协程在恢复后立即退出。
	# 待切入背景由转场层持有；直接纹理路径下它尚未挂入场景树，必须显式释放，
	# 否则销毁表演界面时会留下孤儿节点。旧背景仍属于正式舞台，不在这里处理。
	var staged_background := _new_background
	cancel_transition(false)
	if staged_background and is_instance_valid(staged_background):
		staged_background.queue_free()
	if _current_fallback and is_instance_valid(_current_fallback):
		var fallback_parent := _current_fallback.get_parent()
		if fallback_parent:
			fallback_parent.remove_child(_current_fallback)
		_current_fallback.free()
	_current_fallback = null


func _ensure_shader_nodes() -> void:
	if not is_instance_valid(_current_fallback):
		_current_fallback = ColorRect.new()
		_current_fallback.name = "CurrentFallback"
		_current_fallback.color = Color.BLACK
		_current_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not is_instance_valid(_shader_rect):
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


func _ensure_capture_nodes() -> void:
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


func _create_viewport(node_name: String) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = node_name
	viewport.disable_3d = true
	# 保留背景场景的 alpha，让转场结果继续与正式舞台的底色正确合成。
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
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
		# 清掉上一次转场可能残留的孤儿节点，_current_fallback 和本次参与转场的背景除外。
		if (
			child != _current_fallback
			and child != _old_background
			and child != _new_background
			and is_instance_valid(child)
		):
			child.queue_free()
	_set_full_rect(root, _get_transition_size())


func _move_background_to_root(background: KonadoBackgroundSceneBase, root: Control) -> void:
	if background == null:
		return
	var parent := background.get_parent()
	if parent:
		parent.remove_child(background)
	root.add_child(background)
	background.show()
	_set_full_rect(background, root.size)


func _start_shader_transition(effect_name: String, generation: int, duration: float) -> void:
	# call_deferred 可能在节点离开场景树后才真正调用，读取 process_frame 前先失效。
	if not _is_active_generation(generation):
		return
	await get_tree().process_frame
	if not _is_active_generation(generation):
		return
	await get_tree().process_frame
	if not _is_active_generation(generation):
		return

	# 旧背景拖到最后一刻才移入 SubViewport。SubViewport 会在父视口之前渲染，
	# 所以本帧显示 shader_rect 时 current_texture 已经是正确内容，舞台不会闪黑。
	if _old_background and is_instance_valid(_old_background):
		_move_background_to_root(_old_background, _current_root)
	else:
		var fallback_parent := _current_fallback.get_parent()
		if fallback_parent != _current_root:
			if fallback_parent:
				fallback_parent.remove_child(_current_fallback)
			_current_root.add_child(_current_fallback)
		_set_full_rect(_current_fallback, _current_viewport.size)
		_current_fallback.show()

	var config: Dictionary = TRANSITION_CONFIGS[effect_name]
	_shader_material.shader = config["shader"]
	_shader_material.set_shader_parameter("progress", 0.0)
	_shader_material.set_shader_parameter("current_texture", _current_viewport.get_texture())
	_shader_material.set_shader_parameter("target_texture", _target_viewport.get_texture())
	_shader_rect.visible = true

	_play_shader_tween(config, generation, duration)


func _start_shader_transition_with_textures(
	effect_name: String,
	current_texture: Texture2D,
	target_texture: Texture2D,
	generation: int,
	duration: float
) -> void:
	if not _is_active_generation(generation):
		return
	var config: Dictionary = TRANSITION_CONFIGS[effect_name]
	_shader_material.shader = config["shader"]
	_shader_material.set_shader_parameter("progress", 0.0)
	_shader_material.set_shader_parameter("current_texture", current_texture)
	_shader_material.set_shader_parameter("target_texture", target_texture)
	_shader_rect.visible = true
	_play_shader_tween(config, generation, duration)


func _play_shader_tween(config: Dictionary, generation: int, duration_override: float) -> void:
	if not _is_active_generation(generation):
		return
	var duration := duration_override if duration_override >= 0.0 else float(config["duration"])
	var progress_target := float(config["progress_target"])
	if duration <= 0.0:
		_finish_shader_transition(generation)
		return
	_transition_tween = create_tween()
	# set_trans 只影响之后创建的 tweener，必须放在 tween_property 之前。
	_transition_tween.set_trans(config["tween_trans"])
	_transition_tween.tween_property(
		_shader_material, "shader_parameter/progress", progress_target, duration
	)
	_transition_tween.finished.connect(
		_finish_shader_transition.bind(generation), ConnectFlags.CONNECT_ONE_SHOT
	)


func _finish_shader_transition(generation: int) -> void:
	if not _is_active_generation(generation):
		return
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null
	_set_viewport_capture_active(false)
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
	var viewport_size := _get_transition_size()
	if _current_viewport:
		_current_viewport.size = viewport_size
	if _target_viewport:
		_target_viewport.size = viewport_size
	if _current_root:
		_set_full_rect(_current_root, viewport_size)
		for child in _current_root.get_children():
			_set_full_rect(child as Control, viewport_size)
	if _target_root:
		_set_full_rect(_target_root, viewport_size)
		for child in _target_root.get_children():
			_set_full_rect(child as Control, viewport_size)
	if _shader_rect:
		_set_full_rect(_shader_rect, Vector2(viewport_size))


func _get_transition_size() -> Vector2i:
	var rect_size := size
	var parent_control := get_parent() as Control
	if (rect_size.x < 2.0 or rect_size.y < 2.0) and parent_control:
		rect_size = parent_control.size
	if rect_size.x < 2.0 or rect_size.y < 2.0:
		rect_size = get_viewport_rect().size
	return Vector2i(max(2, int(rect_size.x)), max(2, int(rect_size.y)))


func _get_transition_texture(background: KonadoBackgroundSceneBase) -> Texture2D:
	if background == null:
		return null
	return background.get_transition_texture()


func _can_use_direct_transition_texture(background: KonadoBackgroundSceneBase) -> bool:
	if background == null:
		return true
	return not background.requires_viewport_capture()


func _is_active_generation(generation: int) -> bool:
	return is_inside_tree() and _is_transitioning and generation == _transition_generation


func _set_viewport_capture_active(active: bool) -> void:
	var update_mode := SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if _current_viewport:
		_current_viewport.render_target_update_mode = update_mode
	if _target_viewport:
		_target_viewport.render_target_update_mode = update_mode


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
