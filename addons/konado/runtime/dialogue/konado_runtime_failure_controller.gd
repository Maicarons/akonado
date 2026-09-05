extends RefCounted
class_name KonadoRuntimeFailureController

## Owns one manager's suspended failure transaction and recovery overlay.

const RUNTIME_FAILURE_SESSION := preload(
	"res://addons/konado/runtime/dialogue/konado_runtime_failure_session.gd"
)
const RUNTIME_FAILURE_REPORTER := preload(
	"res://addons/konado/runtime/dialogue/konado_runtime_failure_reporter.gd"
)

var _host_ref: WeakRef
var _pending: KonadoRuntimeFailureSession
var _generic_error_visible := false
var _logger: KonadoLogger


func _init(host: KonadoDialogueManager) -> void:
	_host_ref = weakref(host)


func _setup_logger() -> void:
	var host := _host()
	if host == null or not host.enable_overlay_log or _logger != null:
		return
	_logger = KonadoLogger.new()
	OS.add_logger(_logger)
	_logger.error_caught.connect(_show_generic_error, CONNECT_DEFERRED)


func _dispose() -> void:
	if _logger != null:
		if _logger.error_caught.is_connected(_show_generic_error):
			_logger.error_caught.disconnect(_show_generic_error)
		OS.remove_logger(_logger)
		_logger = null
	_clear()


func _handle_failure(
	failure_value: Variant,
	expected_token: Dictionary = {},
	instruction_context: Dictionary = {},
) -> void:
	var host := _host()
	if host == null:
		return
	# The first failure owns the suspended transaction. Late callbacks from the
	# cancelled operation cannot replace its diagnostics or recovery policy.
	if _pending != null and _pending.is_current(host):
		return
	if not expected_token.is_empty() and not host._token_is_active(expected_token):
		return
	var instruction := host._current_instruction()
	if instruction_context.is_empty():
		instruction_context = RUNTIME_FAILURE_REPORTER.capture_context(host, instruction)
	var failure := _as_failure(failure_value)
	var failure_token := expected_token if not expected_token.is_empty() else host._active_token
	var has_transaction := not failure_token.is_empty() and host._token_is_active(failure_token)
	var failure_generation := host._playback_generation
	var report := RUNTIME_FAILURE_REPORTER.build_report(failure, instruction_context)
	if has_transaction:
		_suspend_transaction(host, failure_token, instruction, report)
	else:
		host._cancel_execution()
		failure_generation = host._playback_generation
		_clear()
		host.dialogue_state = KonadoDialogueManager.DialogState.OFF
		report["state_restored"] = false
		report["recovery_actions"] = PackedStringArray()
		report["recoverable"] = false
	RUNTIME_FAILURE_REPORTER.publish(host, failure, report, host.report_runtime_failures_to_console)
	# A report listener may synchronously replace the shot. Never show stale actions.
	if _pending != null and _pending.is_current(host):
		_show_runtime_failure_overlay()
	elif (
		not has_transaction
		and host._playback_generation == failure_generation
		and host.dialogue_state == KonadoDialogueManager.DialogState.OFF
	):
		_show_runtime_failure_overlay(report)


func _refresh_overlay() -> void:
	var host := _host()
	if host == null or host.error_tooltip_panel == null or not host.error_tooltip_panel.visible:
		return
	if _pending != null:
		_show_runtime_failure_overlay()
	elif _generic_error_visible:
		_show_error_actions(PackedStringArray([&"close"]))


func _clear() -> void:
	_pending = null
	_generic_error_visible = false
	var host := _host()
	if host == null:
		return
	if host.error_tooltip_panel != null:
		host.error_tooltip_panel.hide()
	_clear_error_action_buttons(host)


func _show_generic_error(message: String) -> void:
	# Structured VM failures own their recovery overlay. Their push_error entry is
	# still persisted by KonadoLogger and must not replace the actionable report.
	if message.contains("Error Code: Konado [") or _pending != null:
		return
	var host := _host()
	if host == null:
		return
	_generic_error_visible = true
	if host.error_tooltip_label != null:
		host.error_tooltip_label.text = message
	if host.error_tooltip_panel != null:
		host.error_tooltip_panel.show()
	_show_error_actions(PackedStringArray([&"close"]))


func _pending_report() -> Dictionary:
	var host := _host()
	return _pending.report.duplicate(true) if _pending != null and _pending.is_current(host) else {}


func _has_pending() -> bool:
	return _pending != null and _pending.is_current(_host())


