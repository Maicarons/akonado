extends SceneTree

var _failures := 0


class ValidatedCharacterScene:
	extends KonadoCharacterSceneBase

	var available_statuses := [&"idle", &"happy"]
	var applied_statuses: Array[String] = []
	var validation_count := 0
	var before_validation := Callable()
	var before_apply := Callable()
	var before_reset := Callable()

	func _has_status(resolved_status_name: String, _original_status_name: String) -> bool:
		validation_count += 1
		var hook := before_validation
		before_validation = Callable()
		if hook.is_valid():
			hook.call()
		return StringName(resolved_status_name) in available_statuses

	func _apply_status(resolved_status_name: String, _original_status_name: String) -> void:
		applied_statuses.append(resolved_status_name)
		var hook := before_apply
		before_apply = Callable()
		if hook.is_valid():
			hook.call()

	func _reset_character_scene() -> void:
		var hook := before_reset
		before_reset = Callable()
		if hook.is_valid():
			hook.call()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_character_status_validation()
	await _test_transition_lifecycle()
	await _test_cancel_callback_reentry()
	await _test_frame_blend_lifecycle()
	if _failures == 0:
		print("PASS: actor state transition tests")
	quit(_failures)


func _test_character_status_validation() -> void:
	var staged_character_scene := ValidatedCharacterScene.new()
	_expect(
		staged_character_scene.can_apply_status("happy"),
		"request admission can validate a state without mutating the character scene"
	)
	_expect(
		staged_character_scene.apply_status("happy"),
		"the same state is revalidated when it is committed"
	)
	_expect_equal(
		staged_character_scene.validation_count,
		2,
		"state availability is checked at request admission and final commit"
	)
	staged_character_scene.free()

	var character_scene := ValidatedCharacterScene.new()
	_expect(character_scene.apply_status("idle"), "available states apply successfully")
	_expect_equal(character_scene.current_status_name, "idle", "successful states become current")
	_expect(not character_scene.apply_status("missing"), "missing states report failure")
	_expect_equal(
		character_scene.current_status_name,
		"idle",
		"failed states preserve the last successfully applied state"
	)
	_expect_equal(
		character_scene.applied_statuses,
		["idle"],
		"failed states never reach the mutating apply hook"
	)

	var invalid_validation_results: Array[bool] = []
	character_scene.before_validation = func() -> void:
		invalid_validation_results.append(character_scene.apply_status("missing"))
	invalid_validation_results.append(character_scene.apply_status("happy"))
	_expect_equal(
		invalid_validation_results,
		[false, true],
		"invalid validation reentry does not steal character scene ownership"
	)
	_expect_equal(character_scene.current_status_name, "happy", "the outer valid state commits")

	var apply_reentry_results: Array[bool] = []
	character_scene.before_apply = func() -> void:
		apply_reentry_results.append(character_scene.apply_status("idle"))
	apply_reentry_results.append(character_scene.apply_status("happy"))
	_expect_equal(
		apply_reentry_results,
		[true, false],
		"new states applied from hooks supersede stale outer states"
	)
	_expect_equal(
		character_scene.current_status_name, "idle", "the newest valid state remains active"
	)

	var reset_signal_count := [0]
	character_scene.character_scene_reset.connect(func() -> void: reset_signal_count[0] += 1)
	character_scene.before_reset = func() -> void:
		_expect(
			character_scene.apply_status("happy"),
			"a state applied from the reset hook takes ownership"
		)
	character_scene.reset_character_scene()
	_expect_equal(
		character_scene.current_status_name,
		"happy",
		"reset hook reentry preserves the newest valid state"
	)
	_expect_equal(
		reset_signal_count[0],
		0,
		"superseded resets do not emit a stale character_scene_reset signal"
	)
	character_scene.free()


