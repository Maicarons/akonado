extends SceneTree

const BLEND_SHADER := preload("res://addons/konado/assets/shaders/character_state_blend.gdshader")
const VIEWPORT_SIZE := Vector2i(8, 8)
const SPATIAL_VIEWPORT_SIZE := Vector2i(12, 12)
const COLOR_TOLERANCE := 0.035

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var old_endpoint := await _render_blend(Color.RED, Color.BLUE, 0.0)
	_expect_color(old_endpoint, Color.RED, "progress zero renders the old frame")

	var new_endpoint := await _render_blend(Color.RED, Color.BLUE, 1.0)
	_expect_color(new_endpoint, Color.BLUE, "progress one renders the new frame")

	var opaque_midpoint := await _render_blend(Color.RED, Color.BLUE, 0.5)
	_expect_color(
		opaque_midpoint,
		Color(0.5, 0.0, 0.5, 1.0),
		"overlapping opaque frames crossfade without exposing the background"
	)

	var transparent_midpoint := await _render_blend(
		Color(1.0, 0.0, 0.0, 0.25), Color(0.0, 0.0, 1.0, 0.75), 0.5
	)
	_expect_color(
		transparent_midpoint,
		Color(0.125, 0.0, 0.375, 0.5),
		"semi-transparent frames interpolate in premultiplied-alpha space"
	)

	await _test_atlas_transform_and_flip()
	await _test_rotated_frame()
	await _test_constructed_region_sprite_sheet()
	await _test_constructed_nested_atlas()
	await _test_constructed_atlas_filter_clip()
	await _test_overlay_visual_transform()
	await _test_overlay_draw_order()
	await _test_overlay_outside_target_bounds()

	if _failures == 0:
		print("PASS: character transition rendering tests")
	quit(_failures)


func _render_blend(old_color: Color, new_color: Color, progress: float) -> Color:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.transparent_bg = true
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var blend_rect := ColorRect.new()
	blend_rect.color = Color.WHITE
	blend_rect.size = Vector2(VIEWPORT_SIZE)
	viewport.add_child(blend_rect)

	var material := ShaderMaterial.new()
	material.shader = BLEND_SHADER
	blend_rect.material = material
	var old_texture := _make_texture(old_color)
	var new_texture := _make_texture(new_color)
	material.set_shader_parameter("target_size", Vector2(VIEWPORT_SIZE))
	_set_frame_parameters(material, "old", old_texture)
	_set_frame_parameters(material, "new", new_texture)
	material.set_shader_parameter("progress", progress)

	await process_frame
	RenderingServer.force_draw(true)
	await process_frame
	var image := viewport.get_texture().get_image()
	var result := image.get_pixel(VIEWPORT_SIZE.x / 2, VIEWPORT_SIZE.y / 2)
	viewport.queue_free()
	await process_frame
	return result


func _set_frame_parameters(material: ShaderMaterial, prefix: String, texture: Texture2D) -> void:
	_set_spatial_frame_parameters(
		material,
		prefix,
		texture,
		Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE)),
		Transform2D.IDENTITY,
		Vector2.ZERO
	)


func _test_atlas_transform_and_flip() -> void:
	var texture := _make_quadrant_atlas()
	var frame_to_target := Transform2D(Vector2(2.0, 0.0), Vector2(0.0, 2.0), Vector2(2.0, 2.0))
	var image := await _render_spatial_frame(
		texture, Rect2(4.0, 0.0, 4.0, 4.0), frame_to_target, Vector2.ONE
	)
	_expect_color(
		image.get_pixel(3, 3),
		Color.YELLOW,
		"atlas frames honor scaling and horizontal/vertical flips"
	)
	_expect_color(
		image.get_pixel(8, 8), Color.RED, "flipped atlas frames preserve the opposite corner"
	)
	_expect_color(
		image.get_pixel(1, 3),
		Color(0.0, 0.0, 0.0, 0.0),
		"pixels outside transformed frames stay transparent"
	)


func _test_rotated_frame() -> void:
	var texture := _make_quadrant_atlas()
	var frame_to_target := Transform2D(Vector2(0.0, 1.0), Vector2(-1.0, 0.0), Vector2(6.0, 2.0))
	var image := await _render_spatial_frame(
		texture, Rect2(4.0, 0.0, 4.0, 4.0), frame_to_target, Vector2.ZERO
	)
	_expect_color(image.get_pixel(5, 2), Color.RED, "rotated frames preserve their first corner")
	_expect_color(
		image.get_pixel(2, 5), Color.YELLOW, "rotated frames preserve their opposite corner"
	)
	_expect_color(
		image.get_pixel(6, 2), Color(0.0, 0.0, 0.0, 0.0), "rotated frame bounds stay transparent"
	)


