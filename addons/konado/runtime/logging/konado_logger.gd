extends Logger
class_name KonadoLogger

## Konado Logger，Konado日志记录器

signal error_caught(msg: String)
signal message_caught(msg: String, error: bool)

const LOG_FILE_PATH: String = "user://konado_log.log"

static var _mutex := Mutex.new()

static var _error_type_name := ClassDB.class_get_enum_constants("Logger", "ErrorType")


func _log_error(
	function: String,
	file: String,
	line: int,
	code: String,
	rationale: String,
	editor_notify: bool,
	error_type: int,
	script_backtraces: Array[ScriptBacktrace]
) -> void:
	var is_warning := error_type == Logger.ERROR_TYPE_WARNING
	var sb := PackedStringArray()
	sb.append("Konado runtime warning." if is_warning else "Something's broken in Konado!")
	sb.append("=============================")
	sb.append("  Timestamp: " + Time.get_datetime_string_from_system())
	sb.append("  Function: {0}".format([function]))
	sb.append("  File Path: {0}".format([file]))
	sb.append("  Line Number: {0}".format([line]))
	sb.append("  Error Code: {0}".format([code]))
	sb.append("  Reason: {0}".format([rationale]))
	sb.append("  Editor Notify: {0}".format(["YES" if editor_notify else "NO"]))
	sb.append(
		"  Error Type: {0}".format(
			[_error_type_name[error_type] if error_type < _error_type_name.size() else "UNKNOWN"]
		)
	)
	var konado_trace_found := false
	if not script_backtraces.is_empty():
		sb.append("=============================")
		sb.append("  script backtraces:")
		for trace in script_backtraces:
			var formatted_trace := trace.format()
			if formatted_trace.find("res://addons/konado") != -1:
				konado_trace_found = true
				sb.append("      " + formatted_trace)
	if not konado_trace_found:
		return

	var msg := "\n".join(sb)
	_mutex.lock()
	var filestream := FileAccess.open(LOG_FILE_PATH, FileAccess.READ_WRITE)
	if filestream == null:
		filestream = FileAccess.open(LOG_FILE_PATH, FileAccess.WRITE)
	if filestream != null:
		filestream.seek_end()
		if filestream.get_position() > 0:
			filestream.store_line("")
		filestream.store_line(msg)
		filestream.close()
	_mutex.unlock()
	# Warnings remain available in the persistent log for diagnostics, but must
	# not be presented to players as fatal runtime failures.
	if not is_warning:
		error_caught.emit(msg)


func _log_message(message: String, error: bool) -> void:
	message_caught.emit(message, error)