func _test_transition_lifecycle() -> void:
	var host := Control.new()
	var visual := ColorRect.new()
	visual.modulate = Color(0.8, 0.7, 0.6, 0.65)
	host.add_child(visual)
	get_root().add_child(host)
	await process_frame

	var applied_statuses: Array[String] = []
	var events: Array[String] = []
	var completions: Array[bool] = []
	var controller := KonadoActorStateTransitionController.new(
		host,
		func() -> CanvasItem: return visual,
		func(status_name: String) -> bool:
			applied_statuses.append(status_name)
			return not status_name.is_empty()
	)
	controller.transition_started.connect(
		func(status_name: String) -> void: events.append("started:" + status_name)
	)
	controller.status_applied.connect(
		func(status_name: String) -> void: events.append("applied:" + status_name)
	)
	controller.transition_finished.connect(
		func(status_name: String, succeeded: bool) -> void:
			events.append("finished:%s:%s" % [status_name, succeeded])
	)

	controller.request("idle", 0.0, func(succeeded: bool) -> void: completions.append(succeeded))
	_expect_equal(
		events,
		["started:idle", "applied:idle", "finished:idle:true"],
		"immediate changes preserve signal order"
	)
	_expect_equal(completions, [true], "immediate changes complete exactly once")
	_expect(not controller.is_transitioning(), "immediate changes leave no active request")
	_expect_approx(visual.modulate.a, 0.65, "immediate changes preserve alpha")

	events.clear()
	completions.clear()
	controller.request("pending", 1.0, func(succeeded: bool) -> void: completions.append(succeeded))
	_expect(controller.is_transitioning(), "animated changes expose active state")
	await process_frame
	_expect_equal(
		applied_statuses, ["idle"], "fallback transitions keep the previous state during fade-out"
	)
	controller.cancel()
	_expect_equal(completions, [false], "cancelled transitions complete exactly once")
	_expect_equal(applied_statuses, ["idle"], "cancelled fade-outs never apply pending state")

	var accepts_status := [true]
	var validation_controller := KonadoActorStateTransitionController.new(
		host,
		func() -> CanvasItem: return visual,
		func(status_name: String) -> bool:
			applied_statuses.append(status_name)
			return true,
		Callable(),
		func(_status_name: String) -> bool: return accepts_status[0]
	)
	var validation_completions: Array[bool] = []
	validation_controller.request(
		"valid_pending",
		1.0,
		func(succeeded: bool) -> void: validation_completions.append(succeeded)
	)
	accepts_status[0] = false
	validation_controller.request(
		"invalid", 0.0, func(succeeded: bool) -> void: validation_completions.append(succeeded)
	)
	_expect(
		validation_controller.is_transitioning(),
		"invalid requests do not cancel an active valid transition"
	)
	_expect_equal(
		validation_completions, [false], "invalid replacement requests fail independently"
	)
	validation_controller.cancel()
	_expect_equal(
		validation_completions,
		[false, false],
		"the original transition remains independently cancellable"
	)

	var invalid_reentry_results: Array[String] = []
	var invalid_reentry_controller: KonadoActorStateTransitionController
	var invalid_reentry_refs: Array[WeakRef] = [null]
	invalid_reentry_controller = KonadoActorStateTransitionController.new(
		host,
		func() -> CanvasItem: return visual,
		func(_status_name: String) -> bool: return true,
		Callable(),
		func(status_name: String) -> bool:
			if status_name == "outer":
				var active_controller := (
					invalid_reentry_refs[0].get_ref() as KonadoActorStateTransitionController
				)
				active_controller.request(
					"invalid_inner",
					0.0,
					func(succeeded: bool) -> void:
						invalid_reentry_results.append("inner:%s" % succeeded)
				)
			return status_name != "invalid_inner"
	)
	invalid_reentry_refs[0] = weakref(invalid_reentry_controller)
	invalid_reentry_controller.request(
		"outer",
		0.0,
		func(succeeded: bool) -> void: invalid_reentry_results.append("outer:%s" % succeeded)
	)
	_expect_equal(
		invalid_reentry_results,
		["inner:false", "outer:true"],
		"invalid validator reentry does not steal ownership from a valid request"
	)

	var valid_reentry_results: Array[String] = []
	var valid_reentry_controller: KonadoActorStateTransitionController
	var valid_reentry_refs: Array[WeakRef] = [null]
	valid_reentry_controller = KonadoActorStateTransitionController.new(
		host,
		func() -> CanvasItem: return visual,
		func(_status_name: String) -> bool: return true,
		Callable(),
		func(status_name: String) -> bool:
			if status_name == "outer":
				var active_controller := (
					valid_reentry_refs[0].get_ref() as KonadoActorStateTransitionController
				)
				active_controller.request(
					"replacement",
					0.0,
					func(succeeded: bool) -> void:
						valid_reentry_results.append("replacement:%s" % succeeded)
				)
			return true
	)
	valid_reentry_refs[0] = weakref(valid_reentry_controller)
	valid_reentry_controller.request(
		"outer",
		0.0,
		func(succeeded: bool) -> void: valid_reentry_results.append("outer:%s" % succeeded)
	)
	_expect_equal(
		valid_reentry_results,
		["replacement:true", "outer:false"],
		"valid validator reentry supersedes the older request"
	)

	events.clear()
	completions.clear()
	controller.request("happy", 0.1, func(succeeded: bool) -> void: completions.append(succeeded))
	await create_timer(0.23).timeout
	_expect_equal(
		events,
		["started:happy", "applied:happy", "finished:happy:true"],
		"animated changes preserve signal order"
	)
	_expect_equal(completions, [true], "animated changes complete exactly once")
	_expect(not controller.is_transitioning(), "animated changes clear active state")
	_expect_approx(visual.modulate.a, 0.65, "animated changes restore alpha")
	_expect_equal(host.get_child_count(), 1, "transitions do not duplicate visual nodes")

	events.clear()
	completions.clear()
	controller.request("sad", 1.0, func(succeeded: bool) -> void: completions.append(succeeded))
	controller.request("angry", 0.0, func(succeeded: bool) -> void: completions.append(succeeded))
	_expect_equal(
		completions, [false, true], "superseded and replacement requests each complete once"
	)
	_expect(events.has("finished:sad:false"), "superseded changes report failed completion")
	_expect(events.has("finished:angry:true"), "replacement changes report success")
	_expect_equal(applied_statuses.back(), "angry", "only the replacement state is applied")
	_expect_approx(visual.modulate.a, 0.65, "cancelling restores alpha")
	_expect_equal(host.get_child_count(), 1, "cancelling leaves no temporary nodes")

	completions.clear()
	controller.request("", 0.0, func(succeeded: bool) -> void: completions.append(succeeded))
	_expect_equal(completions, [false], "invalid status changes fail without hanging")

	var no_visual_completions: Array[bool] = []
	var no_visual_controller := KonadoActorStateTransitionController.new(
		host, func() -> CanvasItem: return null, func(_status_name: String) -> bool: return true
	)
	no_visual_controller.request(
		"voice_only", 1.0, func(succeeded: bool) -> void: no_visual_completions.append(succeeded)
	)
	_expect_equal(no_visual_completions, [true], "non-visual scenes use immediate status changes")

	var signal_reentrant_completions: Array[String] = []
	var signal_reentrant_controller: KonadoActorStateTransitionController
	signal_reentrant_controller = KonadoActorStateTransitionController.new(
		host, func() -> CanvasItem: return visual, func(_status_name: String) -> bool: return true
	)
	var signal_controller_ref: WeakRef = weakref(signal_reentrant_controller)
	signal_reentrant_controller.transition_started.connect(
		func(status_name: String) -> void:
			if status_name != "outer":
				return
			var active_controller := (
				signal_controller_ref.get_ref() as KonadoActorStateTransitionController
			)
			active_controller.request(
				"replacement",
				0.0,
				func(succeeded: bool) -> void:
					signal_reentrant_completions.append("replacement:%s" % succeeded)
			)
	)
	signal_reentrant_controller.request(
		"outer",
		1.0,
		func(succeeded: bool) -> void: signal_reentrant_completions.append("outer:%s" % succeeded)
	)
	_expect_equal(
		signal_reentrant_completions,
		["outer:false", "replacement:true"],
		"requests started from transition signals safely supersede the old request"
	)
	_expect(
		not signal_reentrant_controller.is_transitioning(),
		"signal-driven replacement leaves no stale transition"
	)

	var apply_reentrant_completions: Array[String] = []
	var apply_reentrant_controller: KonadoActorStateTransitionController
	var apply_controller_refs: Array[WeakRef] = [null]
	apply_reentrant_controller = KonadoActorStateTransitionController.new(
		host,
		func() -> CanvasItem: return visual,
		func(status_name: String) -> bool:
			if status_name == "outer_apply":
				var active_controller := (
					apply_controller_refs[0].get_ref() as KonadoActorStateTransitionController
				)
				active_controller.request(
					"replacement_apply",
					0.0,
					func(succeeded: bool) -> void:
						apply_reentrant_completions.append("replacement:%s" % succeeded)
				)
			return true
	)
	apply_controller_refs[0] = weakref(apply_reentrant_controller)
	apply_reentrant_controller.request(
		"outer_apply",
		0.0,
		func(succeeded: bool) -> void: apply_reentrant_completions.append("outer:%s" % succeeded)
	)
	_expect_equal(
		apply_reentrant_completions,
		["outer:false", "replacement:true"],
		"requests started while applying safely supersede the old request"
	)
	_expect(
		not apply_reentrant_controller.is_transitioning(),
		"apply-driven replacement leaves no stale transition"
	)

	controller = null
	no_visual_controller = null
	validation_controller = null
	invalid_reentry_controller = null
	valid_reentry_controller = null
	signal_reentrant_controller = null
	apply_reentrant_controller = null
	host.queue_free()
	await process_frame


