extends "res://tests/dialogue/dialogue_lifecycle_test_base.gd"

const CAMERA_CONTROLLER_SCRIPT := preload(
	"res://addons/konado/runtime/camera/konado_camera_controller.gd"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_line_start_reentry_replaces_program_safely()
	await _test_line_end_reentry_does_not_advance_old_program()
	await _test_jump_line_end_reentry_does_not_fail_replacement()
	await _test_failure_report_listener_can_recover_synchronously()
	await _test_failure_can_be_replaced_synchronously()
	await _test_non_transactional_failure_reentry_hides_stale_overlay()
	await _test_failure_resolution_reentry_replaces_program_safely()
	await _test_wait_signal_replacement_ignores_old_signal()
	await _test_stage_completion_is_request_scoped()
	await _test_voice_wait_contracts()
	await _test_camera_cancellation_preserves_configured_offset()
	if _failures == 0:
		print("PASS: atomic external reentry tests")
	quit(_failures)


func _test_line_start_reentry_replaces_program_safely() -> void:
	var manager := await _create_manager()
	var replaced := [false]
	manager.dialogue_line_start.connect(
		func(_id: String) -> void:
			if replaced[0]:
				return
			replaced[0] = true
			manager.set_shot(_compile_shot('"Kona" "new" [id=new]\nend'))
			manager.start_dialogue()
	)
	manager.set_shot(_compile_shot('"Kona" "old" [id=old]\nend'))
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:new", KonadoDialogueManager.DialogState.WAITING
	)
	_expect_equal(manager.dialogue_box.dialogue_text, "new", "new Program owns output")
	_expect_equal(manager.get_execution_history().size(), 0, "old instruction was never committed")
	await _free_node(manager)


func _test_line_end_reentry_does_not_advance_old_program() -> void:
	var manager := await _create_manager()
	var replaced := [false]
	manager.dialogue_line_end.connect(
		func(_id: String) -> void:
			if replaced[0]:
				return
			replaced[0] = true
			manager.set_shot(_compile_shot('"Kona" "new" [id=new]\nend'))
			manager.start_dialogue()
	)
	manager.set_shot(_compile_shot('"Kona" "old" [id=old]\n"Kona" "stale"\nend'))
	manager.start_dialogue()
	await _wait_for_state(manager, KonadoDialogueManager.DialogState.WAITING)
	await _finish_current_dialogue(manager)
	await _wait_for_instruction_and_state(
		manager, "ks:id:new", KonadoDialogueManager.DialogState.WAITING
	)
	_expect_equal(manager.dialogue_box.dialogue_text, "new", "line-end reentry is isolated")
	await _free_node(manager)


func _test_wait_signal_replacement_ignores_old_signal() -> void:
	var manager := await _create_manager()
	manager.set_shot(_compile_shot("waitsignal old [id=wait]\nend"))
	manager.start_dialogue()
	await _wait_for_state(manager, KonadoDialogueManager.DialogState.WAITING)
	manager.set_shot(_compile_shot('"Kona" "replacement" [id=new]\nend'))
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:new", KonadoDialogueManager.DialogState.WAITING
	)
	manager.emit_wait_signal("old")
	await process_frame
	_expect_equal(
		manager._current_instruction().stable_key(),
		"ks:id:new",
		"an old external signal cannot commit into a replacement Program",
	)
	await _free_node(manager)


func _test_jump_line_end_reentry_does_not_fail_replacement() -> void:
	var manager := await _create_manager()
	var replaced := [false]
	var failures: Array[Dictionary] = []
	manager.runtime_failure_reported.connect(
		func(failure: Dictionary) -> void: failures.append(failure)
	)
	manager.dialogue_line_end.connect(
		func(_id: String) -> void:
			if replaced[0]:
				return
			replaced[0] = true
			manager.set_shot(_compile_shot('"Kona" "replacement" [id=new]\nend'))
			manager.start_dialogue()
	)
	manager.set_shot(_compile_shot("jump res://sample/demo/demo_03_variable.ks [id=old_jump]\nend"))
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:new", KonadoDialogueManager.DialogState.WAITING
	)
	_expect_equal(failures.size(), 0, "a superseded jump is cancellation, not a runtime failure")
	_expect_equal(
		manager.dialogue_box.dialogue_text,
		"replacement",
		"jump line-end callbacks cannot cancel the replacement Program",
	)
	await _free_node(manager)


