extends SceneTree

const PARALLAX_BACKGROUND_SCENE := preload("res://sample/demo/backgrounds/background_parallax.tscn")
const CAMERA_CONTROLLER_SCRIPT := preload(
	"res://addons/konado/runtime/camera/konado_camera_controller.gd"
)
const BACKGROUND_TRANSITION_LAYER_SCRIPT := preload(
	"res://addons/konado/runtime/stage/background/konado_background_transition_layer.gd"
)

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_safe_capture_contract()
	await _test_camera_marker_contract()
	await _test_parallax_camera_markers_during_transition()
	await _test_custom_rendering_camera_during_transition()
	await _test_transition_generation_and_viewport_lifecycle()
	await _test_direct_texture_fast_path()
	await _test_exit_tree_invalidates_deferred_transition()
	await _test_acting_interface_transition_lifecycle()
	await _test_orphan_cleanup()
	if _failures == 0:
		print("PASS: background transition layer tests")
	quit(_failures)


func _test_safe_capture_contract() -> void:
	var default_background := _make_background(false)
	_expect(
		default_background.requires_viewport_capture(),
		"backgrounds use full viewport capture by default",
	)
	_expect(
		not default_background.can_use_direct_transition_texture(),
		"default backgrounds cannot enter the direct texture path",
	)

	default_background.transition_render_mode = (
		KonadoBackgroundSceneBase.TransitionRenderMode.DIRECT_TEXTURE
	)
	_expect(
		default_background.can_use_direct_transition_texture(),
		"backgrounds can explicitly opt into the direct texture contract",
	)

	var no_texture_background := KonadoBackgroundSceneBase.new()
	no_texture_background.transition_render_mode = (
		KonadoBackgroundSceneBase.TransitionRenderMode.DIRECT_TEXTURE
	)
	_expect(
		not no_texture_background.can_use_direct_transition_texture(),
		"direct texture mode still requires a valid transition texture",
	)

	var parallax_background := PARALLAX_BACKGROUND_SCENE.instantiate() as KonadoBackgroundSceneBase
	_expect(
		parallax_background.requires_viewport_capture(),
		"the bundled parallax and camera background stays on the safe capture path",
	)

	default_background.free()
	no_texture_background.free()
	parallax_background.free()


func _test_camera_marker_contract() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 180)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background_container := Node.new()
	viewport.add_child(background_container)
	var background := KonadoBackgroundSceneBase.new()
	background_container.add_child(background)

	var marker := KonadoCameraMarker.new()
	marker.marker_id = "close_up"
	marker.position = Vector2(128.0, 72.0)
	marker.zoom = Vector2(1.5, 1.5)
	marker.enabled = true
	background.add_child(marker)
	await process_frame
	_expect(
		not marker.enabled,
		"KonadoCameraMarker disables rendering when it enters the scene tree",
	)
	_expect_equal(
		viewport.get_camera_2d(),
		null,
		"a Konado camera marker never takes over its viewport",
	)

	var render_camera := Camera2D.new()
	render_camera.position = Vector2(10.0, 20.0)
	viewport.add_child(render_camera)
	await process_frame
	_expect(render_camera.enabled, "an ordinary Camera2D remains available for custom rendering")
	_expect_equal(
		viewport.get_camera_2d(),
		render_camera,
		"the marker contract does not disable a custom rendering camera",
	)

	var manager := CAMERA_CONTROLLER_SCRIPT.new()
	manager.active_camera = render_camera
	manager.marker_root = background_container
	viewport.add_child(manager)
	_expect_equal(manager.camera_markers.size(), 1, "the disabled marker remains discoverable")
	manager.move_to_marker("close_up", 0.0)
	await process_frame
	_expect_equal(
		render_camera.position,
		marker.position,
		"camera commands still copy the disabled marker position to the rendering camera",
	)
	_expect_equal(
		render_camera.zoom,
		marker.zoom,
		"camera commands still copy the disabled marker zoom to the rendering camera",
	)

	background_container.remove_child(background)
	background.free()
	var replacement_background := KonadoBackgroundSceneBase.new()
	background_container.add_child(replacement_background)
	var replacement_marker := KonadoCameraMarker.new()
	replacement_marker.marker_id = "close_up"
	replacement_marker.position = Vector2(48.0, 36.0)
	replacement_marker.zoom = Vector2(0.8, 0.8)
	replacement_background.add_child(replacement_marker)
	_expect(
		manager.move_to_marker_async("close_up", 0.0),
		"camera commands replace a same-name stale marker without an external refresh",
	)
	await process_frame
	_expect_equal(
		render_camera.position,
		replacement_marker.position,
		"the replacement marker owns the next asynchronous camera move",
	)
	_expect(not manager.move_to_marker("missing", 0.0), "missing markers reject the command")
	_expect(
		manager.get_last_error().contains("可用机位：close_up"),
		"marker failures expose the live set of available markers",
	)
	await _free_node(viewport)


