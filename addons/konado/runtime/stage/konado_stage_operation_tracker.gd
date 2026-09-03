extends RefCounted
class_name KonadoStageOperationTracker

## Correlates asynchronous stage completions with the runtime instruction that
## started them. Legacy public stage signals intentionally stay outside this
## object; only the atomic runtime consumes these request-scoped completions.

signal operation_finished(request_id: int, succeeded: bool, failure: Dictionary)

var _request_serial := 0
var _background_request := 0
var _actor_move_requests: Dictionary[String, int] = {}
var _actor_motion_requests: Dictionary[String, Dictionary] = {}


func begin_request() -> int:
	_request_serial += 1
	return _request_serial


func complete(request_id: int, succeeded: bool, failure: Dictionary = {}) -> void:
	if request_id <= 0:
		return
	operation_finished.emit(request_id, succeeded, failure.duplicate(true))


func register_background(request_id: int, current_background_id: String) -> void:
	if _background_request > 0 and _background_request != request_id:
		supersede(_background_request, "background", "background", current_background_id)
	_background_request = request_id


func take_background_request() -> int:
	var request_id := _background_request
	_background_request = 0
	return request_id


func supersede_background(current_background_id: String) -> void:
	if _background_request > 0:
		supersede(_background_request, "background", "background", current_background_id)
	_background_request = 0


func register_actor_move(actor_id: String, request_id: int) -> void:
	var previous_request := int(_actor_move_requests.get(actor_id, 0))
	if previous_request > 0 and previous_request != request_id:
		supersede(previous_request, "actor.move", "actor", actor_id)
	if request_id > 0:
		_actor_move_requests[actor_id] = request_id


func take_actor_move(actor_id: String) -> int:
	var request_id := int(_actor_move_requests.get(actor_id, 0))
	_actor_move_requests.erase(actor_id)
	return request_id


func register_actor_motion(actor_id: String, motion_name: String, request_id: int) -> void:
	var previous: Dictionary = _actor_motion_requests.get(actor_id, {})
	var previous_request := int(previous.get("request_id", 0))
	if previous_request > 0 and previous_request != request_id:
		supersede(previous_request, "actor.motion", "actor", actor_id)
	if request_id > 0:
		_actor_motion_requests[actor_id] = {
			"request_id": request_id,
			"motion_name": motion_name,
		}
	else:
		_actor_motion_requests.erase(actor_id)


func take_actor_motion(actor_id: String, motion_name: String) -> int:
	var request: Dictionary = _actor_motion_requests.get(actor_id, {})
	if String(request.get("motion_name", "")) != motion_name:
		return 0
	var request_id := int(request.get("request_id", 0))
	_actor_motion_requests.erase(actor_id)
	return request_id


func supersede(
	request_id: int, operation: String, resource_kind: String, resource_id: String
) -> void:
	complete(request_id, false, superseded_failure(operation, resource_kind, resource_id))


func superseded_failure(
	operation: String, resource_kind: String, resource_id: String
) -> Dictionary:
	return {
		"code": "stage.operation_superseded",
		"message": "舞台操作已被更新请求取代",
		"subsystem": "stage",
		"operation": operation,
		"resource_kind": resource_kind,
		"resource_id": resource_id,
	}


func cancel() -> void:
	_background_request = 0
	_actor_move_requests.clear()
	_actor_motion_requests.clear()