func _test_constructed_region_sprite_sheet() -> void:
	var texture := _make_column_atlas()
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = Rect2(4, 0, 12, 4)
	sprite.hframes = 3
	sprite.frame = 2
	sprite.centered = false
	sprite.position = Vector2(2, 3)
	var image := await _render_constructed_sprite(sprite)
	_expect_color(
		image.get_pixel(2, 3),
		Color.YELLOW,
		"constructed region sprite sheets render the selected frame"
	)
	_expect_color(
		image.get_pixel(6, 3),
		Color(0.0, 0.0, 0.0, 0.0),
		"constructed region sprite sheets keep pixels outside the selected frame transparent"
	)


func _test_constructed_nested_atlas() -> void:
	var texture := _make_column_atlas()
	var inner_atlas := AtlasTexture.new()
	inner_atlas.atlas = texture
	inner_atlas.region = Rect2(8, 0, 8, 4)
	var outer_atlas := AtlasTexture.new()
	outer_atlas.atlas = inner_atlas
	outer_atlas.region = Rect2(4, 0, 4, 4)
	var sprite := Sprite2D.new()
	sprite.texture = outer_atlas
	sprite.centered = false
	sprite.position = Vector2(3, 2)
	var image := await _render_constructed_sprite(sprite)
	_expect_color(
		image.get_pixel(3, 2), Color.YELLOW, "constructed nested atlases render the final region"
	)
	_expect_color(
		image.get_pixel(7, 2),
		Color(0.0, 0.0, 0.0, 0.0),
		"constructed nested atlases preserve their logical bounds"
	)


func _test_constructed_atlas_filter_clip() -> void:
	var texture := _make_column_atlas()
	for filter_clip in [false, true]:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(4, 0, 4, 4)
		atlas.filter_clip = filter_clip
		var sprite := Sprite2D.new()
		sprite.texture = atlas
		sprite.centered = false
		sprite.position = Vector2(3, 3)
		await _render_constructed_sprite(sprite, CanvasItem.TEXTURE_FILTER_LINEAR)


func _test_overlay_visual_transform() -> void:
	var viewport := SubViewport.new()
	viewport.size = SPATIAL_VIEWPORT_SIZE
	viewport.transparent_bg = true
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var host := Control.new()
	host.size = Vector2(SPATIAL_VIEWPORT_SIZE)
	viewport.add_child(host)
	var target := Control.new()
	target.size = Vector2(8.0, 8.0)
	target.position = Vector2(1.0, 1.0)
	target.offset_transform_position = Vector2(2.0, 1.0)
	target.offset_transform_position_ratio = Vector2(0.125, 0.125)
	target.offset_transform_enabled = true
	host.add_child(target)
	var sprite := Sprite2D.new()
	sprite.texture = _make_texture(Color("9467bd"))
	sprite.centered = false
	target.add_child(sprite)

	await process_frame
	RenderingServer.force_draw(true)
	await process_frame
	var live_image := viewport.get_texture().get_image()

	var controller := KonadoActorStateTransitionController.new(
		host,
		func() -> CanvasItem: return target,
		func(_status_name: String) -> bool: return true,
		func(_status_name: String) -> KonadoCharacterTransitionFrame:
			return KonadoCharacterTransitionFrame.from_sprite(sprite, target),
		func(_status_name: String) -> bool: return true
	)
	controller.request("same", 1.0, func(_succeeded: bool) -> void: pass)
	_expect(controller._blend_overlay != null, "visual offsets keep the frame-blend path")
	await process_frame
	RenderingServer.force_draw(true)
	await process_frame
	var blend_image := viewport.get_texture().get_image()
	_expect_images_equal(
		blend_image,
		live_image,
		"the blend overlay matches the live mount with Godot 4.7 visual offsets"
	)
	controller.cancel()
	controller = null
	viewport.queue_free()
	await process_frame