func _test_parallax_camera_markers_during_transition() -> void:
	var fixture := await _create_layer_fixture()
	var host := fixture["host"] as Control
	var layer := fixture["layer"] as BACKGROUND_TRANSITION_LAYER_SCRIPT
	var background := PARALLAX_BACKGROUND_SCENE.instantiate() as KonadoBackgroundSceneBase
	var markers := _find_camera_markers(background)
	_expect_equal(markers.size(), 2, "the bundled parallax scene exposes both camera targets")

	layer.play_transition(null, background, "fade")
	await process_frame
	_expect(
		_all_markers_disabled(markers),
		"camera targets stay disabled while the background is captured",
	)
	_expect_equal(
		layer._target_viewport.get_camera_2d(),
		null,
		"camera targets cannot offset the target SubViewport capture",
	)

	var replacement := PARALLAX_BACKGROUND_SCENE.instantiate() as KonadoBackgroundSceneBase
	var replacement_markers := _find_camera_markers(replacement)
	layer.play_transition(null, replacement, "wave")
	await process_frame
	_expect(
		_all_markers_disabled(replacement_markers),
		"replacement transitions preserve the non-rendering marker contract",
	)
	_expect_equal(
		layer._target_viewport.get_camera_2d(),
		null,
		"a replacement capture is not displaced by its camera targets",
	)
	layer._finish_shader_transition(layer._transition_generation)
	_expect(
		_all_markers_disabled(replacement_markers),
		"completed transitions never reactivate camera targets",
	)
	await _free_node(host)


func _test_custom_rendering_camera_during_transition() -> void:
	var fixture := await _create_layer_fixture()
	var host := fixture["host"] as Control
	var layer := fixture["layer"] as BACKGROUND_TRANSITION_LAYER_SCRIPT
	var background := _make_background(false)
	var marker := KonadoCameraMarker.new()
	marker.position = Vector2(96.0, 54.0)
	marker.enabled = true
	background.add_child(marker)
	var render_camera := Camera2D.new()
	render_camera.position = Vector2(160.0, 90.0)
	background.add_child(render_camera)

	layer.play_transition(null, background, "fade")
	await process_frame
	_expect(not marker.enabled, "the camera target remains a marker during capture")
	_expect(
		render_camera.enabled,
		"viewport capture preserves a custom rendering camera's authored state",
	)
	_expect_equal(
		layer._target_viewport.get_camera_2d(),
		render_camera,
		"viewport capture uses the custom rendering camera instead of a marker",
	)
	layer._finish_shader_transition(layer._transition_generation)
	_expect(
		render_camera.enabled,
		"completing a transition does not rewrite a custom rendering camera's state",
	)
	await _free_node(host)


