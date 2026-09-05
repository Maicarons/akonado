extends RefCounted
class_name KonadoInstructionAwaiter

## Owns one manager's instruction-completion signal connections.
##
## Keeping these callbacks outside the dialogue manager makes cancellation a
## single operation and prevents individual instruction handlers from leaking
## one-shot connections after a stop, failure or shot transition.

var _host_ref: WeakRef
var _pending_connections: Array[Dictionary] = []


func _init(host: KonadoDialogueManager) -> void:
	_host_ref = weakref(host)


func await_signal(completion: Signal, token: Dictionary, two_arguments := false) -> void:
	var host := _host()
	if host == null or completion.is_null() or not host._token_is_active(token):
		return
	var callback := (
		_on_two_argument_signal_completed.bind(token)
		if two_arguments
		else _on_signal_completed.bind(token)
	)
	_track(completion, callback, token)
	host._set_waiting_token(token)


func await_stage_operation(
	completion: Signal,
	request_id: int,
	token: Dictionary,
	fallback: KonadoExecutionFailure,
) -> void:
	var host := _host()
	if host == null or completion.is_null() or request_id <= 0 or not host._token_is_active(token):
		return
	var callback := _on_stage_operation_completed.bind(request_id, token, fallback)
	_track(completion, callback, token, false)
	host._set_waiting_token(token)


func begin_stage_operation(
	stage: KonadoStageController,
	token: Dictionary,
	fallback: KonadoExecutionFailure,
) -> int:
	var host := _host()
	if host == null or stage == null or not host._token_is_active(token):
		return 0
	var request_id := stage.begin_operation_request()
	await_stage_operation(stage.operation_finished, request_id, token, fallback)
	return request_id


func cancel() -> void:
	for connection in _pending_connections:
		var completion: Signal = connection["signal"]
		var callback: Callable = connection["callback"]
		if not completion.is_null() and completion.is_connected(callback):
			completion.disconnect(callback)
	_pending_connections.clear()


func pending_count() -> int:
	return _pending_connections.size()


func _track(completion: Signal, callback: Callable, token: Dictionary, one_shot := true) -> void:
	completion.connect(callback, CONNECT_ONE_SHOT if one_shot else 0)
	_pending_connections.append({"signal": completion, "callback": callback, "token": token})


func _on_signal_completed(token: Dictionary) -> void:
	_forget(token)
	var host := _host()
	if host != null:
		host._complete_instruction(token)


func _on_two_argument_signal_completed(
	_first: Variant, _second: Variant, token: Dictionary
) -> void:
	_on_signal_completed(token)


func _on_stage_operation_completed(
	completed_request_id: int,
	succeeded: bool,
	failure: Dictionary,
	expected_request_id: int,
	token: Dictionary,
	fallback: KonadoExecutionFailure,
) -> void:
	if completed_request_id != expected_request_id:
		return
	_forget(token, true)
	var host := _host()
	if host == null or not host._token_is_active(token):
		return
	if succeeded:
		host._complete_instruction(token)
		return
	host._fail_current(_failure_from_result(failure, fallback), token)


func _forget(token: Dictionary, disconnect := false) -> void:
	for index in range(_pending_connections.size() - 1, -1, -1):
		if _pending_connections[index]["token"] == token:
			if disconnect:
				var completion: Signal = _pending_connections[index]["signal"]
				var callback: Callable = _pending_connections[index]["callback"]
				if not completion.is_null() and completion.is_connected(callback):
					completion.disconnect(callback)
			_pending_connections.remove_at(index)


func _failure_from_result(
	failure: Dictionary, fallback: KonadoExecutionFailure
) -> KonadoExecutionFailure:
	if failure.is_empty():
		return fallback
	return (
		KonadoExecutionFailure
		. new(
			StringName(failure.get("code", fallback.code)),
			String(failure.get("message", fallback.message)),
			failure,
		)
	)


func _host() -> KonadoDialogueManager:
	return _host_ref.get_ref() as KonadoDialogueManager