func _test_overlay_draw_order() -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.transparent_bg = true
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var host := ColorRect.new()
	host.size = Vector2(VIEWPORT_SIZE)
	host.color = Color("773344")
	viewport.add_child(host)
	var target := Control.new()
	target.size = Vector2(VIEWPORT_SIZE)
	target.show_behind_parent = true
	host.add_child(target)
	var sprite := Sprite2D.new()
	sprite.texture = _make_texture(Color("6a9bd8"))
	sprite.centered = false
	target.add_child(sprite)

	await process_frame
	RenderingServer.force_draw(true)
	await process_frame
	var live_image := viewport.get_texture().get_image()
	var controller := KonadoActorStateTransitionController.new(
		host,
		func() -> CanvasItem: return target,
		func(_status_name: String) -> bool: return true,
		func(_status_name: String) -> KonadoCharacterTransitionFrame:
			return KonadoCharacterTransitionFrame.from_sprite(sprite, target),
		func(_status_name: String) -> bool: return true
	)
	controller.request("same", 1.0, func(_succeeded: bool) -> void: pass)
	_expect(controller._blend_overlay != null, "behind-parent mounts keep the frame-blend path")
	await process_frame
	RenderingServer.force_draw(true)
	await process_frame
	_expect_images_equal(
		viewport.get_texture().get_image(),
		live_image,
		"the blend overlay preserves the live mount's behind-parent draw order"
	)
	controller.cancel()
	controller = null
	viewport.queue_free()
	await process_frame


func _test_overlay_outside_target_bounds() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(16, 12)
	viewport.transparent_bg = true
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var host := Control.new()
	host.size = Vector2(viewport.size)
	viewport.add_child(host)
	var target := Control.new()
	target.position = Vector2(6.0, 2.0)
	target.size = Vector2(4.0, 8.0)
	target.clip_contents = false
	host.add_child(target)
	var sprite := Sprite2D.new()
	sprite.texture = _make_texture(Color("b27ad9"))
	sprite.centered = false
	sprite.position = Vector2(-4.0, 0.0)
	target.add_child(sprite)

	await process_frame
	RenderingServer.force_draw(true)
	await process_frame
	var live_image := viewport.get_texture().get_image()
	var controller := KonadoActorStateTransitionController.new(
		host,
		func() -> CanvasItem: return target,
		func(_status_name: String) -> bool: return true,
		func(_status_name: String) -> KonadoCharacterTransitionFrame:
			return KonadoCharacterTransitionFrame.from_sprite(sprite, target),
		func(_status_name: String) -> bool: return true
	)
	controller.request("same", 1.0, func(_succeeded: bool) -> void: pass)
	_expect(controller._blend_overlay != null, "out-of-slot portraits keep the frame-blend path")
	await process_frame
	RenderingServer.force_draw(true)
	await process_frame
	_expect_images_equal(
		viewport.get_texture().get_image(),
		live_image,
		"the blend overlay preserves pixels drawn outside the target control bounds"
	)
	controller.cancel()
	controller = null
	viewport.queue_free()
	await process_frame


func _render_constructed_sprite(
	sprite: Sprite2D, texture_filter: CanvasItem.TextureFilter = CanvasItem.TEXTURE_FILTER_NEAREST
) -> Image:
	var viewport := SubViewport.new()
	viewport.size = SPATIAL_VIEWPORT_SIZE
	viewport.transparent_bg = true
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var target := Control.new()
	target.size = Vector2(SPATIAL_VIEWPORT_SIZE)
	target.texture_filter = texture_filter
	viewport.add_child(target)
	target.add_child(sprite)
	var frame := KonadoCharacterTransitionFrame.from_sprite(sprite, target)
	_expect(
		frame != null and frame.is_valid(), "constructed sprites produce valid transition frames"
	)
	await process_frame
	RenderingServer.force_draw(true)
	await process_frame
	var live_image := viewport.get_texture().get_image()
	sprite.visible = false

	var blend_rect := ColorRect.new()
	blend_rect.color = Color.WHITE
	blend_rect.size = Vector2(SPATIAL_VIEWPORT_SIZE)
	blend_rect.texture_filter = texture_filter
	viewport.add_child(blend_rect)
	if frame:
		var material := ShaderMaterial.new()
		material.shader = BLEND_SHADER
		blend_rect.material = material
		material.set_shader_parameter("target_size", Vector2(SPATIAL_VIEWPORT_SIZE))
		var controller := KonadoActorStateTransitionController.new(
			target, Callable(), func(_status_name: String) -> bool: return true
		)
		controller._set_frame_shader_parameters(material, "old", frame)
		controller._set_frame_shader_parameters(material, "new", frame)
		material.set_shader_parameter("progress", 0.5)

	await process_frame
	RenderingServer.force_draw(true)
	await process_frame
	var image := viewport.get_texture().get_image()
	_expect_images_equal(image, live_image, "constructed frames match live Sprite2D rendering")
	viewport.queue_free()
	await process_frame
	return image


