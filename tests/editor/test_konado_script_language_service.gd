extends SceneTree

const CARET_MARKER := "\uFFFF"
const SCRIPT_LINK_OVERLAY := preload(
	"res://addons/konado/editor/script_editor/konado_script_link_overlay.gd"
)

var _failures := 0
var _selected_filesystem_path := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if Engine.is_editor_hint():
		await EditorInterface.get_resource_filesystem().filesystem_changed
		while (
			EditorInterface.get_resource_filesystem().is_scanning()
			or EditorInterface.get_resource_filesystem().is_importing()
		):
			await process_frame
	_test_parser_strictness()
	_test_project_index()
	_test_diagnostic_service()
	await _test_semantic_navigation()
	await _test_link_geometry()
	_test_project_diagnostics()
	_test_project_scripts_compile()
	if _failures == 0:
		print("PASS: KonadoScript language service tests")
	quit(_failures)


func _test_parser_strictness() -> void:
	var lexer := KonadoScriptLexer.new()
	lexer.console_output_enabled = false
	var tokens := lexer.tokenize("    branch opening-scene # inline comment", "strictness.ks")
	_expect(lexer.get_errors().is_empty(), "inline comments are ignored by the lexer")
	var branch_name_token: KonadoScriptToken = tokens.token_at(2)
	_expect(
		(
			tokens.size() >= 3
			and branch_name_token.value == "opening-scene"
			and branch_name_token.column == 12
		),
		"hyphenated identifiers retain their real indented source column",
	)
	var malformed_variable_tokens := lexer.tokenize("set % 1", "strictness.ks")
	_expect(
		not malformed_variable_tokens.is_empty(),
		"an isolated variable prefix is consumed without stalling live analysis",
	)
	var compiler := KonadoScriptCompiler.new()
	compiler.set_console_output_enabled(false)
	_expect(
		(
			compiler.compile_string(
				"jump_branch opening-scene\nbranch opening-scene\n    end", "strictness.ks"
			)
			!= null
		),
		"refactorable branch names are accepted by the compiler",
	)
	_expect(
		compiler.compile_string("background bg_end fade unexpected", "strictness.ks") == null,
		"fixed-arity commands reject trailing arguments",
	)
	_expect(
		compiler.compile_string("cam move cam2 linear invalid", "strictness.ks") == null,
		"camera durations reject non-numeric values",
	)
	_expect(
		compiler.compile_string("asyncam move cam2 ease_in_out 1.0", "strictness.ks") != null,
		"documented ease-in-out camera transitions compile",
	)
	_expect(
		compiler.compile_string("achievement set_flag flag maybe", "strictness.ks") == null,
		"achievement booleans reject ambiguous values",
	)
	_expect(
		compiler.compile_string("set $score", "strictness.ks") == null,
		"variable operations require an explicit value",
	)
	_expect(
		compiler.compile_string("if $score == 1.5:\nendif", "strictness.ks") == null,
		"integer conditions reject silently truncated decimal values",
	)
	_expect(
		compiler.compile_string("jump user://story.ks", "strictness.ks") == null,
		"cross-script jumps require an exported res:// KonadoScript path",
	)
	_expect(
		compiler.compile_string("showtextbox\nhidetextbox\nend", "strictness.ks") != null,
		"optional text-box durations match the language signature",
	)
	_expect(
		(
			(
				compiler
				. compile_string(
					(
						'if %love == 0:\n\t"Konado" "Tab-indented"\nendif\n'
						+ 'if %love == 1:\n    "Konado" "Space-indented"\nendif'
					),
					"strictness.ks",
				)
			)
			!= null
		),
		"equivalent tab and four-space indentation can coexist on separate lines",
	)
	_expect(
		(
			compiler.compile_string(
				'if %love == 0:\n \t"Konado" "Ambiguous"\nendif', "strictness.ks"
			)
			== null
		),
		"a single indentation prefix cannot mix tabs and spaces",
	)
	var diagnostics := KonadoScriptDiagnostics.new()
	var recovered := (
		diagnostics
		. analyze(
			"endif_bad\nbackground bg_end fade unexpected\nactor move Kona invalid",
			"strictness.ks",
		)
	)
	_expect(
		(
			_has_diagnostic_line(recovered, 1)
			and _has_diagnostic_line(recovered, 2)
			and _has_diagnostic_line(recovered, 3)
		),
		"parser recovery reports independent errors from multiple lines in one pass",
	)
	var lexical_errors := diagnostics.analyze('"first\n"second', "strictness.ks")
	_expect(
		_has_diagnostic_line(lexical_errors, 1) and _has_diagnostic_line(lexical_errors, 2),
		"lexer recovery reports multiple malformed strings in one pass",
	)
	var indented_lexical_error := diagnostics.analyze('    "unfinished', "strictness.ks")
	_expect(
		indented_lexical_error.size() == 1 and indented_lexical_error[0].get("column") == 5,
		"lexical diagnostics preserve columns after indentation",
	)


