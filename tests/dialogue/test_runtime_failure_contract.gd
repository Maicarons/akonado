extends SceneTree

var _failures := 0


class FakeStageController:
	extends KonadoStageController

	func _init() -> void:
		_actor_layer = Control.new()
		add_child(_actor_layer)

	func apply_background_tint_to_actors() -> void:
		pass


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_stage_request_supersession()
	var manager := KonadoDialogueManager.new()
	var stage := FakeStageController.new()
	manager.stage_controller = stage
	var compiler := KonadoScriptCompiler.new()
	compiler.set_console_output_enabled(false)
	var instruction := compiler.compile_line(
		"background missing fade", 7, "res://tests/runtime-failure.ks"
	)
	var executor := KonadoInstructionExecutor.new(manager)
	var result := executor.execute(instruction, {})
	var failure := executor.get_failure()
	_expect_equal(
		result,
		KonadoVirtualMachine.Result.FAILED,
		"resource lookup rejects the instruction without logging from the subsystem",
	)
	_expect(failure != null, "instruction failures retain a structured payload")
	if failure != null:
		_expect_equal(
			String(failure.code),
			"stage.background_not_found",
			"structured failures expose a stable machine-readable code",
		)
		_expect_equal(
			failure.resource_id,
			"missing",
			"structured failures preserve the exact rejected resource",
		)
		_expect_equal(
			failure.operation,
			"background",
			"structured failures identify the failing operation",
		)

	var completion := [true]
	var operation_results: Array[Dictionary] = []
	stage.actor_state_changed.connect(func(ok: bool) -> void: completion[0] = ok)
	stage.operation_finished.connect(
		func(request_id: int, succeeded: bool, detail: Dictionary) -> void:
			operation_results.append(
				{"request_id": request_id, "succeeded": succeeded, "failure": detail}
			)
	)
	var request_id := stage.begin_operation_request()
	stage.change_actor_state("ghost", "idle", 0.0, false, request_id)
	var stage_failure := stage.get_last_failure()
	_expect(not completion[0], "stage completion signals still report a rejected operation")
	_expect_equal(
		stage_failure.get("resource_id"),
		"ghost",
		"asynchronous stage rejection retains the responsible actor id",
	)
	_expect_equal(operation_results.size(), 1, "a request-scoped stage result is emitted once")
	if not operation_results.is_empty():
		_expect_equal(
			operation_results[0].request_id,
			request_id,
			"stage results retain the originating request identity",
		)
		_expect_equal(
			operation_results[0].failure.get("code"),
			"stage.actor_not_present",
			"stage results carry their own exact failure instead of shared mutable state",
		)

	manager._achievement_manager = root.get_node_or_null("KonadoAchievements")
	var achievement_instruction := (
		compiler
		. compile_line(
			'achievement unlock "missing_runtime_achievement"',
			9,
			"res://tests/runtime-failure.ks",
		)
	)
	var achievement_result := executor.execute(achievement_instruction, {})
	var achievement_failure := executor.get_failure()
	_expect_equal(
		achievement_result,
		KonadoVirtualMachine.Result.FAILED,
		"an unknown achievement rejects the atomic instruction",
	)
	_expect_equal(
		String(achievement_failure.code) if achievement_failure != null else "",
		"achievement.not_found",
		"achievement failures preserve their exact cause",
	)
	_expect_equal(
		achievement_failure.resource_id if achievement_failure != null else "",
		"missing_runtime_achievement",
		"achievement failures identify the rejected achievement",
	)
	_expect_equal(
		achievement_failure.operation if achievement_failure != null else "",
		"achievement.unlock",
		"achievement failures identify the exact requested operation",
	)
	stage.free()
	manager.free()
	if _failures == 0:
		print("PASS: runtime failure contract tests")
	quit(_failures)


func _test_stage_request_supersession() -> void:
	var tracker := KonadoStageOperationTracker.new()
	var results: Array[Dictionary] = []
	tracker.operation_finished.connect(
		func(request_id: int, succeeded: bool, failure: Dictionary) -> void:
			results.append({"request_id": request_id, "succeeded": succeeded, "failure": failure})
	)
	var first_request := tracker.begin_request()
	var second_request := tracker.begin_request()
	tracker.register_actor_motion("Kona", "wave", first_request)
	tracker.register_actor_motion("Kona", "jump", second_request)
	_expect_equal(results.size(), 1, "a replacement motion settles the superseded request")
	if not results.is_empty():
		_expect_equal(results[0].request_id, first_request, "the superseded request is identified")
		_expect_equal(
			results[0].failure.get("code"),
			"stage.operation_superseded",
			"motion replacement has a stable failure code",
		)
	_expect_equal(
		tracker.take_actor_motion("Kona", "wave"),
		0,
		"a stale motion completion cannot settle the replacement request",
	)
	_expect_equal(
		tracker.take_actor_motion("Kona", "jump"),
		second_request,
		"the active motion completion retains its request identity",
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("FAIL: %s" % message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		return
	_failures += 1
	printerr("FAIL: %s\n  expected: %s\n  actual:   %s" % [message, expected, actual])
