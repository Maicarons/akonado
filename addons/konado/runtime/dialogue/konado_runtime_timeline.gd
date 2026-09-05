extends RefCounted
class_name KonadoRuntimeTimeline

## Owns execution history, checkpoints, and portable runtime snapshots for one manager.

var _host_ref: WeakRef
var _shot_program_cache: Dictionary = {}


func _init(host: KonadoDialogueManager) -> void:
	_host_ref = weakref(host)


func can_rollback(steps := 1) -> bool:
	var host := _host()
	return host != null and host._vm.can_rollback(steps, true)


func rollback(steps := 1) -> bool:
	var host := _host()
	if host == null:
		return false
	var recovering_failure := host._failure_controller()._has_pending()
	if not host._vm.can_rollback(steps, true):
		return false
	if not recovering_failure:
		host._cancel_active_instruction()
	var ok := host._vm.rollback(steps, _restore_runtime_state, recovering_failure)
	if not ok:
		if not recovering_failure or not host._vm._last_failed_restore_preserved_state():
			host._enter_safe_off_state()
		return false
	_resume_restored_timeline(KonadoRuntimeFailureSession.RESOLUTION_ROLLBACK)
	return true


func create_checkpoint(label := "") -> String:
	var host := _host()
	return (
		host._vm.create_checkpoint(label, KonadoRuntimeState.capture(host)) if host != null else ""
	)


func restore_checkpoint(checkpoint_id: String) -> bool:
	var host := _host()
	if host == null:
		return false
	var recovering_failure := host._failure_controller()._has_pending()
	if not host._vm._can_restore_checkpoint(checkpoint_id, true):
		return false
	if not recovering_failure:
		host._cancel_active_instruction()
	var ok := host._vm.restore_checkpoint(checkpoint_id, _restore_runtime_state, recovering_failure)
	if not ok:
		if not recovering_failure or not host._vm._last_failed_restore_preserved_state():
			host._enter_safe_off_state()
		return false
	_resume_restored_timeline(KonadoRuntimeFailureSession.RESOLUTION_RESTORE_CHECKPOINT)
	return true


func execution_history(limit := 0) -> Array[Dictionary]:
	var host := _host()
	return host._vm.history(limit) if host != null else []


func clear_execution_history() -> void:
	var host := _host()
	if host != null:
		host._vm.clear_history()


func capture_execution_snapshot() -> Dictionary:
	var host := _host()
	if (
		host == null
		or host.current_shot == null
		or host.current_shot.source_path.is_empty()
		or host.current_shot.source_path == "null"
		or host._vm.program == null
		or host._vm.pc == KonadoProgram.INVALID_PC
	):
		return {}
	var state := host._vm.snapshot_state()
	if state.is_empty():
		state = KonadoRuntimeState.capture(host)
	return {
		"execution":
		{
			"shot_path": host.current_shot.source_path,
			"program_fingerprint": host._vm.program.fingerprint(),
			"instruction_id": host._vm.program.key_for_pc(host._vm.pc),
		},
		"runtime_state": state,
	}


func restore_execution_snapshot(snapshot: Dictionary) -> bool:
	var host := _host()
	if host == null:
		return false
	var execution: Dictionary = snapshot.get("execution", {})
	var runtime_state: Dictionary = snapshot.get("runtime_state", {})
	var resolved := _resolve_snapshot_target(execution)
	if resolved.is_empty() or not KonadoRuntimeState.validate(runtime_state, host):
		return false
	var shot: KonadoShot = resolved.shot
	var pc := int(resolved.pc)
	var failure_report := host._failure_controller()._detach_pending_report()
	host._cancel_execution()
	host.current_shot = shot.duplicate() as KonadoShot
	if not host._vm.restore_boundary(host.current_shot.program, pc, runtime_state):
		host._enter_safe_off_state()
		_publish_snapshot_resolution(
			failure_report, KonadoRuntimeFailureSession.RESOLUTION_CANCELLED
		)
		return false
	if not KonadoRuntimeState.restore(runtime_state, host):
		host._enter_safe_off_state()
		_publish_snapshot_resolution(
			failure_report, KonadoRuntimeFailureSession.RESOLUTION_CANCELLED
		)
		return false
	host._shot_active = true
	host.dialogue_state = KonadoDialogueManager.DialogState.EXECUTING
	_publish_snapshot_resolution(
		failure_report, KonadoRuntimeFailureSession.RESOLUTION_RESTORE_SNAPSHOT
	)
	if host._shot_active and host.dialogue_state == KonadoDialogueManager.DialogState.EXECUTING:
		host._schedule_pump()
	return true


func remember_shot(shot: KonadoShot) -> void:
	if shot == null or shot.program == null or not shot.program.is_valid():
		return
	_shot_program_cache[shot.program_fingerprint()] = shot.duplicate() as KonadoShot


func _resume_restored_timeline(resolution: StringName) -> void:
	var host := _host()
	if host == null:
		return
	var restored_program := host._vm.program
	var failure_report := host._failure_controller()._detach_pending_report()
	host._playback_generation += 1
	host._active_token.clear()
	host._cancel_pending_callbacks()
	host._shot_active = true
	host.dialogue_state = KonadoDialogueManager.DialogState.EXECUTING
	host._failure_controller()._publish_external_resolution(failure_report, resolution)
	if (
		host._shot_active
		and host.dialogue_state == KonadoDialogueManager.DialogState.EXECUTING
		and host._vm.program == restored_program
	):
		host._schedule_pump()


func _restore_runtime_state(state: Dictionary) -> bool:
	var host := _host()
	if host == null:
		return false
	var execution: Dictionary = state.get("execution", {})
	var shot_path := String(execution.get("shot_path", ""))
	var expected_fingerprint := String(execution.get("program_fingerprint", ""))
	if expected_fingerprint.is_empty():
		return false
	var shot := _shot_program_cache.get(expected_fingerprint) as KonadoShot
	if shot == null and not shot_path.is_empty():
		shot = host._load_localized_shot(load(shot_path) as KonadoShot)
	if shot == null and not shot_path.is_empty() and FileAccess.file_exists(shot_path):
		shot = KonadoScriptCompiler.new().compile_file(shot_path)
	if (
		shot == null
		or not shot.ensure_script_ready()
		or shot.program == null
		or shot.program_fingerprint() != expected_fingerprint
		or host._vm.program == null
		or host._vm.program.fingerprint() != expected_fingerprint
	):
		return false
	var previous_shot := host.current_shot
	host.current_shot = shot.duplicate() as KonadoShot
	if not KonadoRuntimeState.restore(state, host):
		host.current_shot = previous_shot
		return false
	return true


func _resolve_snapshot_target(execution: Dictionary) -> Dictionary:
	var host := _host()
	var shot_path := String(execution.get("shot_path", ""))
	if host == null or shot_path.is_empty() or not ResourceLoader.exists(shot_path):
		return {}
	var shot := host._load_localized_shot(load(shot_path) as KonadoShot)
	if shot == null or not shot.ensure_script_ready() or shot.program == null:
		return {}
	if shot.program.fingerprint() != String(execution.get("program_fingerprint", "")):
		return {}
	var pc := shot.pc_for_key(String(execution.get("instruction_id", "")))
	if pc == KonadoProgram.INVALID_PC:
		return {}
	return {"shot": shot, "pc": pc}


func _publish_snapshot_resolution(report: Dictionary, resolution: StringName) -> void:
	var host := _host()
	if host != null:
		host._failure_controller()._publish_external_resolution(report, resolution)


func _host() -> KonadoDialogueManager:
	return _host_ref.get_ref() as KonadoDialogueManager