func _detach_pending_report() -> Dictionary:
	if _pending == null:
		return {}
	var report := _pending.report.duplicate(true)
	_pending = null
	_clear()
	return report


func _publish_external_resolution(report: Dictionary, resolution: StringName) -> void:
	var host := _host()
	if host != null and not report.is_empty():
		host.runtime_failure_resolved.emit(report.duplicate(true), resolution)


func _resolve(action: StringName) -> bool:
	match action:
		KonadoRuntimeFailureSession.ACTION_RETRY:
			return _retry()
		KonadoRuntimeFailureSession.ACTION_SKIP:
			return _continue_at(action)
		KonadoRuntimeFailureSession.ACTION_CONTINUE_TRUE:
			return _continue_at(action)
		KonadoRuntimeFailureSession.ACTION_CONTINUE_FALSE:
			return _continue_at(action)
		KonadoRuntimeFailureSession.ACTION_STOP:
			return _stop()
	return false


func _suspend_transaction(
	host: KonadoDialogueManager,
	failure_token: Dictionary,
	instruction: KonadoInstruction,
	report: Dictionary,
) -> void:
	var state_before := host._vm.snapshot_state()
	# Invalidate callbacks without cancelling the VM token. The token stays suspended
	# until Retry, a safe bypass, or Stop settles the atomic transaction.
	host._playback_generation += 1
	host._cancel_pending_callbacks()
	var restored := not state_before.is_empty() and KonadoRuntimeState.restore(state_before, host)
	host.dialogue_state = KonadoDialogueManager.DialogState.FAILED
	_pending = (
		RUNTIME_FAILURE_SESSION
		. new(
			report,
			failure_token,
			instruction,
			host._vm.program,
			host._playback_generation,
			restored,
		)
	)
	report["state_restored"] = restored
	report["recovery_actions"] = _pending.available_actions()
	report["recoverable"] = _has_resumable_action(report["recovery_actions"])
	_pending.report = report.duplicate(true)


func _retry() -> bool:
	var host := _host()
	var session := _current_session(KonadoRuntimeFailureSession.ACTION_RETRY)
	if host == null or session == null or not host._vm.fail(session.token):
		return false
	host._active_token.clear()
	# Keep intentional live debugger edits as the new pre-instruction boundary.
	host._vm.synchronize_state(KonadoRuntimeState.capture(host))
	host.dialogue_state = KonadoDialogueManager.DialogState.EXECUTING
	_emit_resolution(host, session, KonadoRuntimeFailureSession.ACTION_RETRY)
	_schedule_recovery_pump(host, session)
	return true


func _continue_at(action: StringName) -> bool:
	var host := _host()
	var session := _current_session(action)
	if host == null or session == null:
		return false
	var target_pc := session.target_for(action)
	if target_pc == KonadoProgram.INVALID_PC:
		return false
	host.dialogue_line_end.emit(session.instruction.stable_key())
	if not session.is_current(host):
		return false
	# Debugger edits and line-end callbacks intentionally become the new boundary;
	# the bypassed instruction itself contributes no state delta.
	host._vm.synchronize_state(KonadoRuntimeState.capture(host))
	if not host._vm._commit_skipped(session.token, target_pc):
		return false
	host._active_token.clear()
	host._waiting_signal_name = ""
	host._dialogue_typing = false
	host.dialogue_state = KonadoDialogueManager.DialogState.EXECUTING
	_emit_resolution(host, session, action)
	_schedule_recovery_pump(host, session)
	return true


func _stop() -> bool:
	var host := _host()
	var session := _current_session(KonadoRuntimeFailureSession.ACTION_STOP)
	if host == null or session == null or not host._vm.fail(session.token):
		return false
	host._active_token.clear()
	host.stop_dialogue()
	return true


func _current_session(action: StringName) -> KonadoRuntimeFailureSession:
	var host := _host()
	if (
		host == null
		or _pending == null
		or not _pending.is_current(host)
		or not _pending.supports(action)
	):
		return null
	return _pending


func _emit_resolution(
	host: KonadoDialogueManager,
	session: KonadoRuntimeFailureSession,
	resolution: StringName,
) -> void:
	var report := session.report.duplicate(true)
	_pending = null
	_clear()
	host.runtime_failure_resolved.emit(report, resolution)


func _schedule_recovery_pump(
	host: KonadoDialogueManager, session: KonadoRuntimeFailureSession
) -> void:
	# A resolution listener may stop playback or replace the shot synchronously.
	if (
		host._shot_active
		and host.dialogue_state == KonadoDialogueManager.DialogState.EXECUTING
		and host._vm.program == session.program
		and host._active_token.is_empty()
	):
		host._schedule_pump()


