extends RefCounted
class_name KonadoStageFailureReporter

## Builds the stable failure payload shared by direct stage API calls and the
## request-scoped atomic runtime, while keeping console reporting in one place.


static func record_actor(
	code: StringName,
	message: String,
	operation: String,
	actor_id: String,
	report_errors: bool,
	cause := "",
	as_warning := false,
) -> Dictionary:
	return record(code, message, operation, "actor", actor_id, report_errors, cause, as_warning)


static func record(
	code: StringName,
	message: String,
	operation: String,
	resource_kind: String,
	resource_id: String,
	report_errors: bool,
	cause := "",
	as_warning := false,
) -> Dictionary:
	var failure := {
		"code": String(code),
		"message": message,
		"subsystem": "stage",
		"operation": operation,
		"resource_kind": resource_kind,
		"resource_id": resource_id,
		"cause": cause,
	}
	if report_errors:
		if as_warning:
			push_warning(message)
		else:
			push_error(message)
	return failure
