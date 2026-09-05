extends SceneTree

const SCRIPT_LINK_OVERLAY := preload(
	"res://addons/konado/editor/script_editor/konado_script_link_overlay.gd"
)


class DebugManager:
	extends Node

	var resume_count := 0

	func _resume_from_debugger() -> void:
		resume_count += 1


var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if Engine.is_editor_hint():
		var filesystem := EditorInterface.get_resource_filesystem()
		while filesystem.is_scanning() or filesystem.is_importing():
			await process_frame
		await process_frame
	_test_document_cache()
	_test_atomic_file()
	_test_incremental_project_index()
	_test_formatter()
	_test_typed_completion()
	_test_control_flow_analysis()
	_test_lowered_program_diagnostics()
	_test_localization_validation()
	_test_editor_localization()
	_test_quick_fixes()
	_test_code_edit_transaction()
	_test_adaptive_diagnostic_card()
	await _test_diagnostic_hover_interaction()
	_test_refactor_plan()
	await _test_runtime_debugger_resume()
	_test_editor_plugin_contracts()
	if _failures == 0:
		print("PASS: KonadoScript editor service tests")
	await process_frame
	quit(_failures)


func _test_document_cache() -> void:
	var store := KonadoScriptDocumentStore.new()
	var first := store.update_buffer("res://tests/cache.ks", "branch intro\n\tend")
	var revision := first.revision
	var second := store.update_buffer("res://tests/cache.ks", "branch intro\n\tend")
	_expect(first == second, "document store reuses one semantic model per path")
	_expect(second.revision == revision, "identical source does not create a new revision")
	store.update_buffer("res://tests/cache.ks", "branch changed\n\tend")
	_expect(second.revision == revision + 1, "changed source advances the semantic revision")
	_expect(second.branch_definitions.has("changed"), "document model exposes compiler symbols")
	_expect(
		not second.get_analysis().has("ast"),
		"cached document revisions release the compiler AST after projecting editor data",
	)
	var empty := store.update_buffer("res://tests/empty.ks", "")
	_expect(empty.source.is_empty(), "empty unsaved buffers never fall back to stale disk content")