func _test_transition_generation_and_viewport_lifecycle() -> void:
	var fixture := await _create_layer_fixture()
	var host := fixture["host"] as Control
	var layer := fixture["layer"] as BACKGROUND_TRANSITION_LAYER_SCRIPT
	var first_old := _make_background(false)
	var first_new := _make_background(false)
	host.add_child(first_old)

	layer.play_transition(first_old, first_new, "fade")
	var first_generation := layer._transition_generation
	_expect(
		layer._current_viewport != null and layer._target_viewport != null,
		"the safe capture path creates its viewports on demand",
	)
	_expect(
		layer._current_viewport.transparent_bg and layer._target_viewport.transparent_bg,
		"capture viewports preserve scene transparency",
	)
	_expect_equal(
		layer._current_viewport.render_target_update_mode,
		SubViewport.UPDATE_ALWAYS,
		"viewport capture is active while a safe-path transition is staged",
	)

	var replacement := _make_background(false)
	layer.play_transition(null, replacement, "wave")
	var replacement_generation := layer._transition_generation
	_expect(
		replacement_generation > first_generation,
		"starting a replacement transition advances its generation",
	)

	await process_frame
	await process_frame
	await process_frame

	_expect(
		layer._is_active_generation(replacement_generation),
		"only the replacement transition remains active after deferred staging",
	)
	_expect_equal(
		layer._new_background,
		replacement,
		"a stale deferred transition cannot replace the current background reference",
	)
	_expect_equal(
		layer._shader_material.shader,
		layer.TRANSITION_CONFIGS["wave"]["shader"],
		"a stale deferred transition cannot overwrite the replacement effect",
	)
	_expect(
		layer._transition_tween != null and layer._transition_tween.is_valid(),
		"the replacement transition owns one valid tween",
	)

	layer.cancel_transition(true)
	_expect_equal(
		layer._current_viewport.render_target_update_mode,
		SubViewport.UPDATE_DISABLED,
		"cancelling a transition disables the current capture viewport",
	)
	_expect_equal(
		layer._target_viewport.render_target_update_mode,
		SubViewport.UPDATE_DISABLED,
		"cancelling a transition disables the target capture viewport",
	)
	await _free_node(host)


func _test_direct_texture_fast_path() -> void:
	var fixture := await _create_layer_fixture()
	var host := fixture["host"] as Control
	var layer := fixture["layer"] as BACKGROUND_TRANSITION_LAYER_SCRIPT
	var old_background := _make_background(true)
	var new_background := _make_background(true)
	var completions: Array[Array] = []
	layer.transition_finished.connect(
		func(old_value: KonadoBackgroundSceneBase, new_value: KonadoBackgroundSceneBase) -> void:
			completions.append([old_value, new_value])
	)
	host.add_child(old_background)
	_expect(
		layer._current_viewport == null and layer._target_viewport == null,
		"an idle transition layer does not allocate capture viewports",
	)

	layer.play_transition(old_background, new_background, "fade")
	_expect(
		layer._shader_rect.visible,
		"an explicitly declared direct texture transition starts immediately",
	)
	_expect(
		layer._current_viewport == null and layer._target_viewport == null,
		"the direct texture path never allocates capture viewports",
	)

	layer._finish_shader_transition(layer._transition_generation)
	_expect_equal(completions.size(), 1, "a completed transition emits exactly one completion")
	_expect_equal(
		completions[0],
		[old_background, new_background],
		"the completion signal preserves the transition background pair",
	)
	_expect(
		not layer.is_transitioning(),
		"finishing a direct texture transition clears its active state",
	)
	new_background.free()
	await _free_node(host)