func _test_cancel_callback_reentry() -> void:
	var host := Control.new()
	var visual := ColorRect.new()
	host.add_child(visual)
	get_root().add_child(host)
	await process_frame

	var signal_results: Array[String] = []
	var signal_controller := KonadoActorStateTransitionController.new(
		host, func() -> CanvasItem: return visual, func(_status_name: String) -> bool: return true
	)
	var signal_controller_ref: WeakRef = weakref(signal_controller)
	signal_controller.transition_cancelled.connect(
		func(status_name: String) -> void:
			if status_name != "old":
				return
			var active_controller := (
				signal_controller_ref.get_ref() as KonadoActorStateTransitionController
			)
			active_controller.request(
				"callback_replacement",
				0.0,
				func(succeeded: bool) -> void: signal_results.append("replacement:%s" % succeeded)
			)
	)
	signal_controller.request(
		"old", 1.0, func(succeeded: bool) -> void: signal_results.append("old:%s" % succeeded)
	)
	signal_controller.request(
		"superseding",
		0.0,
		func(succeeded: bool) -> void: signal_results.append("superseding:%s" % succeeded)
	)
	_expect_equal(
		signal_results,
		["replacement:true", "old:false", "superseding:false"],
		"a cancellation signal request owns the controller and suppresses the older call frame"
	)
	_expect(not signal_controller.is_transitioning(), "signal reentry leaves no orphan Tween")

	var completion_results: Array[String] = []
	var completion_controller := KonadoActorStateTransitionController.new(
		host, func() -> CanvasItem: return visual, func(_status_name: String) -> bool: return true
	)
	var completion_controller_ref: WeakRef = weakref(completion_controller)
	completion_controller.request(
		"old",
		1.0,
		func(succeeded: bool) -> void:
			completion_results.append("old:%s" % succeeded)
			var active_controller := (
				completion_controller_ref.get_ref() as KonadoActorStateTransitionController
			)
			active_controller.request(
				"completion_replacement",
				0.0,
				func(replacement_succeeded: bool) -> void:
					completion_results.append("replacement:%s" % replacement_succeeded)
			)
	)
	completion_controller.request(
		"superseding",
		0.0,
		func(succeeded: bool) -> void: completion_results.append("superseding:%s" % succeeded)
	)
	_expect_equal(
		completion_results,
		["old:false", "replacement:true", "superseding:false"],
		"a cancellation completion request owns the controller and suppresses the older call frame"
	)
	_expect(
		not completion_controller.is_transitioning(), "completion reentry leaves no orphan Tween"
	)

	signal_controller = null
	completion_controller = null
	host.queue_free()
	await process_frame