func _test_failure_resolution_reentry_replaces_program_safely() -> void:
	var manager := await _create_manager()
	manager.report_runtime_failures_to_console = false
	manager.set_shot(
		_compile_shot(
			(
				"if %missing == 1:\n"
				+ '\t"Kona" "stale" [id=stale]\n'
				+ "else:\n"
				+ '\t"Kona" "also stale" [id=also_stale]\n'
				+ "endif\nend"
			)
		)
	)
	manager.start_dialogue()
	await _wait_for_state(manager, KonadoDialogueManager.DialogState.FAILED)
	manager.runtime_failure_resolved.connect(
		func(_failure: Dictionary, _resolution: StringName) -> void:
			manager.set_shot(_compile_shot('"Kona" "replacement" [id=new]\nend'))
			manager.start_dialogue()
	)
	manager.variable_store.set_value("missing", 1)
	_expect(
		manager.resolve_runtime_failure(&"retry"),
		"Retry settles the failed transaction",
	)
	await _wait_for_instruction_and_state(
		manager, "ks:id:new", KonadoDialogueManager.DialogState.WAITING
	)
	_expect_equal(
		manager.dialogue_box.dialogue_text,
		"replacement",
		"a resolution listener can replace playback without the old recovery resuming over it",
	)
	await _free_node(manager)


func _test_failure_report_listener_can_recover_synchronously() -> void:
	var manager := await _create_manager()
	manager.report_runtime_failures_to_console = false
	var recovery_accepted := [false]
	manager.runtime_failure_reported.connect(
		func(_failure: Dictionary) -> void:
			manager.variable_store.set_value("missing", 1)
			recovery_accepted[0] = manager.resolve_runtime_failure(&"retry")
	)
	manager.set_shot(
		_compile_shot(
			(
				"if %missing == 1:\n"
				+ '\t"Kona" "recovered" [id=recovered]\n'
				+ "else:\n"
				+ '\t"Kona" "stale" [id=stale]\n'
				+ "endif\nend"
			)
		)
	)
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:recovered", KonadoDialogueManager.DialogState.WAITING
	)
	_expect(recovery_accepted[0], "a report listener can resolve the suspended transaction")
	_expect(
		not manager.error_tooltip_panel.visible,
		"synchronous recovery never leaves a stale failure overlay",
	)
	await _free_node(manager)


func _test_failure_can_be_replaced_synchronously() -> void:
	var manager := await _create_manager()
	manager.report_runtime_failures_to_console = false
	var resolutions: Array[StringName] = []
	manager.runtime_failure_resolved.connect(
		func(_failure: Dictionary, resolution: StringName) -> void: resolutions.append(resolution)
	)
	manager.set_shot(
		_compile_shot(
			(
				"if %missing == 1:\n"
				+ '\t"Kona" "stale" [id=stale]\n'
				+ "else:\n"
				+ '\t"Kona" "also stale" [id=also_stale]\n'
				+ "endif\nend"
			)
		)
	)
	manager.start_dialogue()
	await _wait_for_state(manager, KonadoDialogueManager.DialogState.FAILED)
	manager.set_shot(_compile_shot('"Kona" "replacement" [id=replacement]\nend'))
	_expect_equal(
		resolutions,
		[&"replace_shot"],
		"replacing a failed shot closes the failure lifecycle exactly once",
	)
	_expect(manager.pending_runtime_failure.is_empty(), "replacement clears stale actions")
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:replacement", KonadoDialogueManager.DialogState.WAITING
	)
	_expect_equal(
		manager.dialogue_box.dialogue_text,
		"replacement",
		"the replacement Program owns subsequent playback",
	)
	await _free_node(manager)