func _test_diagnostic_service() -> void:
	var diagnostics := KonadoScriptDiagnostics.new()
	var results := diagnostics.analyze("actor move missing 2", "diagnostic-test.ks")
	_expect(not results.is_empty(), "semantic warnings are exposed to the editor")
	if not results.is_empty():
		_expect(results[0]["severity"] == "warning", "diagnostic severity is preserved")
		_expect(results[0]["line"] == 1, "diagnostic line is structured")

	results = diagnostics.analyze("background room unknown_effect", "diagnostic-test.ks")
	_expect(
		(
			_has_diagnostic_containing(results, "unknown_effect")
			and _has_diagnostic_containing(results, "room")
		),
		"live diagnostics combine language constraints with unresolved project resources",
	)

	results = (
		diagnostics
		. analyze(
			'if %love == 0:\n    "Kona" "Hello"\nendif1',
			"diagnostic-test.ks",
			"zh_CN",
		)
	)
	_expect(
		(
			results.size() == 1
			and results[0]["severity"] == "error"
			and results[0]["line"] == 3
			and "endif1" in results[0]["message"]
			and "应为 endif" in results[0]["message"]
		),
		"malformed endif reports a diagnostic without stalling the editor",
	)
	results = (
		diagnostics
		. analyze(
			'if %love == 0:\n    "Kona" "Hello"',
			"diagnostic-test.ks",
			"zh_CN",
		)
	)
	_expect(
		results.size() == 1 and "缺少 endif" in results[0]["message"],
		"unterminated condition blocks report a diagnostic",
	)
	results = (
		diagnostics
		. analyze(
			'if %love == 0:1\n    "Kona" "Hello"\nendif',
			"diagnostic-test.ks",
			"zh_CN",
		)
	)
	_expect(
		(
			results.size() == 1
			and results[0]["severity"] == "error"
			and results[0]["line"] == 1
			and "冒号后不允许其他内容" in results[0]["message"]
		),
		"unexpected content after an if condition is never silently ignored",
	)
	results = (
		diagnostics
		. analyze(
			'if %love == 0:\n    "Kona" "Hello"\nelse:garbage\n    "Kona" "Fallback"\nendif',
			"diagnostic-test.ks",
			"en",
		)
	)
	_expect(
		(
			results.size() == 1
			and results[0]["line"] == 3
			and results[0]["message"] == "Nothing is allowed after the else colon."
		),
		"unexpected content after else is reported in the editor language",
	)
	results = (
		diagnostics
		. analyze(
			'if %love == 0:\n    "Kona" "Hello"',
			"diagnostic-test.ks",
			"en",
		)
	)
	_expect(
		results.size() == 1 and results[0]["message"] == "The if block requires endif.",
		"editor diagnostics follow a non-Chinese editor locale",
	)
	for message: String in KonadoScriptDiagnosticMessages.EXACT_ENGLISH:
		_expect(
			KonadoScriptDiagnosticMessages.localize(message, "en") != "KonadoScript: " + message,
			"static compiler diagnostic has an English translation: %s" % message,
		)
	_expect(
		(
			KonadoScriptDiagnosticMessages.localize("期望 IDENTIFIER，实际为 EOF", "en")
			== "Expected IDENTIFIER; got EOF."
		),
		"dynamic parser-context diagnostics are translated",
	)

	results = (
		diagnostics
		. analyze(
			"screentext {\n    invalid_content\n}",
			"diagnostic-test.ks",
		)
	)
	_expect(
		results.size() == 1 and "screentext" in results[0]["message"],
		"malformed screen text blocks report a diagnostic without stalling the editor",
	)
	results = (
		diagnostics
		. analyze(
			"jump res://missing/story.ks",
			"diagnostic-test.ks",
			"en",
		)
	)
	_expect(
		(
			results.size() == 1
			and results[0]["severity"] == "error"
			and (
				results[0]["message"]
				== "Target KonadoScript 'res://missing/story.ks' does not exist."
			)
		),
		"missing jump targets are reported instead of becoming clickable dead links",
	)