func _show_runtime_failure_overlay(report: Dictionary = {}) -> void:
	var host := _host()
	if host == null or not host.enable_overlay_log:
		return
	_generic_error_visible = false
	var current_report := _pending.report if _pending != null else report
	if host.error_tooltip_label != null:
		host.error_tooltip_label.text = _format_runtime_failure(host, current_report)
	if host.error_tooltip_panel != null:
		host.error_tooltip_panel.show()
	var actions := (
		_pending.available_actions()
		if _pending != null and _pending.is_current(host)
		else PackedStringArray([&"close"])
	)
	_show_error_actions(actions)


func _format_runtime_failure(host: KonadoDialogueManager, report: Dictionary) -> String:
	var lines := PackedStringArray([host.tr("KONADO_RUNTIME_ERROR_TITLE")])
	lines.append("=============================")
	lines.append(String(report.get("message", host.tr("KONADO_RUNTIME_ERROR_UNKNOWN"))))
	var source_path := String(report.get("source_path", ""))
	var source_line := int(report.get("source_line", -1))
	if not source_path.is_empty():
		lines.append("%s:%d" % [source_path, source_line])
	var details := PackedStringArray()
	for key: String in ["code", "operation", "resource_kind", "resource_id", "cause"]:
		var value := String(report.get(key, ""))
		if not value.is_empty():
			details.append("%s: %s" % [key, value])
	if not details.is_empty():
		lines.append("")
		lines.append("\n".join(details))
	return "\n".join(lines)


func _show_error_actions(actions: PackedStringArray) -> void:
	var host := _host()
	if host == null:
		return
	_clear_error_action_buttons(host)
	if host.error_action_container == null:
		return
	for action: StringName in actions:
		var button := Button.new()
		button.name = _action_node_name(action)
		button.text = _action_label(host, action)
		button.custom_minimum_size.y = 52.0
		button.add_theme_font_size_override("font_size", 28)
		button.set_meta("konado_recovery_action", action)
		button.pressed.connect(_on_action_pressed.bind(action))
		host.error_action_container.add_child(button)


func _action_label(host: KonadoDialogueManager, action: StringName) -> String:
	match action:
		KonadoRuntimeFailureSession.ACTION_RETRY:
			return host.tr("KONADO_ERROR_RETRY")
		KonadoRuntimeFailureSession.ACTION_SKIP:
			return host.tr("KONADO_ERROR_SKIP_INSTRUCTION")
		KonadoRuntimeFailureSession.ACTION_CONTINUE_TRUE:
			return host.tr("KONADO_ERROR_CONTINUE_TRUE")
		KonadoRuntimeFailureSession.ACTION_CONTINUE_FALSE:
			return host.tr("KONADO_ERROR_CONTINUE_FALSE")
		KonadoRuntimeFailureSession.ACTION_STOP:
			return host.tr("KONADO_ERROR_STOP")
	return host.tr("KONADO_ERROR_CLOSE")


func _action_node_name(action: StringName) -> String:
	match action:
		KonadoRuntimeFailureSession.ACTION_RETRY:
			return "Retry"
		KonadoRuntimeFailureSession.ACTION_SKIP:
			return "SkipInstruction"
		KonadoRuntimeFailureSession.ACTION_CONTINUE_TRUE:
			return "ContinueTrue"
		KonadoRuntimeFailureSession.ACTION_CONTINUE_FALSE:
			return "ContinueFalse"
		KonadoRuntimeFailureSession.ACTION_STOP:
			return "StopDialogue"
	return "Close"


func _on_action_pressed(action: StringName) -> void:
	if action == &"close":
		if _pending == null:
			_clear()
		return
	_resolve(action)


func _clear_error_action_buttons(host: KonadoDialogueManager) -> void:
	if host.error_action_container == null:
		return
	for child in host.error_action_container.get_children():
		host.error_action_container.remove_child(child)
		child.queue_free()


func _has_resumable_action(actions: PackedStringArray) -> bool:
	for action: String in actions:
		if StringName(action) != KonadoRuntimeFailureSession.ACTION_STOP:
			return true
	return false


func _as_failure(value: Variant) -> KonadoExecutionFailure:
	if value is KonadoExecutionFailure:
		return value as KonadoExecutionFailure
	return KonadoExecutionFailure.new(&"runtime.failed", String(value))


func _host() -> KonadoDialogueManager:
	return _host_ref.get_ref() as KonadoDialogueManager