func _test_non_transactional_failure_reentry_hides_stale_overlay() -> void:
	var manager := await _create_manager()
	manager.enable_overlay_log = true
	manager.report_runtime_failures_to_console = false
	manager.set_shot(_compile_shot('"Kona" "stale" [id=stale]\nend'))
	manager.runtime_failure_reported.connect(
		func(_failure: Dictionary) -> void:
			manager.set_shot(_compile_shot('"Kona" "replacement" [id=replacement]\nend'))
			manager.start_dialogue()
	)
	manager._fail_current(
		KonadoExecutionFailure.new(&"runtime.test_failure", "test failure without a transaction")
	)
	await _wait_for_instruction_and_state(
		manager, "ks:id:replacement", KonadoDialogueManager.DialogState.WAITING
	)
	_expect(
		not manager.error_tooltip_panel.visible,
		"a synchronous replacement prevents a non-transactional stale error overlay",
	)
	await _free_node(manager)


func _test_stage_completion_is_request_scoped() -> void:
	var manager := await _create_manager()
	manager.set_shot(_compile_shot("waitsignal hold [id=wait]\nend"))
	manager.start_dialogue()
	await _wait_for_instruction_and_state(
		manager, "ks:id:wait", KonadoDialogueManager.DialogState.WAITING
	)
	var token := manager._active_token.duplicate(true)
	var fallback := KonadoExecutionFailure.new(&"stage.test_failed", "stage test failed")
	var request_id := manager._begin_stage_operation(token, fallback)
	manager.stage_controller.operation_finished.emit(request_id + 1, true, {})
	await process_frame
	_expect(manager._token_is_active(token), "an unrelated stage completion is ignored")
	manager.stage_controller.operation_finished.emit(request_id, true, {})
	await _wait_for_state(manager, KonadoDialogueManager.DialogState.OFF)
	_expect(not manager._token_is_active(token), "the matching stage completion commits once")
	await _free_node(manager)


func _test_voice_wait_contracts() -> void:
	var audio := KonadoAudioController.new()
	var player := AudioStreamPlayer.new()
	audio.add_child(player)
	audio.voice_player = player
	root.add_child(audio)
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 8000.0
	stream.buffer_length = 0.02
	var result: Array[bool] = []
	_record_voice_result.bind(audio, stream, result).call_deferred()
	await _wait_for_condition(
		func() -> bool: return not audio._voice_waiters.is_empty(),
		"waitable voice registers its completion",
	)
	audio.stop_voice()
	await _wait_for_condition(func() -> bool: return not result.is_empty(), "voice waiter settles")
	_expect(not result[0], "waitable voice reports interruption")
	await _free_node(audio)


func _record_voice_result(
	audio: KonadoAudioController, stream: AudioStream, result: Array[bool]
) -> void:
	result.append(await audio.play_voice_and_wait(stream))


func _test_camera_cancellation_preserves_configured_offset() -> void:
	var camera := Camera2D.new()
	camera.offset = Vector2(12.0, 8.0)
	var manager := CAMERA_CONTROLLER_SCRIPT.new()
	manager.add_child(camera)
	manager.active_camera = camera
	root.add_child(manager)
	manager.shake_camera_async(1.0)
	await process_frame
	manager.cancel_pending_operations()
	_expect_equal(camera.offset, Vector2(12.0, 8.0), "camera cancellation restores base offset")
	camera.position = Vector2(30.0, 20.0)
	camera.zoom = Vector2(1.2, 1.2)
	_expect(manager.finish_async_operations(), "stopping an idle async camera is a valid no-op")
	_expect_equal(
		camera.position,
		Vector2(30.0, 20.0),
		"stopping an idle async camera never jumps to an obsolete target",
	)
	_expect_equal(
		camera.zoom,
		Vector2(1.2, 1.2),
		"stopping an idle async camera preserves the configured zoom",
	)
	await _free_node(manager)