func _test_atomic_file() -> void:
	var path := "user://konado_atomic_file_test.ks"
	_expect(
		KonadoScriptAtomicFile.replace_text(path, "first") == OK, "atomic writer creates a new file"
	)
	_expect(
		KonadoScriptAtomicFile.replace_text(path, "second") == OK,
		"atomic writer replaces an existing file"
	)
	var file := FileAccess.open(path, FileAccess.READ)
	_expect(
		file != null and file.get_as_text() == "second", "atomic writer preserves complete content"
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_incremental_project_index() -> void:
	var path := "res://tests/editor/fixtures/editor_refactor.ks"
	var store := KonadoScriptDocumentStore.shared()
	var original := store.get_document(path).source
	var index := KonadoScriptProjectIndex.shared()
	index.get_values("scripts")
	var changed := store.update_buffer(path, original + "\nbranch unsaved_index_symbol\n\tend")
	index.update_document(changed)
	_expect(
		not index.get_definitions("branches", "unsaved_index_symbol").is_empty(),
		"incremental project index includes unsaved KonadoScript revisions",
	)
	var restored := store.update_buffer(path, original)
	index.update_document(restored)
	_expect(
		index.get_definitions("branches", "unsaved_index_symbol").is_empty(),
		"incremental project index removes symbols from superseded revisions",
	)


func _test_formatter() -> void:
	var source := (
		"if   %score   ==   1:\n"
		+ '  "Kona"   "spaces   inside"   # keep   comment\n'
		+ " else:   \n"
		+ "screentext   {\n"
		+ ' "full   text"\n'
		+ " }\n"
		+ "endif"
	)
	var formatted := KonadoScriptFormatter.format_document(source, "    ")
	_expect(
		'"Kona" "spaces   inside" # keep   comment' in formatted,
		"formatter normalizes syntax spacing without changing strings or comments",
	)
	_expect(
		"\nelse:\n    screentext {\n" in formatted,
		"formatter applies deterministic nested indentation",
	)
	_expect(
		KonadoScriptFormatter.format_document(formatted, "    ") == formatted,
		"formatter output is idempotent",
	)


func _test_typed_completion() -> void:
	var language := KonadoScriptLanguage.new()
	var variables := language._get_completion_candidates("set %score 0", "set %")
	var variables_are_typed := not variables.is_empty()
	for item: Dictionary in variables:
		if item.get("kind") != CodeEdit.CodeCompletionKind.KIND_VARIABLE:
			variables_are_typed = false
			break
	_expect(
		variables_are_typed,
		"semantic completion assigns variable candidates their native Godot completion kind",
	)


func _test_control_flow_analysis() -> void:
	var document := KonadoScriptDocument.new()
	(
		document
		. update(
			'choice "Start" -> used\nbranch used\n\tjump_branch missing\nbranch orphan\n\tend',
			"res://tests/story.ks",
		)
	)
	var diagnostics := KonadoScriptControlFlowAnalyzer.analyze(document)
	_expect(
		diagnostics.any(
			func(item: Dictionary) -> bool: return item.get("code") == "missing_branch"
		),
		"control-flow analysis reports missing branches",
	)
	_expect(
		diagnostics.any(
			func(item: Dictionary) -> bool: return item.get("code") == "unreachable_branch"
		),
		"control-flow analysis reports unreferenced branches",
	)
	var compiler := KonadoScriptCompiler.new()
	compiler.set_console_output_enabled(false)
	var dead_branch := (
		compiler
		. compile_string(
			'end\nbranch orphan\n\t"Kona" "Optional content"\n\tend',
			"res://tests/dead-branch.ks",
		)
	)
	_expect(dead_branch != null, "dead branch content is a warning rather than a build failure")
	_expect(
		compiler.get_warnings().any(func(item: String) -> bool: return "不可从程序入口到达" in item),
		"compiler preserves a warning for unreachable executable instructions",
	)


func _test_lowered_program_diagnostics() -> void:
	var actor_document := KonadoScriptDocument.new()
	actor_document.update("actor change Kona happy\nend", "res://tests/external-stage.ks")
	_expect(actor_document.valid, "externally prepared stage actors remain valid compositions")
	_expect(
		actor_document.get_diagnostics("zh_CN").any(
			func(item: Dictionary) -> bool: return "无法在当前文件中确认角色" in String(item.get("message", ""))
		),
		"live editor diagnostics include lowered Program data-flow warnings",
	)
	var variable_document := KonadoScriptDocument.new()
	variable_document.update("add $score 1\nend", "res://tests/undefined-temp.ks")
	_expect(
		not variable_document.valid, "undefined temporary variables fail full document analysis"
	)
	_expect(
		variable_document.get_diagnostics("zh_CN").any(
			func(item: Dictionary) -> bool: return "当前所有路径上尚未定义" in String(item.get("message", ""))
		),
		"live editor diagnostics expose Program data-flow errors before a build",
	)


func _test_localization_validation() -> void:
	var unchanged := (
		KonadoScriptLocalizationValidator
		. compare(
			'"Kona" "这是全屏文本"',
			'"Kona" "这是全屏文本"',
			"res://story.ks",
			"res://story.zh_Hans.ks",
			"zh_Hans",
		)
	)
	_expect(
		unchanged["diagnostics"].is_empty(),
		"localized text content is never inspected to guess whether translation is complete",
	)
	var comparison := (
		KonadoScriptLocalizationValidator
		. compare(
			'"Kona" "Hello"\nchoice "Continue" -> next\nbranch next\n\tend',
			'"Kona" "你好"\nchoice "继续" -> next\nbranch next\n\tend',
		)
	)
	_expect(
		comparison["compatible"], "translated text may differ while structure remains compatible"
	)
	var resized_screen_text := (
		KonadoScriptLocalizationValidator
		. compare(
			'screentext {\n    "First"\n    "Second"\n} [id=opening]\nend',
			'screentext {\n    "合并后的本地化文本"\n} [id=opening]\nend',
		)
	)
	_expect(
		resized_screen_text["compatible"],
		"localized screen text may use a locale-appropriate number of lines",
	)
	var translated_speaker := (
		KonadoScriptLocalizationValidator
		. compare(
			'"Narrator" "Hello"',
			'"旁白" "你好"',
		)
	)
	_expect(
		translated_speaker["compatible"],
		"quoted speaker labels are localizable text",
	)
	var translated_voice := KonadoScriptLocalizationValidator.compare(
		'Kona "Hello" voice_en', 'Kona "你好" voice_zh'
	)
	_expect(
		translated_voice["compatible"],
		"localized dialogue may select a locale-specific voice resource",
	)
	var changed_actor := KonadoScriptLocalizationValidator.compare('Kona "Hello"', 'Alice "你好"')
	_expect(
		(
			changed_actor["compatible"]
			and changed_actor["diagnostics"].size() == 1
			and changed_actor["diagnostics"][0].get("severity") == "warning"
		),
		"localized scripts may replace a static actor identifier with a warning",
	)
	var changed_staging := (
		KonadoScriptLocalizationValidator
		. compare(
			"actor show Kona normal at 1\nbackground room fade\nend",
			"actor show Alice winter at 3\nbackground snow wave\nend",
		)
	)
	_expect(
		(
			changed_staging["compatible"]
			and changed_staging["diagnostics"].all(
				func(item: Dictionary) -> bool: return item.get("severity") == "warning"
			)
		),
		"locale-specific actors, portraits and backgrounds remain compatible",
	)
	var changed_staging_opcode := (
		KonadoScriptLocalizationValidator
		. compare(
			"actor show Kona normal at 1\nend",
			"actor change Kona normal\nend",
		)
	)
	_expect(
		not changed_staging_opcode["compatible"],
		"localized scripts cannot replace the type of a presentation instruction",
	)
	var changed_stable_id := (
		KonadoScriptLocalizationValidator
		. compare(
			"actor show Kona normal at 1 [id=entrance]\nend",
			"actor show Alice winter at 3 [id=localized_entrance]\nend",
		)
	)
	_expect(
		not changed_stable_id["compatible"],
		"localized presentation instructions cannot replace a stable instruction ID",
	)
	var changed_dialogue_id := (
		KonadoScriptLocalizationValidator
		. compare(
			'Kona "Hello" [id=greeting]',
			'Alice "你好" [id=localized_greeting]',
		)
	)
	_expect(
		not changed_dialogue_id["compatible"],
		"localized dialogue cannot replace a stable instruction ID",
	)
	var broken := (
		KonadoScriptLocalizationValidator
		. compare(
			'choice "Continue" -> next\nbranch next\n\tend',
			'choice "继续" -> other\nbranch next\n\tend',
		)
	)
	_expect(not broken["compatible"], "localized branch target drift is reported")
	var inserted := (
		KonadoScriptLocalizationValidator
		. compare(
			'"Kona" "One"\n"Kona" "Two"\n"Kona" "Three"',
			'"Kona" "一"\n"Kona" "新增"\n"Kona" "二"\n"Kona" "三"',
		)
	)
	_expect(
		(
			(
				inserted["diagnostics"]
				. filter(func(item: Dictionary) -> bool: return item.get("code") == "locale_extra")
				. size()
			)
			== 1
		),
		"localization alignment isolates inserted rows instead of cascading later mismatches",
	)


func _test_editor_localization() -> void:
	_expect(
		KonadoScriptDiagnosticMessages.validate_catalog().is_empty(),
		"every static and dynamic diagnostic template has complete bilingual coverage",
	)
	_expect(
		KonadoScriptEditorLocale.resolve_locale("auto", "zh_CN", "en_US") == "zh_CN",
		"automatic editor language resolves through Godot's tool locale",
	)
	_expect(
		KonadoScriptEditorLocale.resolve_locale("en", "zh_CN", "zh_CN") == "en",
		"an explicitly configured editor language takes precedence",
	)
	var document := KonadoScriptDocument.new()
	document.update('if %love == 0:\n\t"Kona" "Hello"\nendif1', "diagnostic-test.ks")
	var chinese_diagnostics := document.get_diagnostics("zh_CN")
	var chinese_fixes := KonadoScriptQuickFixService.get_fixes(document, "zh_CN")
	_expect(
		(
			not chinese_diagnostics.is_empty()
			and "无法识别的语法" in chinese_diagnostics[0]["message"]
			and "应为 endif" in chinese_diagnostics[0]["message"]
		),
		"diagnostic messages follow the Chinese editor locale",
	)
	_expect(
		not chinese_fixes.is_empty() and chinese_fixes[0]["title"] == "替换为“endif”",
		"diagnostic quick fixes follow the Chinese editor locale",
	)
	var compiler := KonadoScriptCompiler.new()
	compiler.set_console_output_enabled(false)
	var analysis := compiler.analyze_string("cam fly", "res://tests/diagnostic-test.ks")
	var records: Array = analysis.get("diagnostics", [])
	var english_diagnostics := (
		KonadoScriptDiagnostics
		. new()
		. analyze_result(
			"cam fly",
			"res://tests/diagnostic-test.ks",
			"en",
			analysis,
		)
	)
	_expect(
		(
			records.size() == 1
			and records[0].get("code") == "syntax.camera_action"
			and records[0].get("arguments") == ["fly"]
		),
		"compiler stages expose stable diagnostic codes and structured arguments",
	)
	_expect(
		(
			english_diagnostics.size() == 1
			and english_diagnostics[0]["message"].begins_with("Unknown cam action")
			and english_diagnostics[0]["end_column"] > english_diagnostics[0]["column"]
		),
		"structured editor diagnostics localize without parsing console strings and expose a range",
	)


func _test_quick_fixes() -> void:
	var document := KonadoScriptDocument.new()
	document.update("if %score == 1: # keep\n\tendif_bad # explain", "res://tests/fixes.ks")
	var fixes := KonadoScriptQuickFixService.get_fixes(document)
	var normalize := {}
	for fix: Dictionary in fixes:
		if fix.get("code") == "normalize_endif":
			normalize = KonadoScriptQuickFixService.materialize_line_fix(document.source, fix)
			break
	_expect(not normalize.is_empty(), "quick fixes recognize malformed endif")
	if not normalize.is_empty():
		var fixed := KonadoScriptQuickFixService.apply_fix(document.source, normalize)
		_expect(
			fixed.ends_with("\tendif # explain"),
			"quick fix changes only the malformed token and preserves comments",
		)
		_expect(
			not fixes.any(func(fix: Dictionary) -> bool: return fix.get("code") == "append_endif"),
			"normalizing a malformed endif also balances its conditional block",
		)
	var stale_fix := (
		KonadoScriptQuickFixService
		. materialize_line_fix(
			document.source,
			{"line_edit": true, "line": 999, "replacement_line": ""},
		)
	)
	_expect(
		stale_fix.is_empty(),
		"stale quick fixes cannot address a line outside the current revision",
	)
	var fixed_all := KonadoScriptQuickFixService.apply_all_fixes(
		"if %score == 1\n\tendif_bad\n}", "res://tests/fixes.ks"
	)
	_expect(
		fixed_all == "if %score == 1:\n\tendif\n",
		"all safe quick fixes apply directly to one current editor revision",
	)
	var choice_document := KonadoScriptDocument.new()
	choice_document.update('choice "Continue" next', "res://tests/fixes.ks")
	var choice_fix := KonadoScriptQuickFixService.get_fixes(choice_document, "en").filter(
		func(fix: Dictionary) -> bool: return fix.get("code") == "insert_choice_arrow"
	)
	_expect(
		(
			choice_fix.size() == 1
			and (
				(
					KonadoScriptQuickFixService
					. apply_fix(
						choice_document.source,
						(
							KonadoScriptQuickFixService
							. materialize_line_fix(
								choice_document.source,
								choice_fix[0],
							)
						),
					)
				)
				== 'choice "Continue" -> next'
			)
		),
		"quick fixes insert an unambiguous missing choice arrow",
	)
	var boolean_document := KonadoScriptDocument.new()
	(
		boolean_document
		. update(
			'achievement set_flag "ending" maybe',
			"res://tests/fixes.ks",
		)
	)
	var boolean_diagnostic := boolean_document.get_diagnostics("en")[0]
	var boolean_fixes := KonadoScriptQuickFixService.get_fixes(boolean_document, "en").filter(
		func(fix: Dictionary) -> bool:
			return KonadoScriptQuickFixService.matches_diagnostic(fix, boolean_diagnostic)
	)
	_expect(
		(
			boolean_fixes.size() == 2
			and boolean_fixes.all(
				func(fix: Dictionary) -> bool: return not bool(fix.get("safe", true))
			)
		),
		"one diagnostic may offer multiple explicit alternatives without marking a choice as safe",
	)
	_expect(
		(
			(
				KonadoScriptQuickFixService
				. apply_all_fixes(
					boolean_document.source,
					boolean_document.path,
				)
			)
			== boolean_document.source
		),
		"apply-all never chooses between non-deterministic quick-fix alternatives",
	)
	var actor_document := KonadoScriptDocument.new()
	actor_document.update("actor show Kona normal", "res://tests/fixes.ks")
	var actor_diagnostics := actor_document.get_diagnostics("en")
	var actor_position_diagnostic := {}
	for diagnostic: Dictionary in actor_diagnostics:
		if diagnostic.get("code") == "syntax.actor_position":
			actor_position_diagnostic = diagnostic
			break
	var actor_fixes := (
		KonadoScriptQuickFixService
		. rank_fixes_for_diagnostic(
			KonadoScriptQuickFixService.get_fixes(actor_document, "en"),
			actor_position_diagnostic,
		)
	)
	_expect(
		(
			not actor_position_diagnostic.is_empty()
			and actor_fixes.size() == KonadoScriptQuickFixService.MAX_CANDIDATES_PER_DIAGNOSTIC
			and actor_fixes.all(
				func(fix: Dictionary) -> bool: return not bool(fix.get("safe", true))
			)
		),
		"missing actor positions offer every valid position without choosing one as safe",
	)
	for position_index: int in actor_fixes.size():
		var actor_fix := (
			KonadoScriptQuickFixService
			. materialize_line_fix(
				actor_document.source,
				actor_fixes[position_index],
			)
		)
		_expect(
			(
				KonadoScriptQuickFixService.apply_fix(actor_document.source, actor_fix)
				== (
					"actor show Kona normal at %s"
					% KonadoScriptLanguageCatalog.LIKELY_POSITION_VALUES[position_index]
				)
			),
			"each actor position suggestion applies its distinct candidate",
		)
	_expect(
		(
			(
				KonadoScriptQuickFixService
				. apply_all_fixes(
					actor_document.source,
					actor_document.path,
				)
			)
			== actor_document.source
		),
		"apply-all does not guess an actor position",
	)
	var keyword_typo_document := KonadoScriptDocument.new()
	(
		keyword_typo_document
		. update(
			"actor exit1 Kona\nend写错",
			"res://tests/fixes.ks",
		)
	)
	var keyword_typo_fixes := KonadoScriptQuickFixService.get_fixes(keyword_typo_document, "zh_CN")
	var actor_action_fix := keyword_typo_fixes.filter(
		func(fix: Dictionary) -> bool:
			return (
				fix.get("code") == "replace_context_keyword"
				and fix.get("replacement_line") == "actor exit Kona"
			)
	)
	var root_keyword_fix := keyword_typo_fixes.filter(
		func(fix: Dictionary) -> bool:
			return (
				fix.get("code") == "replace_root_keyword" and fix.get("replacement_line") == "end"
			)
	)
	_expect(
		(
			actor_action_fix.size() == 1
			and root_keyword_fix.size() == 1
			and not bool(actor_action_fix[0].get("safe", true))
			and not bool(root_keyword_fix[0].get("safe", true))
		),
		"likely root and contextual keyword typos offer explicit non-destructive corrections",
	)
	var ranked_candidates := (
		KonadoScriptQuickFixService
		. rank_fixes_for_diagnostic(
			[
				{"code": "low", "line": 1, "safe": false, "confidence": 0.2},
				{"code": "safe", "line": 1, "safe": true, "confidence": 0.1},
				{"code": "high", "line": 1, "safe": false, "confidence": 0.9},
				{"code": "medium", "line": 1, "safe": false, "confidence": 0.6},
			],
			{"line": 1, "code": "test"},
		)
	)
	_expect(
		(
			ranked_candidates.size() == 3
			and ranked_candidates[0].get("code") == "safe"
			and ranked_candidates[1].get("code") == "high"
			and ranked_candidates[2].get("code") == "medium"
		),
		"quick-fix candidates are capped at three with safe and likely edits first",
	)


func _test_code_edit_transaction() -> void:
	var code_edit := CodeEdit.new()
	root.add_child(code_edit)
	code_edit.text = "alpha\nbeta\ngamma"
	code_edit.select(0, 1, 0, 4)
	var second_caret := code_edit.add_caret(2, 2)
	_expect(second_caret >= 0, "native editor accepts a secondary caret for transaction testing")
	KonadoScriptCodeEditTransaction.replace_text(code_edit, "alpha!\nbeta\ngamma")
	_expect(
		(
			code_edit.get_caret_count() == 2
			and code_edit.has_selection(0)
			and code_edit.get_selection_from_column(0) == 1
			and code_edit.get_selection_to_column(0) == 4
			and code_edit.get_caret_line(1) == 2
			and code_edit.get_caret_column(1) == 2
		),
		"whole-document edits preserve native selections and multiple carets",
	)
	root.remove_child(code_edit)
	code_edit.free()


func _test_adaptive_diagnostic_card() -> void:
	var code_edit := CodeEdit.new()
	code_edit.size = Vector2(1000, 600)
	root.add_child(code_edit)
	var overlay := SCRIPT_LINK_OVERLAY.new()
	code_edit.add_child(overlay)
	overlay.setup(code_edit)
	overlay._ensure_diagnostic_panel()
	(
		overlay
		. _add_diagnostic_entry(
			{"message": "Short", "actions": [{"kind": "docs"}]},
			[],
			"",
		)
	)
	overlay._layout_diagnostic_content()
	var short_width: float = overlay._diagnostic_scroll.custom_minimum_size.x
	var short_wrap_mode: int = overlay._diagnostic_wrap_labels[0].autowrap_mode
	overlay._clear_diagnostic_content()
	(
		overlay
		. _add_diagnostic_entry(
			{
				"message":
				(
					(
						"This diagnostic is deliberately repeated until its real rendered width exceeds "
						+ "the available editor viewport. "
					)
					. repeat(12)
				)
			},
			[],
			"",
		)
	)
	overlay._layout_diagnostic_content()
	var long_width: float = overlay._diagnostic_scroll.custom_minimum_size.x
	var long_wrap_mode: int = overlay._diagnostic_wrap_labels[0].autowrap_mode
	_expect(
		(
			short_width >= 360.0
			and short_wrap_mode == TextServer.AUTOWRAP_OFF
			and long_width <= code_edit.size.x - 56.0
			and long_wrap_mode == TextServer.AUTOWRAP_WORD_SMART
		),
		"diagnostic cards keep fitting content on one line and wrap only at the editor boundary",
	)
	overlay.cleanup()
	code_edit.remove_child(overlay)
	overlay.free()
	root.remove_child(code_edit)
	code_edit.free()


func _test_diagnostic_hover_interaction() -> void:
	var code_edit := CodeEdit.new()
	code_edit.size = Vector2(1000, 600)
	code_edit.text = "if %score == 1:\n\tendif_bad"
	root.add_child(code_edit)
	var overlay := SCRIPT_LINK_OVERLAY.new()
	code_edit.add_child(overlay)
	overlay.setup(code_edit)
	await process_frame
	var diagnostics := overlay.get_diagnostics_for_line(1)
	_expect(not diagnostics.is_empty(), "diagnostic hover test source produces an editor error")
	if not diagnostics.is_empty():
		var start_column := maxi(0, int(diagnostics[0].get("column", 1)) - 1)
		var end_column := maxi(
			start_column + 1,
			int(diagnostics[0].get("end_column", start_column + 2)) - 1,
		)
		overlay._update_diagnostic_hover_target(1, start_column, Vector2(200, 100))
		var target_key: String = overlay._pending_diagnostic_key
		overlay._show_diagnostic_hover()
		var inside_column := mini(start_column + 1, end_column - 1)
		overlay._update_diagnostic_hover_target(1, inside_column, Vector2(210, 100))
		_expect(
			(
				not target_key.is_empty()
				and overlay._pending_diagnostic_key == target_key
				and overlay._diagnostic_panel.visible
			),
			"moving inside one diagnostic range keeps the hover card visible",
		)
		overlay._update_diagnostic_hover_target(1, end_column + 1, Vector2(220, 110))
		_expect(
			overlay._diagnostic_panel.visible and overlay._diagnostic_dismiss_timer.is_stopped(),
			"crossing the narrow gap to the hover card does not start dismissal",
		)
		overlay._update_diagnostic_hover_target(1, end_column + 1, Vector2(800, 500))
		_expect(
			(
				overlay._diagnostic_panel.visible
				and not overlay._diagnostic_dismiss_timer.is_stopped()
			),
			"leaving the diagnostic starts a grace period without hiding the hover card",
		)
		overlay._on_diagnostic_panel_mouse_entered()
		await create_timer(0.25).timeout
		_expect(
			overlay._diagnostic_panel.visible and overlay._diagnostic_dismiss_timer.is_stopped(),
			"entering the hover card cancels dismissal so its actions remain clickable",
		)
		overlay._schedule_diagnostic_dismissal()
		await create_timer(0.25).timeout
		_expect(
			not overlay._diagnostic_panel.visible,
			"leaving both the diagnostic and hover card dismisses it after the grace period",
		)
		overlay._update_diagnostic_hover_target(1, start_column, Vector2(200, 100))
		overlay._show_diagnostic_hover()
		_expect(
			not overlay._diagnostic_wrap_buttons.is_empty(),
			"diagnostic hover exposes an actionable quick fix",
		)
		if not overlay._diagnostic_wrap_buttons.is_empty():
			overlay._diagnostic_wrap_buttons[0].pressed.emit()
			_expect(
				(
					code_edit.get_line(1).strip_edges() == "endif"
					and not overlay._diagnostic_panel.visible
				),
				"hover-card quick fixes remain clickable and close stale diagnostics",
			)
	overlay.cleanup()
	code_edit.remove_child(overlay)
	overlay.free()
	root.remove_child(code_edit)
	code_edit.free()


func _test_refactor_plan() -> void:
	var path := "res://tests/editor/fixtures/editor_refactor.ks"
	var plan := (
		KonadoScriptRefactorService
		. create_rename_plan(
			"branches",
			"intro",
			"opening",
			PackedStringArray([path]),
		)
	)
	_expect(plan["valid"], "cross-file rename produces a previewable valid plan")
	_expect(
		plan["changes"][0]["after"].contains("branch opening"),
		"rename plan updates semantic declarations",
	)
	var resource_plan := (
		KonadoScriptRefactorService
		. create_project_resource_rename_plan(
			"backgrounds",
			"bg_end",
			"bg_end_preview",
		)
	)
	_expect(resource_plan["valid"], "project resource rename produces a validated preview")
	var includes_owner_resource := false
	for change: Dictionary in resource_plan["changes"]:
		if String(change["path"]).ends_with("background_list.tres"):
			includes_owner_resource = true
			break
	_expect(
		includes_owner_resource,
		"project resource rename includes the owning resource declaration",
	)
	var stale_plan := resource_plan.duplicate(true)
	stale_plan["changes"][0]["before"] += "\n# changed after preview"
	_expect(
		not KonadoScriptRefactorService.validate_plan(stale_plan).is_empty(),
		"refactor validation rejects stale previews before writing any file",
	)


func _test_runtime_debugger_resume() -> void:
	var manager := DebugManager.new()
	root.add_child(manager)
	KonadoScriptRuntimeDebugger._current_key = "res://debug.ks:1:node"
	KonadoScriptRuntimeDebugger._paused = true
	KonadoScriptRuntimeDebugger._paused_manager = weakref(manager)
	KonadoScriptRuntimeDebugger._capture_message("continue", [])
	await process_frame
	_expect(manager.resume_count == 1, "debugger Continue resumes the suspended dialogue manager")
	KonadoScriptRuntimeDebugger._paused = true
	KonadoScriptRuntimeDebugger._paused_manager = weakref(manager)
	KonadoScriptRuntimeDebugger._capture_message("step", [])
	await process_frame
	_expect(
		manager.resume_count == 2 and KonadoScriptRuntimeDebugger._step_after_resume,
		"debugger Step resumes once and arms a pause for the following statement",
	)
	KonadoScriptRuntimeDebugger._paused = false
	KonadoScriptRuntimeDebugger._pause_next = false
	KonadoScriptRuntimeDebugger._step_after_resume = false
	KonadoScriptRuntimeDebugger._resume_key = ""
	root.remove_child(manager)
	manager.free()


func _test_editor_plugin_contracts() -> void:
	var integration_script := (
		load("res://addons/konado/editor/script_editor/konado_script_editor_integration.gd")
		as GDScript
	)
	var context_menu_script := (
		load("res://addons/konado/editor/script_editor/konado_script_code_context_menu.gd")
		as GDScript
	)
	var debugger_script := (
		load("res://addons/konado/editor/script_editor/konado_script_debugger_plugin.gd")
		as GDScript
	)
	_expect(
		_script_has_methods(
			integration_script,
			PackedStringArray(["get_instruction_tree", "get_docs_button", "get_locale_selector"]),
		),
		"KonadoScript extends the current native Script workspace",
	)
	_expect(
		_script_has_methods(
			context_menu_script,
			PackedStringArray(["_apply_quick_fix", "_apply_all_quick_fixes"]),
		),
		"quick fixes operate on the active native CodeEdit",
	)
	_expect(
		_script_has_methods(
			debugger_script, PackedStringArray(["_has_capture", "_capture", "_setup_session"])
		),
		"debugger plugin implements Godot's debugger protocol contract",
	)


func _script_has_methods(script: GDScript, required: PackedStringArray) -> bool:
	if script == null:
		return false
	var available := PackedStringArray()
	for method: Dictionary in script.get_script_method_list():
		available.append(String(method.get("name", "")))
	for method_name: String in required:
		if method_name not in available:
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: %s" % message)