func _test_project_index() -> void:
	var project_index := KonadoScriptProjectIndex.shared()
	project_index.invalidate()
	var background := project_index.get_definition("backgrounds", "bg_end")
	_expect(
		(
			background.get("owner_path") == "res://sample/demo/background_list.tres"
			and (
				background.get("target_path")
				== "res://sample/demo/backgrounds/background_ending.tscn"
			)
			and int(background.get("line", 0)) > 0
		),
		"background IDs map to their declaration and final scene",
	)
	var actor := project_index.get_definition("actors", "Kona")
	_expect(
		actor.get("target_path") == "res://sample/demo/sample_character.tscn",
		"actor IDs map to character scenes",
	)
	_expect(
		project_index.get_actor_scoped_values("Kona", "states").has("正常"),
		"state completion is scoped to the selected actor scene",
	)
	var default_camera := project_index.get_definition("cameras", "cam1")
	_expect(
		(
			default_camera.get("target_path")
			== "res://sample/demo/backgrounds/background_parallax.tscn"
		),
		"camera IDs include exported defaults omitted from serialized scenes",
	)


func _test_semantic_navigation() -> void:
	var line := "background bg_end fade"
	var reference := KonadoScriptSymbolIndex.get_semantic_reference_at(
		line, line.find("bg_end") + 2
	)
	_expect(
		(
			reference.get("kind") == "backgrounds"
			and reference.get("name") == "bg_end"
			and reference.get("start") == line.find("bg_end")
			and reference.get("end") == line.find("bg_end") + "bg_end".length()
		),
		"semantic spans cover complete resource identifiers",
	)
	var link_controller := SCRIPT_LINK_OVERLAY.new()
	var native_lookup_editor := CodeEdit.new()
	native_lookup_editor.set_symbol_lookup_on_click_enabled(true)
	native_lookup_editor.set_symbol_tooltip_on_hover_enabled(true)
	native_lookup_editor.add_child(link_controller)
	link_controller.setup(native_lookup_editor)
	_expect(
		(
			not native_lookup_editor.is_symbol_lookup_on_click_enabled()
			and not native_lookup_editor.is_symbol_tooltip_on_hover_enabled()
			and link_controller.anchor_right == 1.0
			and link_controller.anchor_bottom == 1.0
		),
		"Konado semantic links use a full-size overlay and disable native word links",
	)
	var diagnostic_style := link_controller._create_diagnostic_panel_style()
	_expect(
		(
			is_equal_approx(diagnostic_style.bg_color.a, 0.8)
			and diagnostic_style.corner_radius_top_left == 20
			and diagnostic_style.corner_radius_top_right == 20
			and diagnostic_style.corner_radius_bottom_left == 20
			and diagnostic_style.corner_radius_bottom_right == 20
		),
		"diagnostic hover uses a 20-pixel rounded card with an 80% opaque background",
	)
	native_lookup_editor.size = Vector2(1200.0, 600.0)
	link_controller._ensure_diagnostic_panel()
	(
		link_controller
		. _add_diagnostic_entry(
			{
				"message": "无法识别的语法：end错字",
				"actions": [{"kind": "docs"}],
			},
			[],
			native_lookup_editor.text,
		)
	)
	link_controller._layout_diagnostic_content()
	_expect(
		(
			link_controller._diagnostic_wrap_labels[0].autowrap_mode == TextServer.AUTOWRAP_OFF
			and link_controller._diagnostic_wrap_buttons[0].autowrap_mode == TextServer.AUTOWRAP_OFF
			and not link_controller._diagnostic_wrap_buttons[0].clip_text
		),
		"diagnostic hover keeps fitting messages and complete action labels on one line",
	)
	link_controller._clear_diagnostic_content()
	native_lookup_editor.text = "if %score == 1:\n\tendif_bad"
	var hover_diagnostics := link_controller.get_diagnostics_for_line(1)
	var hover_fixes := link_controller.get_quick_fixes_for_line(1)
	_expect(
		not hover_diagnostics.is_empty() and not hover_fixes.is_empty(),
		"diagnostic hover resolves the current native editor line and its quick fixes",
	)
	if not hover_fixes.is_empty():
		link_controller._apply_hover_fix(hover_fixes[0], native_lookup_editor.text)
		_expect(
			native_lookup_editor.get_line(1).strip_edges() == "endif",
			"diagnostic hover fixes edit the active native CodeEdit through its undo history",
		)
	var targets := link_controller.resolve_navigation_targets(reference, line)
	_expect(
		(
			targets.size() == 1
			and targets[0].get("path") == "res://sample/demo/backgrounds/background_ending.tscn"
		),
		"background navigation resolves the final scene",
	)
	var navigation_cases := [
		{
			"line": "actor show Kona 正常 at 1",
			"token": "Kona",
			"target": "res://sample/demo/sample_character.tscn",
		},
		{
			"line": "actor show Kona 正常 at 1",
			"token": "正常",
			"target": "res://sample/demo/sample_character.tscn",
		},
		{
			"line": "actor motion Kona jump",
			"token": "jump",
			"target":
			"res://addons/konado/templates/default/character/konado_actor_motion_layer.tscn",
		},
		{
			"line": "play bgm echo",
			"token": "echo",
			"target": "res://sample/demo/background_music/echoes_of_home.mp3",
		},
		{
			"line": "cam move cam2",
			"token": "cam2",
			"target": "res://sample/demo/backgrounds/background_parallax.tscn",
		},
	]
	for test_case: Dictionary in navigation_cases:
		var case_line := String(test_case["line"])
		var case_reference := (
			KonadoScriptSymbolIndex
			. get_semantic_reference_at(
				case_line,
				case_line.find(String(test_case["token"])),
			)
		)
		var case_targets := link_controller.resolve_navigation_targets(case_reference, case_line)
		_expect(
			not case_targets.is_empty() and case_targets[0].get("path") == test_case["target"],
			"semantic navigation resolves %s" % test_case["token"],
		)
	_selected_filesystem_path = ""
	(
		link_controller
		. _schedule_filesystem_selection(
			"res://sample/demo/demo_03_variable.ks",
			_record_filesystem_selection,
		)
	)
	await process_frame
	_expect(
		_selected_filesystem_path == "res://sample/demo/demo_03_variable.ks",
		"KonadoScript navigation synchronizes the FileSystem dock selection",
	)
	var dialogue_line := 'Kona "回合=$score，奖励=%bonus"'
	var speaker_reference := KonadoScriptSymbolIndex.get_semantic_reference_at(dialogue_line, 1)
	var dialogue_variable := (
		KonadoScriptSymbolIndex
		. get_semantic_reference_at(
			dialogue_line,
			dialogue_line.find("$score") + 2,
		)
	)
	_expect(
		(
			speaker_reference.get("start") == 0
			and speaker_reference.get("end") == "Kona".length()
			and dialogue_variable.get("kind") == "variables"
			and dialogue_variable.get("name") == "$score"
			and dialogue_variable.get("start") == dialogue_line.find("$score")
			and (dialogue_variable.get("end") == dialogue_line.find("$score") + "$score".length())
		),
		"static actor and interpolated variable links use exact spans",
	)
	var dynamic_label := '"访客 $score" "你好"'
	var dynamic_label_references := KonadoScriptSymbolIndex.get_semantic_references(dynamic_label)
	_expect(
		(
			dynamic_label_references.size() == 1
			and dynamic_label_references[0].get("kind") == "variables"
			and dynamic_label_references[0].get("name") == "$score"
		),
		"interpolated text labels are not misclassified as actor references",
	)
	var screentext_source := 'screentext {\n    "Full-screen text with $score"\n}'
	var screentext_references := KonadoScriptSymbolIndex.get_semantic_references(screentext_source)
	var has_screentext_actor := false
	var has_screentext_variable := false
	for screentext_reference: Dictionary in screentext_references:
		has_screentext_actor = (
			has_screentext_actor or screentext_reference.get("kind") == "actors"
		)
		has_screentext_variable = (
			has_screentext_variable
			or (
				screentext_reference.get("kind") == "variables"
				and screentext_reference.get("name") == "$score"
			)
		)
	_expect(
		not has_screentext_actor and has_screentext_variable,
		"full-screen text is not treated as an actor while interpolated variables remain semantic",
	)
	var highlighter := KonadoScriptSyntaxHighlighter.new()
	var highlighting := highlighter._highlight_line_text(dialogue_line, Color.WHITE)
	_expect(
		(
			(
				_color_at(highlighting, dialogue_line.find("$score"), Color.WHITE)
				== KonadoScriptSyntaxHighlighter.VARIABLE_COLOR
			)
			and (
				_color_at(highlighting, dialogue_line.find("%bonus"), Color.WHITE)
				== KonadoScriptSyntaxHighlighter.VARIABLE_COLOR
			)
		),
		"variables interpolated inside dialogue strings retain variable highlighting",
	)
	var local_source := "set $score 0\n%s" % dialogue_line
	var local_reference := (
		KonadoScriptSymbolIndex
		. get_semantic_reference_at(
			dialogue_line,
			dialogue_line.find("$score"),
		)
	)
	var local_targets := link_controller.resolve_navigation_targets(local_reference, local_source)
	_expect(
		local_targets.size() == 1 and local_targets[0].get("line") == 1,
		"local variable navigation resolves its declaration",
	)
	link_controller.cleanup()
	_expect(
		(
			native_lookup_editor.is_symbol_lookup_on_click_enabled()
			and native_lookup_editor.is_symbol_tooltip_on_hover_enabled()
		),
		"native link behavior is restored after leaving KonadoScript",
	)
	native_lookup_editor.free()
	var language := KonadoScriptLanguage.new()
	var embedded_lookup := (
		language
		. _lookup_code(
			'set $score 0\n"Kona" "回合=$s%score"' % CARET_MARKER,
			"$score",
			"res://source.ks",
			null,
		)
	)
	_expect(
		embedded_lookup.get("result") == ERR_UNAVAILABLE,
		"dialogue variables defer to exact-span semantic links instead of native string lookup",
	)
	var lookup := (
		language
		. _lookup_code(
			"background bg_%send fade" % CARET_MARKER,
			"bg_end",
			"res://source.ks",
			null,
		)
	)
	_expect(
		lookup.get("result") == ERR_UNAVAILABLE,
		"project resources defer to the scene and resource navigation layer",
	)
	lookup = (
		language
		. _lookup_code(
			"jump_%sbranch final" % CARET_MARKER,
			"jump_branch",
			"res://source.ks",
			null,
		)
	)
	_expect(
		lookup.get("result") == ERR_UNAVAILABLE,
		"command keywords never masquerade as source declarations",
	)


