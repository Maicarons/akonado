extends RefCounted

## 单次演员状态请求的生命周期协调器。
## 负责同步/异步完成、状态应用通知、演员离树和拒绝请求的统一收口，
## 不负责判断请求所有权或写入业务数据。

var _actor_ref: WeakRef
var _target_state: String
var _transition_duration: float
var _is_current: Callable
var _on_status_applied: Callable
var _on_rejected: Callable
var _on_finished: Callable
var _request_returned := false
var _completion_received := false
var _completion_succeeded := false
var _actor_exiting := false
var _started := false
var _finalized := false


func _init(
	actor: KonadoActor,
	target_state: String,
	transition_duration: float,
	is_current: Callable,
	on_status_applied: Callable,
	on_rejected: Callable,
	on_finished: Callable
) -> void:
	_actor_ref = weakref(actor)
	_target_state = target_state
	_transition_duration = transition_duration
	_is_current = is_current
	_on_status_applied = on_status_applied
	_on_rejected = on_rejected
	_on_finished = on_finished


## 启动请求并返回演员是否接受。同步完成也统一经过 _finish()，
## 因而拒绝、完成回调和离树通知都只会收口一次。
func start() -> bool:
	if _started:
		return false
	_started = true
	var actor := _get_actor()
	if actor == null:
		_request_returned = true
		_call(_on_rejected)
		_finish(false)
		return false

	actor.actor_status_applied.connect(_handle_status_applied)
	actor.tree_exiting.connect(_handle_actor_exiting, ConnectFlags.CONNECT_ONE_SHOT)
	# 使用闭包持有协调器本身。异步扩展可能保存完成回调并在演员离树后调用；
	# 直接传对象方法会在协调器释放后变成指向 null 的 Callable。
	var completion_callback := func(succeeded: bool) -> void: _handle_completion(succeeded)
	var accepted := actor._request_character_status(
		_target_state, _transition_duration, completion_callback
	)
	_request_returned = true
	if not accepted:
		# 拒绝回调必须先恢复此前的请求所有权，再让统一完成逻辑判断当前请求。
		_call(_on_rejected)
	if _completion_received:
		_finish(_completion_succeeded)
	elif not accepted:
		# 内置演员会在拒绝时同步回调；扩展钩子返回 false 时由这里兜底。
		_finish(false)
	return accepted


func _handle_status_applied(applied_status: String) -> void:
	if _finalized or applied_status != _target_state or not _call_bool(_is_current):
		return
	_call(_on_status_applied)


func _handle_completion(succeeded: bool) -> void:
	if _finalized:
		return
	_completion_received = true
	_completion_succeeded = succeeded
	if _request_returned:
		_finish(succeeded)


func _handle_actor_exiting() -> void:
	if _finalized:
		return
	_actor_exiting = true
	_completion_received = true
	_completion_succeeded = false
	if _request_returned:
		_finish(false)


func _finish(succeeded: bool) -> void:
	if _finalized:
		return
	_finalized = true
	var actor := _get_actor()
	if actor != null:
		if actor.actor_status_applied.is_connected(_handle_status_applied):
			actor.actor_status_applied.disconnect(_handle_status_applied)
		if not _actor_exiting and actor.tree_exiting.is_connected(_handle_actor_exiting):
			actor.tree_exiting.disconnect(_handle_actor_exiting)
	_call(_on_finished, [succeeded, _actor_exiting])
	_clear_callbacks()


func _get_actor() -> KonadoActor:
	if _actor_ref == null:
		return null
	return _actor_ref.get_ref() as KonadoActor


func _call(callback: Callable, arguments: Array = []) -> Variant:
	if not callback.is_valid():
		return null
	return callback.callv(arguments)


func _call_bool(callback: Callable) -> bool:
	return callback.is_valid() and callback.call() == true


func _clear_callbacks() -> void:
	_is_current = Callable()
	_on_status_applied = Callable()
	_on_rejected = Callable()
	_on_finished = Callable()
