extends RefCounted
class_name KonadoScriptRuntimeDebugger

## Runtime bridge between KonadoScript execution and Godot's debugger.
##
## Breakpoints remain owned by Godot's editor and debugger protocol. Konado only
## contributes the script source location and a serializable snapshot of its
## dialogue state immediately before a command is executed.

const CAPTURE_PREFIX := &"konado"

static var _capture_registered := false
static var _paused := false
static var _pause_next := false
static var _step_after_resume := false
static var _current_key := ""
static var _resume_key := ""
static var _paused_manager: WeakRef


static func before_instruction(manager: Object, instruction: KonadoInstruction) -> bool:
	if not EngineDebugger.is_active() or manager == null or instruction == null:
		return false
	_ensure_capture()
	var shot := manager.get("current_shot") as KonadoShot
	if shot == null:
		return false
	var path := shot.source_path
	var line := instruction.source_line()
	if path.is_empty() or path == "null" or line < 1:
		return false
	var state := {
		"path": path,
		"line": line,
		"instruction_id": instruction.stable_key(),
		"program_counter": instruction.pc,
		"shot_id": shot.shot_id,
		"opcode": instruction.opcode(),
		"opcode_name": KonadoOpcode.name_of(instruction.opcode()),
		"persistent_variables": _persistent_variables(manager),
		"temporary_variables": _dictionary_property(manager, "_temp_variables"),
	}
	var location_key := "%s:%d:%s" % [path, line, instruction.stable_key()]
	_current_key = location_key
	if _paused:
		EngineDebugger.line_poll()
		return true
	if _resume_key == location_key:
		_resume_key = ""
		_pause_next = _step_after_resume
		_step_after_resume = false
		EngineDebugger.send_message("%s:line" % CAPTURE_PREFIX, [state])
		return false
	if (
		_pause_next
		or (
			EngineDebugger.is_breakpoint(line, path)
			and not EngineDebugger.is_skipping_breakpoints()
		)
	):
		_pause_next = false
		_paused = true
		_paused_manager = weakref(manager)
		EngineDebugger.send_message("%s:breakpoint" % CAPTURE_PREFIX, [state])
		return true
	EngineDebugger.send_message("%s:line" % CAPTURE_PREFIX, [state])
	return false


static func _ensure_capture() -> void:
	if _capture_registered and EngineDebugger.has_capture(CAPTURE_PREFIX):
		return
	if EngineDebugger.has_capture(CAPTURE_PREFIX):
		_capture_registered = true
		return
	EngineDebugger.register_message_capture(CAPTURE_PREFIX, _capture_message)
	_capture_registered = true


static func _capture_message(message: String, _data: Array) -> bool:
	match message:
		"continue":
			_resume_key = _current_key
			_paused = false
			_pause_next = false
			_step_after_resume = false
			_resume_execution()
			return true
		"step":
			_resume_key = _current_key
			_paused = false
			_step_after_resume = true
			_resume_execution()
			return true
		"pause_next":
			_pause_next = true
			return true
		_:
			return false


static func _resume_execution() -> void:
	if _paused_manager == null:
		return
	var manager := _paused_manager.get_ref()
	_paused_manager = null
	if (
		manager != null
		and is_instance_valid(manager)
		and manager.has_method("_resume_from_debugger")
	):
		manager.call_deferred("_resume_from_debugger")


static func _persistent_variables(manager: Object) -> Dictionary:
	var store: Object = manager.get("variable_store")
	if store == null:
		return {}
	if store.has_method("get_all"):
		var all_values: Variant = store.call("get_all")
		if all_values is Dictionary:
			return (all_values as Dictionary).duplicate(true)
	var available := {}
	for property: Dictionary in store.get_property_list():
		available[String(property.get("name", ""))] = true
	for property_name: String in ["_variables", "variables", "variable_store", "data"]:
		if not available.has(property_name):
			continue
		var value: Variant = store.get(property_name)
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {}


static func _dictionary_property(object: Object, property_name: String) -> Dictionary:
	var value: Variant = object.get(property_name)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}
