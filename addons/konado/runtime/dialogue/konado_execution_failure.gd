extends RefCounted
class_name KonadoExecutionFailure

## Structured runtime failure passed from an instruction subsystem to the
## dialogue manager. Only the manager writes the final error to Godot's log.

var code := &"runtime.failed"
var message := "指令执行失败"
var subsystem := "runtime"
var operation := ""
var resource_kind := ""
var resource_id := ""
var cause := ""


func _init(
	failure_code: StringName = &"runtime.failed",
	failure_message := "指令执行失败",
	context: Dictionary = {},
) -> void:
	code = failure_code
	message = failure_message if not failure_message.is_empty() else "指令执行失败"
	subsystem = String(context.get("subsystem", "runtime"))
	operation = String(context.get("operation", ""))
	resource_kind = String(context.get("resource_kind", ""))
	resource_id = String(context.get("resource_id", ""))
	cause = String(context.get("cause", ""))


func to_dictionary() -> Dictionary:
	return {
		"code": String(code),
		"message": message,
		"subsystem": subsystem,
		"operation": operation,
		"resource_kind": resource_kind,
		"resource_id": resource_id,
		"cause": cause,
	}


func console_message() -> String:
	var details := PackedStringArray()
	if not operation.is_empty():
		details.append("操作=%s" % operation)
	if not resource_kind.is_empty() and not resource_id.is_empty():
		details.append("%s=%s" % [resource_kind, resource_id])
	elif not resource_id.is_empty():
		details.append("资源=%s" % resource_id)
	if not cause.is_empty() and cause != message:
		details.append("原因=%s" % cause)
	return message if details.is_empty() else "%s；%s" % [message, "，".join(details)]