func _render_spatial_frame(
	texture: Texture2D, region: Rect2, frame_to_target: Transform2D, flip: Vector2
) -> Image:
	var viewport := SubViewport.new()
	viewport.size = SPATIAL_VIEWPORT_SIZE
	viewport.transparent_bg = true
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)

	var blend_rect := ColorRect.new()
	blend_rect.color = Color.WHITE
	blend_rect.size = Vector2(SPATIAL_VIEWPORT_SIZE)
	blend_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(blend_rect)

	var material := ShaderMaterial.new()
	material.shader = BLEND_SHADER
	blend_rect.material = material
	material.set_shader_parameter("target_size", Vector2(SPATIAL_VIEWPORT_SIZE))
	_set_spatial_frame_parameters(material, "old", texture, region, frame_to_target, flip)
	_set_spatial_frame_parameters(material, "new", texture, region, frame_to_target, flip)
	material.set_shader_parameter("progress", 0.5)

	await process_frame
	RenderingServer.force_draw(true)
	await process_frame
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	await process_frame
	return image


func _set_spatial_frame_parameters(
	material: ShaderMaterial,
	prefix: String,
	texture: Texture2D,
	region: Rect2,
	frame_to_target: Transform2D,
	flip: Vector2
) -> void:
	var target_inverse := frame_to_target.affine_inverse()
	material.set_shader_parameter(prefix + "_texture", texture)
	material.set_shader_parameter(
		prefix + "_inverse_basis",
		Vector4(target_inverse.x.x, target_inverse.x.y, target_inverse.y.x, target_inverse.y.y)
	)
	material.set_shader_parameter(prefix + "_inverse_origin", target_inverse.origin)
	material.set_shader_parameter(
		prefix + "_region",
		Vector4(region.position.x, region.position.y, region.size.x, region.size.y)
	)
	material.set_shader_parameter(
		prefix + "_clip_region",
		Vector4(region.position.x, region.position.y, region.size.x, region.size.y)
	)
	material.set_shader_parameter(prefix + "_filter_clip", true)
	material.set_shader_parameter(prefix + "_texture_size", Vector2(texture.get_size()))
	material.set_shader_parameter(prefix + "_flip", flip)
	material.set_shader_parameter(prefix + "_modulate", Color.WHITE)


func _make_texture(color: Color) -> Texture2D:
	var image := Image.create(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _make_quadrant_atlas() -> Texture2D:
	var image := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(4, 0, 2, 2), Color.RED)
	image.fill_rect(Rect2i(6, 0, 2, 2), Color.GREEN)
	image.fill_rect(Rect2i(4, 2, 2, 2), Color.BLUE)
	image.fill_rect(Rect2i(6, 2, 2, 2), Color.YELLOW)
	return ImageTexture.create_from_image(image)


func _make_column_atlas() -> Texture2D:
	var image := Image.create(16, 4, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(0, 0, 4, 4), Color.RED)
	image.fill_rect(Rect2i(4, 0, 4, 4), Color.GREEN)
	image.fill_rect(Rect2i(8, 0, 4, 4), Color.BLUE)
	image.fill_rect(Rect2i(12, 0, 4, 4), Color.YELLOW)
	return ImageTexture.create_from_image(image)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("FAIL: " + message)


func _expect_color(actual: Color, expected: Color, message: String) -> void:
	if (
		absf(actual.r - expected.r) <= COLOR_TOLERANCE
		and absf(actual.g - expected.g) <= COLOR_TOLERANCE
		and absf(actual.b - expected.b) <= COLOR_TOLERANCE
		and absf(actual.a - expected.a) <= COLOR_TOLERANCE
	):
		return
	_failures += 1
	printerr("FAIL: %s\n  expected: %s\n  actual:   %s" % [message, expected, actual])


func _expect_images_equal(actual: Image, expected: Image, message: String) -> void:
	if actual.get_size() != expected.get_size():
		_failures += 1
		printerr("FAIL: %s (image sizes differ)" % message)
		return
	for y in range(actual.get_height()):
		for x in range(actual.get_width()):
			var actual_color := actual.get_pixel(x, y)
			var expected_color := expected.get_pixel(x, y)
			if (
				absf(actual_color.r - expected_color.r) <= COLOR_TOLERANCE
				and absf(actual_color.g - expected_color.g) <= COLOR_TOLERANCE
				and absf(actual_color.b - expected_color.b) <= COLOR_TOLERANCE
				and absf(actual_color.a - expected_color.a) <= COLOR_TOLERANCE
			):
				continue
			_failures += 1
			printerr(
				(
					"FAIL: %s at (%d, %d)\n  expected: %s\n  actual:   %s"
					% [message, x, y, expected_color, actual_color]
				)
			)
			return