func _test_exit_tree_invalidates_deferred_transition() -> void:
	var fixture := await _create_layer_fixture()
	var host := fixture["host"] as Control
	var layer := fixture["layer"] as BACKGROUND_TRANSITION_LAYER_SCRIPT
	var staged_background := _make_background(false)

	layer.play_transition(null, staged_background, "fade")
	var active_generation := layer._transition_generation
	host.remove_child(layer)
	_expect(
		layer._transition_generation > active_generation,
		"leaving the scene tree invalidates deferred transition work",
	)
	_expect(
		not layer.is_transitioning(),
		"leaving the scene tree clears the active transition state",
	)
	_expect_equal(
		layer._current_viewport.render_target_update_mode,
		SubViewport.UPDATE_DISABLED,
		"leaving the scene tree disables the current capture viewport",
	)
	_expect_equal(
		layer._target_viewport.render_target_update_mode,
		SubViewport.UPDATE_DISABLED,
		"leaving the scene tree disables the target capture viewport",
	)

	await process_frame
	await process_frame
	await process_frame
	_expect(
		layer._transition_tween == null,
		"a deferred transition cannot create a tween after leaving the scene tree",
	)
	_expect(
		not is_instance_valid(staged_background),
		"leaving the scene tree releases the staged capture-path background",
	)

	host.add_child(layer)
	var replacement := _make_background(false)
	layer.play_transition(null, replacement, "wave")
	await process_frame
	await process_frame
	await process_frame
	_expect(
		layer._transition_tween != null and layer._transition_tween.is_valid(),
		"the transition layer remains reusable after being attached again",
	)
	layer.cancel_transition(true)

	var direct_background := _make_background(true)
	layer.play_transition(null, direct_background, "fade")
	_expect(
		direct_background.get_parent() == null,
		"the direct texture background is not mounted before completion",
	)
	host.remove_child(layer)
	await process_frame
	_expect(
		not is_instance_valid(direct_background),
		"leaving the scene tree releases an unparented direct texture background",
	)
	layer.free()
	await _free_node(host)


func _test_acting_interface_transition_lifecycle() -> void:
	var acting := KonadoStageController.new()
	acting.size = Vector2(320.0, 180.0)
	root.add_child(acting)
	await process_frame

	var first_modulate := Color(0.25, 0.5, 0.75, 0.45)
	var first_scene := _make_background_scene(first_modulate)
	var second_modulate := Color(0.8, 0.35, 0.65, 0.6)
	var second_scene := _make_background_scene(second_modulate)
	var no_effect := KonadoStageController.BackgroundTransitionEffect.NONE
	var fade_effect := KonadoStageController.BackgroundTransitionEffect.ALPHA_FADE
	acting.change_background_scene(first_scene, "first", no_effect)
	var old_background := acting.get_current_background()
	_expect(old_background != null, "the initial background is installed on the acting stage")

	var completions := [0]
	acting.background_change_finished.connect(func(_succeeded: bool) -> void: completions[0] += 1)
	acting.change_background_scene(second_scene, "second", fade_effect)
	var staged_background := acting.get_pending_background()
	_expect(staged_background != null, "the replacement background is staged for shader capture")
	_expect_equal(
		old_background.get_parent(),
		acting._background_container,
		"the visible background remains on stage while the replacement is prepared",
	)
	_expect_equal(
		staged_background.get_parent(),
		acting._background_transition_layer._target_root,
		"the replacement background is prepared in the target capture viewport",
	)
	_expect(
		not acting._background_transition_layer._shader_rect.visible,
		"the shader stays hidden until both capture inputs are ready",
	)

	var shader_started := await _wait_until(
		func() -> bool:
			return (
				is_instance_valid(acting)
				and acting._background_transition_layer._shader_rect.visible
			),
		1000,
	)
	_expect(shader_started, "the staged transition starts through the real deferred path")
	if shader_started:
		_expect_equal(
			old_background.get_parent(),
			acting._background_transition_layer._current_root,
			"the old background moves into capture only when the shader becomes visible",
		)
		_expect_color_equal(
			old_background.modulate,
			first_modulate,
			"viewport capture preserves the outgoing background's current modulate value",
		)

	var transition_completed := await _wait_until(func() -> bool: return completions[0] == 1, 2500)
	_expect(transition_completed, "the real tween completes and notifies the acting interface")
	if transition_completed:
		var current_background := acting.get_current_background()
		_expect_equal(
			current_background,
			staged_background,
			"the completed replacement becomes the acting interface's current background",
		)
		_expect_equal(
			current_background.get_parent(),
			acting._background_container,
			"the completed background returns to the permanent stage container",
		)
		_expect_color_equal(
			current_background.modulate,
			second_modulate,
			"viewport capture preserves the background's authored modulate value",
		)
		_expect_equal(
			acting._background_transition_layer._current_viewport.render_target_update_mode,
			SubViewport.UPDATE_DISABLED,
			"the current capture viewport is disabled after acting integration completes",
		)
		_expect_equal(
			acting._background_transition_layer._target_viewport.render_target_update_mode,
			SubViewport.UPDATE_DISABLED,
			"the target capture viewport is disabled after acting integration completes",
		)

	await process_frame
	_expect(
		not is_instance_valid(old_background),
		"the acting interface releases the replaced background after completion",
	)
	await _free_node(acting)