func _test_frame_blend_lifecycle() -> void:
	var host := Control.new()
	host.size = Vector2(320.0, 180.0)
	var visual := Control.new()
	visual.size = host.size
	host.add_child(visual)
	var media_node := Node.new()
	media_node.name = "LiveMedia"
	visual.add_child(media_node)
	var source_visual := Sprite2D.new()
	source_visual.texture = _make_texture(Color("684c9e"))
	source_visual.position = Vector2(80.0, 90.0)
	visual.add_child(source_visual)
	visual.offset_transform_position = Vector2(6.0, -4.0)
	visual.offset_transform_position_ratio = Vector2(0.05, -0.02)
	visual.offset_transform_scale = Vector2(1.1, 0.9)
	visual.offset_transform_rotation = 0.08
	visual.offset_transform_pivot = Vector2(12.0, 9.0)
	visual.offset_transform_pivot_ratio = Vector2(0.1, 0.2)
	visual.offset_transform_visual_only = false
	visual.offset_transform_enabled = true
	visual.show_behind_parent = true
	get_root().add_child(host)
	await process_frame

	var old_texture := source_visual.texture
	var new_texture := _make_texture(Color("df76b6"))
	var applied_statuses: Array[String] = []
	var completions: Array[bool] = []
	var apply_should_succeed := [true]
	var validator_accepts := [true]
	var controller := KonadoActorStateTransitionController.new(
		host,
		func() -> CanvasItem: return visual,
		func(status_name: String) -> bool:
			if not apply_should_succeed[0]:
				return false
			applied_statuses.append(status_name)
			source_visual.texture = new_texture
			return true,
		func(status_name: String) -> KonadoCharacterTransitionFrame:
			return KonadoCharacterTransitionFrame.from_sprite(
				source_visual, visual, old_texture if status_name.is_empty() else new_texture
			),
		func(_status_name: String) -> bool: return validator_accepts[0]
	)
	controller.request("happy", 1.0, func(succeeded: bool) -> void: completions.append(succeeded))
	_expect(controller.is_transitioning(), "frame blending exposes active state")
	_expect_equal(applied_statuses, [], "live state is unchanged until the blend completes")
	_expect_equal(visual.get_child_count(), 2, "frame blending never duplicates media nodes")
	_expect_equal(host.get_child_count(), 2, "frame blending creates one sibling render overlay")
	_expect(not visual.visible, "the render overlay replaces the live mount during blending")
	await process_frame
	_expect(controller._blend_material != null, "the shader blend path remains active")
	if controller._blend_material:
		var progress := float(controller._blend_material.get_shader_parameter("progress"))
		_expect(progress >= 0.0 and progress < 1.0, "the shader starts from the old frame")
	_expect_overlay_matches_target(
		controller._blend_overlay, visual, "new overlays preserve the complete visual transform"
	)
	_expect_equal(
		controller._blend_overlay.visibility_layer,
		source_visual.visibility_layer,
		"frame overlays use the source visibility layer"
	)
	_expect_equal(
		controller._blend_overlay.light_mask,
		source_visual.light_mask,
		"frame overlays use the source light mask"
	)
	var blend_rect := controller._blend_overlay.get_child(0) as ColorRect
	_expect_equal(
		blend_rect.visibility_layer,
		source_visual.visibility_layer,
		"the shader draw node uses the source visibility layer"
	)
	_expect_equal(
		blend_rect.light_mask,
		source_visual.light_mask,
		"the shader draw node uses the source light mask"
	)
	visual.position = Vector2(12.0, 7.0)
	visual.modulate = Color(0.8, 0.9, 1.0, 0.7)
	visual.self_modulate = Color(0.9, 0.8, 0.7, 0.6)
	visual.offset_transform_position = Vector2(-3.0, 8.0)
	visual.offset_transform_position_ratio = Vector2(-0.03, 0.04)
	visual.offset_transform_scale = Vector2(0.95, 1.15)
	visual.offset_transform_rotation = -0.12
	visual.offset_transform_pivot = Vector2(20.0, 14.0)
	visual.offset_transform_pivot_ratio = Vector2(0.2, 0.1)
	visual.offset_transform_visual_only = true
	visual.show_behind_parent = false
	controller._sync_blend_overlay()
	_expect_overlay_matches_target(
		controller._blend_overlay, visual, "active overlays follow runtime visual-transform changes"
	)
	var stale_request_id: int = controller._active_request_id
	controller.cancel()
	_expect_equal(completions, [false], "cancelling a frame blend completes once")
	_expect_equal(applied_statuses, [], "cancelling a frame blend does not apply target state")
	_expect(visual.visible and source_visual.visible, "cancelling restores the live visual")
	_expect_equal(source_visual.texture, old_texture, "cancelling preserves the previous state")

	controller.request("happy", 1.0, func(_succeeded: bool) -> void: pass)
	var replacement_overlay_position := controller._blend_overlay.position
	visual.position += Vector2(30.0, 10.0)
	controller._sync_blend_overlay(0.0, stale_request_id)
	_expect_equal(
		controller._blend_overlay.position,
		replacement_overlay_position,
		"stale tween callbacks cannot mutate a replacement overlay"
	)
	controller.cancel()

	completions.clear()
	controller.request("happy", 0.1, func(succeeded: bool) -> void: completions.append(succeeded))
	await create_timer(0.25).timeout
	_expect_equal(applied_statuses, ["happy"], "a completed blend applies its state once")
	_expect_equal(completions, [true], "a completed blend reports success once")
	_expect_equal(source_visual.texture, new_texture, "the live visual takes over at completion")
	_expect(source_visual.visible, "the live visual is restored after blending")
	_expect_equal(host.get_child_count(), 1, "the completed blend releases its overlay")
	_expect_equal(visual.get_child_count(), 2, "the completed blend leaves media untouched")

	apply_should_succeed[0] = false
	validator_accepts[0] = false
	completions.clear()
	controller.request("missing", 0.1, func(succeeded: bool) -> void: completions.append(succeeded))
	await create_timer(0.25).timeout
	_expect_equal(completions, [false], "failed blends report failure once")
	_expect_equal(source_visual.texture, new_texture, "failed blends preserve the live state")
	_expect(source_visual.visible, "failed blends restore the live visual")
	_expect_equal(host.get_child_count(), 1, "failed blends release their overlay")

	validator_accepts[0] = true
	completions.clear()
	controller.request(
		"changed_after_validation",
		0.1,
		func(succeeded: bool) -> void: completions.append(succeeded)
	)
	await create_timer(0.25).timeout
	_expect_equal(completions, [false], "late application failures report failure once")
	_expect_equal(source_visual.texture, new_texture, "late failures preserve the live state")
	_expect(visual.visible, "late failures restore the complete live visual")
	_expect_equal(host.get_child_count(), 1, "late failures release their overlay")

	apply_should_succeed[0] = true
	completions.clear()
	controller.request("happy", 0.1, func(succeeded: bool) -> void: completions.append(succeeded))
	await process_frame
	visual.modulate.a = 0.42
	await create_timer(0.2).timeout
	_expect_equal(completions, [true], "moving-stage blends still complete")
	_expect_approx(visual.modulate.a, 0.42, "blending preserves concurrent alpha changes")

	var visibility_results: Array[String] = []
	var visibility_reentry_armed := [true]
	var controller_ref: WeakRef = weakref(controller)
	var visibility_reentry := func() -> void:
		if not visibility_reentry_armed[0] or visual.visible:
			return
		visibility_reentry_armed[0] = false
		var active_controller := controller_ref.get_ref() as KonadoActorStateTransitionController
		active_controller.request(
			"visibility_replacement",
			0.0,
			func(succeeded: bool) -> void: visibility_results.append("replacement:%s" % succeeded)
		)
	visual.visibility_changed.connect(visibility_reentry)
	controller.request(
		"visibility_outer",
		1.0,
		func(succeeded: bool) -> void: visibility_results.append("outer:%s" % succeeded)
	)
	if visual.visibility_changed.is_connected(visibility_reentry):
		visual.visibility_changed.disconnect(visibility_reentry)
	await process_frame
	_expect_equal(
		visibility_results,
		["outer:false", "replacement:true"],
		"visibility callbacks can replace a blend without corruption"
	)
	_expect(visual.visible, "visibility replacement restores the live visual")
	_expect_equal(host.get_child_count(), 1, "visibility replacement releases old overlay")

	# 自定义 CanvasItem 材质可能改变挂载层的最终合成结果，不能假定帧纹理可以
	# 复刻该效果。此类场景必须走安全淡变路径，而不是短暂丢失用户材质。
	var custom_material := CanvasItemMaterial.new()
	visual.material = custom_material
	controller.request("happy", 1.0, func(_succeeded: bool) -> void: pass)
	_expect(controller.is_transitioning(), "material fallback still starts a transition")
	_expect(controller._blend_overlay == null, "custom materials use the safe fade fallback")
	_expect(controller._active_tween != null, "material fallback owns a fade tween")
	controller.cancel()
	visual.material = null

	var old_frame := KonadoCharacterTransitionFrame.from_sprite(source_visual, visual, old_texture)
	source_visual.visibility_layer = 2
	var different_layer_frame := KonadoCharacterTransitionFrame.from_sprite(
		source_visual, visual, new_texture
	)
	controller._active_visual = visual
	_expect(
		not controller._can_blend_frames(old_frame, different_layer_frame),
		"states with different visibility layers use the safe fade fallback"
	)
	source_visual.visibility_layer = 1

	controller = null
	host.queue_free()
	await process_frame


func _expect_overlay_matches_target(overlay: Control, target: Control, message: String) -> void:
	var properties: Array[StringName] = [
		&"modulate",
		&"self_modulate",
		&"position",
		&"size",
		&"pivot_offset",
		&"rotation",
		&"scale",
		&"offset_transform_position",
		&"offset_transform_position_ratio",
		&"offset_transform_scale",
		&"offset_transform_rotation",
		&"offset_transform_pivot",
		&"offset_transform_pivot_ratio",
		&"offset_transform_visual_only",
		&"offset_transform_enabled",
		&"show_behind_parent",
		&"z_index",
		&"z_as_relative",
	]
	for property_name in properties:
		_expect_equal(
			overlay.get(property_name),
			target.get(property_name),
			"%s: %s" % [message, property_name]
		)


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


func _expect_approx(actual: float, expected: float, message: String) -> void:
	if is_equal_approx(actual, expected):
		return
	_failures += 1
	printerr("FAIL: %s\n  expected: %s\n  actual:   %s" % [message, expected, actual])