func _test_project_diagnostics() -> void:
	var diagnostics := KonadoScriptDiagnostics.new()
	_expect(
		diagnostics.analyze("background bg_end fade", "semantic.ks").is_empty(),
		"valid indexed resources do not produce false diagnostics",
	)
	var missing := diagnostics.analyze("play sfx missing_effect", "semantic.ks", "en")
	_expect(
		(
			not missing.is_empty()
			and missing[0]["message"] == "Unknown sound effect: 'missing_effect'."
		),
		"unknown resource IDs are reported in the editor locale",
	)
	var valid_screentext_and_camera := (
		'screentext {\n    "这是全屏文本"\n}\n' + "asyncam move cam1 linear 1.0"
	)
	_expect(
		diagnostics.analyze(valid_screentext_and_camera, "semantic.ks", "en").is_empty(),
		"screentext content and default camera IDs do not produce false diagnostics",
	)
	var missing_actor := diagnostics.analyze('UnknownActor "Hello"', "semantic.ks", "en")
	_expect(
		_has_diagnostic_containing(missing_actor, "UnknownActor"),
		"bare dialogue actors are checked against project resources",
	)
	_expect(
		diagnostics.analyze('"Narrator" "Hello"', "semantic.ks", "en").is_empty(),
		"quoted text labels do not require an actor resource",
	)