func _test_orphan_cleanup() -> void:
	var fixture := await _create_layer_fixture()
	var host := fixture["host"] as Control
	var layer := fixture["layer"] as BACKGROUND_TRANSITION_LAYER_SCRIPT
	var orphan := Control.new()
	layer._ensure_capture_nodes()
	layer._current_root.add_child(orphan)

	layer._prepare_viewport_root(layer._current_root)
	await process_frame
	_expect(
		not is_instance_valid(orphan),
		"preparing a capture root frees an unowned leftover background",
	)
	await _free_node(host)


func _create_layer_fixture() -> Dictionary:
	var host := Control.new()
	host.size = Vector2(320.0, 180.0)
	root.add_child(host)
	var layer := BACKGROUND_TRANSITION_LAYER_SCRIPT.new()
	layer.size = host.size
	host.add_child(layer)
	await process_frame
	return {"host": host, "layer": layer}


func _make_background(direct_texture: bool) -> KonadoBackgroundSceneBase:
	var background := KonadoBackgroundSceneBase.new()
	background.size = Vector2(320.0, 180.0)
	if direct_texture:
		background.transition_render_mode = (
			KonadoBackgroundSceneBase.TransitionRenderMode.DIRECT_TEXTURE
		)
	var texture_rect := TextureRect.new()
	texture_rect.texture = _make_texture()
	background.add_child(texture_rect)
	return background


func _make_background_scene(background_modulate: Color) -> PackedScene:
	var background := _make_background(false)
	background.modulate = background_modulate
	var texture_rect := background.get_child(0)
	texture_rect.owner = background
	var scene := PackedScene.new()
	_expect_equal(
		scene.pack(background),
		OK,
		"a generated background fixture can be packed",
	)
	background.free()
	return scene


func _make_texture() -> Texture2D:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color("684c9e"))
	return ImageTexture.create_from_image(image)


func _find_camera_markers(background: Node) -> Array[KonadoCameraMarker]:
	var markers: Array[KonadoCameraMarker] = []
	for node in background.find_children("*", "Camera2D", true, false):
		if node is KonadoCameraMarker:
			markers.append(node)
	return markers


func _all_markers_disabled(markers: Array[KonadoCameraMarker]) -> bool:
	for marker in markers:
		if marker.enabled:
			return false
	return true


func _wait_until(predicate: Callable, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not bool(predicate.call()) and Time.get_ticks_msec() < deadline:
		await process_frame
	return bool(predicate.call())


func _free_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await process_frame
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	printerr("ASSERTION FAILED: " + message)
	_failures += 1


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	_expect(actual == expected, "%s (expected %s, got %s)" % [message, expected, actual])


func _expect_color_equal(actual: Color, expected: Color, message: String) -> void:
	_expect(
		actual.is_equal_approx(expected),
		"%s (expected %s, got %s)" % [message, expected, actual],
	)
