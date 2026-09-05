extends SceneTree

var _failures := 0


class ExtendedTransitionFrame:
	extends KonadoCharacterTransitionFrame

	func is_valid() -> bool:
		return true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_frame_contract()
	_test_frame_type_boundary()
	if _failures == 0:
		print("PASS: character transition frame tests")
	quit(_failures)


func _test_frame_contract() -> void:
	var target := Control.new()
	target.size = Vector2(320.0, 180.0)
	target.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sprite := Sprite2D.new()
	sprite.texture = _make_texture(Color.WHITE)
	sprite.position = Vector2(32.0, 48.0)
	sprite.modulate = Color(0.8, 0.9, 1.0, 0.75)
	sprite.self_modulate = Color(0.5, 1.0, 0.8, 0.5)
	sprite.visibility_layer = 5
	sprite.light_mask = 9
	target.add_child(sprite)
	get_root().add_child(target)
	var frame := KonadoCharacterTransitionFrame.from_sprite(sprite, target)
	_expect(frame != null and frame.is_valid(), "static sprites expose safe transition frames")
	if frame:
		_expect_equal(frame.source_visual, sprite, "frames retain only the source visual")
		_expect_equal(frame.texture, sprite.texture, "frames reuse immutable textures")
		_expect_equal(
			frame.texture_filter,
			CanvasItem.TEXTURE_FILTER_NEAREST,
			"frames preserve the effective texture filter"
		)
		_expect_equal(
			frame.modulate,
			sprite.modulate * sprite.self_modulate,
			"frames preserve the source node's effective color"
		)
		_expect_equal(
			frame.get_target_bounds(),
			Rect2(28.0, 44.0, 8.0, 8.0),
			"frames derive their complete transformed bounds in target space"
		)
		_expect_equal(
			frame.visibility_layer,
			sprite.visibility_layer,
			"frames preserve the source visibility layer"
		)
		_expect_equal(frame.light_mask, sprite.light_mask, "frames preserve the source light mask")
		var controller := KonadoActorStateTransitionController.new(
			target,
			func() -> CanvasItem: return target,
			func(_status_name: String) -> bool: return true
		)
		controller._active_visual = target
		_expect(
			not controller._can_blend_frames(frame, frame),
			"a mutable frame instance cannot represent both transition endpoints"
		)
		sprite.visible = false
		_expect(
			not controller._is_valid_transition_frame(frame),
			"frames are rejected if their source becomes hidden before blending"
		)
		sprite.visible = true
		controller = null

	var atlas_image := Image.create(16, 8, false, Image.FORMAT_RGBA8)
	atlas_image.fill(Color.TRANSPARENT)
	atlas_image.fill_rect(Rect2i(8, 0, 8, 8), Color.WHITE)
	var atlas_texture := ImageTexture.create_from_image(atlas_image)
	var atlas_region := AtlasTexture.new()
	atlas_region.atlas = atlas_texture
	atlas_region.region = Rect2(8, 0, 8, 8)
	atlas_region.filter_clip = false
	sprite.texture = atlas_region
	var atlas_frame := KonadoCharacterTransitionFrame.from_sprite(sprite, target)
	_expect(atlas_frame != null and atlas_frame.is_valid(), "atlas states expose safe frames")
	if atlas_frame:
		_expect_equal(atlas_frame.texture, atlas_texture, "atlas frames sample backing textures")
		_expect_equal(
			atlas_frame.source_region,
			Rect2(8, 0, 8, 8),
			"atlas frames preserve backing texture regions"
		)
		_expect(not atlas_frame.filter_clip, "unclipped atlases preserve neighbor filtering")

	atlas_region.filter_clip = true
	var clipped_atlas_frame := KonadoCharacterTransitionFrame.from_sprite(sprite, target)
	_expect(
		clipped_atlas_frame != null and clipped_atlas_frame.is_valid(),
		"filter-clipped atlases expose safe frames"
	)
	if clipped_atlas_frame:
		_expect(clipped_atlas_frame.filter_clip, "atlas filter clipping is preserved")
		_expect_equal(
			clipped_atlas_frame.sampling_clip_region,
			Rect2(8, 0, 8, 8),
			"atlas filter clipping keeps its backing texture boundary"
		)
	atlas_region.filter_clip = false

	var nested_atlas := AtlasTexture.new()
	nested_atlas.atlas = atlas_region
	nested_atlas.region = Rect2(4, 0, 4, 8)
	sprite.texture = nested_atlas
	var nested_frame := KonadoCharacterTransitionFrame.from_sprite(sprite, target)
	_expect(nested_frame != null and nested_frame.is_valid(), "nested atlases expose safe frames")
	if nested_frame:
		_expect_equal(
			nested_frame.texture, atlas_texture, "nested atlas frames use the final backing texture"
		)
		_expect_equal(
			nested_frame.source_region,
			Rect2(12, 0, 4, 8),
			"nested atlas frames accumulate every region offset"
		)

	# 内层 AtlasTexture 的裁切边界可能大于外层选区，不能误收紧到最终帧边界。
	atlas_region.filter_clip = true
	var nested_clipped_frame := KonadoCharacterTransitionFrame.from_sprite(sprite, target)
	_expect(
		nested_clipped_frame != null and nested_clipped_frame.is_valid(),
		"nested clipped atlases expose safe frames"
	)
	if nested_clipped_frame:
		_expect_equal(
			nested_clipped_frame.sampling_clip_region,
			Rect2(8, 0, 8, 8),
			"nested atlases preserve the nearest active filtering boundary"
		)
	atlas_region.filter_clip = false

	# Godot 支持 region 与精灵表分帧同时启用，当前帧必须从 region 内部选取。
	sprite.texture = atlas_texture
	sprite.region_enabled = true
	sprite.region_rect = Rect2(4, 0, 12, 8)
	sprite.hframes = 3
	sprite.vframes = 1
	sprite.frame = 2
	var region_frame := KonadoCharacterTransitionFrame.from_sprite(sprite, target)
	_expect(
		region_frame != null and region_frame.is_valid(), "region sprite sheets expose safe frames"
	)
	if region_frame:
		_expect_equal(
			region_frame.source_region,
			Rect2(12, 0, 4, 8),
			"region sprite sheets select the current frame inside the configured region"
		)
	sprite.region_enabled = false
	sprite.hframes = 1
	sprite.frame = 0

	var viewport := target.get_viewport()
	viewport.snap_2d_transforms_to_pixel = true
	sprite.texture = atlas_texture
	sprite.centered = false
	sprite.offset = Vector2(0.2, 1.6)
	var snapped_frame := KonadoCharacterTransitionFrame.from_sprite(sprite, target)
	_expect_equal(
		snapped_frame,
		null,
		"pixel-snapped sprites use safe fading instead of inaccurate transform snapshots"
	)
	viewport.snap_2d_transforms_to_pixel = false
	sprite.centered = true
	sprite.offset = Vector2.ZERO

	var margined_atlas := AtlasTexture.new()
	margined_atlas.atlas = atlas_texture
	margined_atlas.region = Rect2(8, 0, 8, 8)
	margined_atlas.margin = Rect2(1, 0, 0, 0)
	sprite.texture = margined_atlas
	_expect_equal(
		KonadoCharacterTransitionFrame.from_sprite(sprite, target),
		null,
		"trimmed atlases use fallback instead of producing inaccurate blends"
	)

	var foreign_sprite := Sprite2D.new()
	foreign_sprite.texture = atlas_texture
	get_root().add_child(foreign_sprite)
	_expect_equal(
		KonadoCharacterTransitionFrame.from_sprite(foreign_sprite, target),
		null,
		"visuals outside the stable mount cannot become transition frames"
	)

	var custom_material := ShaderMaterial.new()
	custom_material.shader = Shader.new()
	custom_material.shader.code = "shader_type canvas_item;"
	sprite.material = custom_material
	_expect_equal(
		KonadoCharacterTransitionFrame.from_sprite(sprite, target),
		null,
		"material-driven visuals use fallback instead of losing their effects"
	)
	sprite.material = null

	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_expect_equal(
		KonadoCharacterTransitionFrame.from_sprite(sprite, target),
		null,
		"repeating textures use fallback instead of changing edge sampling semantics"
	)
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_PARENT_NODE

	var animated_texture := AnimatedTexture.new()
	animated_texture.frames = 1
	animated_texture.set_frame_texture(0, atlas_texture)
	sprite.texture = animated_texture
	_expect_equal(
		KonadoCharacterTransitionFrame.from_sprite(sprite, target),
		null,
		"dynamic textures use fallback instead of pretending to be snapshots"
	)

	var mesh_texture := MeshTexture.new()
	mesh_texture.image_size = Vector2(8.0, 8.0)
	sprite.texture = mesh_texture
	_expect_equal(
		KonadoCharacterTransitionFrame.from_sprite(sprite, target),
		null,
		"textures without a directly sampleable RID use the safe fallback"
	)

	sprite.texture = atlas_texture
	sprite.z_index = 1
	_expect_equal(
		KonadoCharacterTransitionFrame.from_sprite(sprite, target),
		null,
		"source-specific Z ordering uses fallback instead of changing external draw order"
	)
	sprite.z_index = 0
	sprite.z_as_relative = false
	_expect_equal(
		KonadoCharacterTransitionFrame.from_sprite(sprite, target),
		null,
		"absolute source Z ordering uses fallback instead of escaping the character mount"
	)
	sprite.z_as_relative = true
	sprite.show_behind_parent = true
	_expect_equal(
		KonadoCharacterTransitionFrame.from_sprite(sprite, target),
		null,
		"source behind-parent ordering uses fallback instead of changing composition"
	)
	sprite.show_behind_parent = false
	target.y_sort_enabled = true
	_expect_equal(
		KonadoCharacterTransitionFrame.from_sprite(sprite, target),
		null,
		"Y-sorted character mounts use fallback instead of flattening runtime draw order"
	)
	target.y_sort_enabled = false

	var ordered_parent := Node2D.new()
	ordered_parent.z_index = 1
	target.add_child(ordered_parent)
	var ordered_sprite := Sprite2D.new()
	ordered_sprite.texture = atlas_texture
	ordered_parent.add_child(ordered_sprite)
	_expect_equal(
		KonadoCharacterTransitionFrame.from_sprite(ordered_sprite, target),
		null,
		"intermediate Z ordering uses fallback instead of flattening nested composition"
	)

	var malformed_frame := KonadoCharacterTransitionFrame.new()
	malformed_frame.texture = atlas_texture
	malformed_frame.source_region = Rect2(0, 0, 64, 64)
	malformed_frame.source_visual = sprite
	_expect(not malformed_frame.is_valid(), "frames reject out-of-bounds sampling regions")

	var overflowing_frame := KonadoCharacterTransitionFrame.new()
	overflowing_frame.texture = atlas_texture
	overflowing_frame.source_region = Rect2(0, 0, 8, 8)
	overflowing_frame.frame_to_target = Transform2D(
		Vector2(1.0e200, 0.0), Vector2(0.0, 1.0e200), Vector2.ZERO
	)
	overflowing_frame.source_visual = sprite
	_expect(
		not overflowing_frame.is_valid(),
		"frames reject transforms whose derived geometry overflows"
	)

	var clipped_parent := Control.new()
	clipped_parent.clip_contents = true
	target.add_child(clipped_parent)
	var clipped_sprite := Sprite2D.new()
	clipped_sprite.texture = atlas_texture
	clipped_parent.add_child(clipped_sprite)
	_expect_equal(
		KonadoCharacterTransitionFrame.from_sprite(clipped_sprite, target),
		null,
		"intermediate clipping uses fallback instead of producing incomplete frames"
	)

	var masked_parent := Node2D.new()
	masked_parent.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	target.add_child(masked_parent)
	var masked_sprite := Sprite2D.new()
	masked_sprite.texture = atlas_texture
	masked_parent.add_child(masked_sprite)
	_expect_equal(
		KonadoCharacterTransitionFrame.from_sprite(masked_sprite, target),
		null,
		"CanvasItem child masks use fallback instead of losing their mask"
	)

	var canvas_group := CanvasGroup.new()
	target.add_child(canvas_group)
	var grouped_sprite := Sprite2D.new()
	grouped_sprite.texture = atlas_texture
	canvas_group.add_child(grouped_sprite)
	_expect_equal(
		KonadoCharacterTransitionFrame.from_sprite(grouped_sprite, target),
		null,
		"CanvasGroup composition uses fallback instead of changing render semantics"
	)

	frame = null
	atlas_frame = null
	clipped_atlas_frame = null
	nested_frame = null
	nested_clipped_frame = null
	region_frame = null
	snapped_frame = null
	custom_material = null
	foreign_sprite.queue_free()
	target.queue_free()
	await process_frame


func _test_frame_type_boundary() -> void:
	var host := Control.new()
	var controller := KonadoActorStateTransitionController.new(
		host, Callable(), func(_status_name: String) -> bool: return true
	)
	var official_frame := KonadoCharacterTransitionFrame.new()
	var extended_frame := ExtendedTransitionFrame.new()
	_expect(
		controller._is_official_transition_frame(official_frame),
		"the controller accepts direct instances of the official frame contract"
	)
	_expect(
		not controller._is_official_transition_frame(extended_frame),
		"frame subclasses cannot override the trusted validation boundary"
	)
	controller = null
	official_frame = null
	extended_frame = null
	host.free()


func _make_texture(color: Color) -> Texture2D:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("FAIL: " + message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		return
	_failures += 1
	printerr("FAIL: %s\n  expected: %s\n  actual:   %s" % [message, expected, actual])