func _test_project_scripts_compile() -> void:
	for path: String in KonadoScriptProjectIndex.shared().get_values("scripts"):
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_expect(false, "indexed KonadoScript can be read: %s" % path)
			continue
		var compiler := KonadoScriptCompiler.new()
		compiler.set_console_output_enabled(false)
		var valid := compiler.validate_string(file.get_as_text(), path)
		_expect(
			valid,
			(
				"project KonadoScript passes the strict parser: %s (%s)"
				% [path, "; ".join(compiler.get_errors())]
			),
		)


func _test_link_geometry() -> void:
	var editor := CodeEdit.new()
	editor.size = Vector2(1000, 200)
	editor.text = "\tactor show Kona normal at 1"
	root.add_child(editor)
	var overlay := SCRIPT_LINK_OVERLAY.new()
	editor.add_child(overlay)
	overlay.setup(editor)
	await process_frame
	var token_start := editor.get_line(0).find("Kona")
	var boundary_rect := editor.get_rect_at_line_column(0, token_start)
	var character_rect := overlay._get_character_rect(0, token_start)
	_expect(
		boundary_rect.position.x >= 0 and character_rect.position.x == boundary_rect.end.x,
		"semantic underlines map caret boundaries to the following visible grapheme",
	)
	overlay.cleanup()
	editor.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: %s" % message)


func _record_filesystem_selection(path: String) -> void:
	_selected_filesystem_path = path


func _has_diagnostic_line(diagnostics: Array[Dictionary], line: int) -> bool:
	for diagnostic: Dictionary in diagnostics:
		if diagnostic.get("line") == line:
			return true
	return false


func _has_diagnostic_containing(diagnostics: Array[Dictionary], fragment: String) -> bool:
	return diagnostics.any(
		func(diagnostic: Dictionary) -> bool:
			return fragment in String(diagnostic.get("message", ""))
	)


func _color_at(highlighting: Dictionary, column: int, default_color: Color) -> Color:
	var color := default_color
	for start_column: int in highlighting:
		if start_column > column:
			break
		color = highlighting[start_column]["color"]
	return color
