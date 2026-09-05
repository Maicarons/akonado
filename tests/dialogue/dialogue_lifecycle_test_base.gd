extends SceneTree

const DIALOGUE_MANAGER_SCENE := preload(
	"res://addons/konado/templates/default/dialogue_runtime.tscn"
)
const DIALOGUE_BOX_SCENE := preload("res://addons/konado/templates/default/dialogue_box.tscn")

var _failures: int = 0


class WarningCapture:
	extends Logger

	var fallback_warnings: Array[String] = []

	func _log_error(
		_function: String,
		_file: String,
		_line: int,
		code: String,
		_rationale: String,
		_editor_notify: bool,
		error_type: int,
		_script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING and code.begins_with("KonadoStoryLocalization:"):
			fallback_warnings.append(code)


class RuntimeErrorCapture:
	extends Logger

	var errors: Array[String] = []

	func _log_error(
		_function: String,
		_file: String,
		_line: int,
		code: String,
		_rationale: String,
		_editor_notify: bool,
		error_type: int,
		_script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append(code)


class FakeLocalizedScriptService:
	extends Node

	var localized_shot: KonadoShot

	func load_localized_script(
		_script_path: String, _locale: String = "", _warn_on_fallback: bool = true
	) -> KonadoShot:
		return localized_shot


func _create_manager() -> KonadoDialogueManager:
	var manager := DIALOGUE_MANAGER_SCENE.instantiate() as KonadoDialogueManager
	manager.initialize_on_ready = false
	manager.require_visible_in_tree = false
	manager.enable_overlay_log = false
	manager.auto_show_dialogue_box = false
	manager.typing_interval = 0.001
	manager.dialogue_box.enable_typing_effect_audio = false
	root.add_child(manager)
	await process_frame
	manager.dialogue_box.fade_duration = 0.01
	return manager


func _compile_shot(source: String, path := "") -> KonadoShot:
	var compiler := KonadoScriptCompiler.new()
	compiler.set_console_output_enabled(false)
	var shot := compiler.compile_string(source, path)
	_expect(shot != null, "fixture compiles: %s" % [compiler.get_errors()])
	return shot


func _make_visibility_shot(
	id_prefix: String, speaker: String, content: String, duration: float
) -> KonadoShot:
	return _compile_shot(
		(
			(
				"showtextbox [duration=%s] [id=show_%s]\n"
				+ '"%s" "%s" [id=line_%s]\n'
				+ "hidetextbox [duration=%s] [id=hide_%s]\n"
				+ "end [id=end_%s]"
			)
			% [duration, id_prefix, speaker, content, id_prefix, duration, id_prefix, id_prefix]
		),
		"",
	)


func _make_shot(content: String) -> KonadoShot:
	return _compile_shot('"Kona" "%s" [id=start]\nend [id=done]' % content)


func _free_node(node: Node) -> void:
	node.queue_free()
	await process_frame
	await process_frame


func _wait_for_state(manager: KonadoDialogueManager, expected_state: int) -> void:
	for _frame: int in range(30):
		if manager.dialogue_state == expected_state:
			return
		await process_frame
	_expect(false, "dialogue manager reaches state %d" % expected_state)


func _wait_for_instruction_and_state(
	manager: KonadoDialogueManager, expected_key: String, expected_state: int
) -> void:
	await _wait_for_condition(
		func() -> bool:
			var instruction := manager._current_instruction()
			return (
				instruction != null
				and instruction.stable_key() == expected_key
				and manager.dialogue_state == expected_state
			),
		"dialogue reaches instruction %s in state %d" % [expected_key, expected_state],
	)


func _wait_for_condition(condition: Callable, message: String) -> void:
	for _frame: int in range(240):
		if condition.call():
			return
		await process_frame
	_expect(false, message)


func _wait_for_typing_connection_count(
	manager: KonadoDialogueManager, expected_count: int, message: String
) -> void:
	for _frame: int in range(60):
		if manager.dialogue_box.typing_completed.get_connections().size() == expected_count:
			return
		await process_frame
	_expect_equal(
		manager.dialogue_box.typing_completed.get_connections().size(),
		expected_count,
		message,
	)


func _finish_current_dialogue(manager: KonadoDialogueManager) -> void:
	if manager._dialogue_typing:
		manager.dialogue_box.skip_typing_anim()
		await _wait_for_condition(
			func() -> bool: return not manager._dialogue_typing,
			"typewriter publishes its completion",
		)
	manager._process_next()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	printerr("ASSERTION FAILED: " + message)
	_failures += 1


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	_expect(actual == expected, "%s (expected %s, got %s)" % [message, expected, actual])
