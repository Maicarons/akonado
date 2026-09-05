extends SceneTree

const DEFAULT_SCRIPT_PATH := "res://sample/demo/demo_01.ks"
const ENGLISH_SCRIPT_PATH := "res://sample/demo/demo_01.en.ks"
const SINGLE_LANGUAGE_SCRIPT_PATH := "res://tests/editor/fixtures/native_editor.ks"

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	while (
		EditorInterface.get_resource_filesystem().is_scanning()
		or EditorInterface.get_resource_filesystem().is_importing()
	):
		await process_frame
	await process_frame
	_test_variant_discovery()
	await _test_selector_ui()
	if _failures == 0:
		print("PASS: KonadoScript locale selector tests")
	quit(_failures)


func _test_variant_discovery() -> void:
	var variants := KonadoScriptEditorIntegration.get_script_variants(
		"res://sample/demo/demo_01.zh_Hant.ks"
	)
	var locales: Array[String] = []
	for variant: Dictionary in variants:
		locales.append(String(variant["locale"]))
	_expect_equal(
		variants.size(),
		6,
		"variant discovery includes the default and every localized script",
	)
	_expect_equal(
		variants[0]["path"],
		DEFAULT_SCRIPT_PATH,
		"variant discovery keeps the default script first",
	)
	for locale: String in ["zh_Hans", "zh_Hant", "en", "ja", "ko"]:
		_expect(locale in locales, "variant discovery includes locale: %s" % locale)
	_expect_equal(
		KonadoScriptEditorIntegration.get_language_display_name("zh_Hans"),
		"简体中文",
		"variant labels use language names instead of filenames",
	)


func _test_selector_ui() -> void:
	var script_editor := EditorInterface.get_script_editor()
	var single_language_script := (
		ResourceLoader.load(SINGLE_LANGUAGE_SCRIPT_PATH, "Script") as Script
	)
	_expect(single_language_script != null, "single-language fixture loads")
	if single_language_script == null:
		return
	EditorInterface.edit_script(single_language_script)
	await process_frame
	await process_frame
	var docs_button := script_editor.find_child("KonadoOnlineDocs", true, false) as Button
	var selector := (
		script_editor.find_child("KonadoScriptLocaleSelector", true, false) as OptionButton
	)
	_expect(docs_button != null, "KonadoScript documentation button exists")
	_expect(selector != null, "KonadoScript language selector exists")
	if selector == null or docs_button == null:
		return
	_expect(
		not selector.visible,
		"the language selector stays hidden for scripts without localized files",
	)

	var default_script := ResourceLoader.load(DEFAULT_SCRIPT_PATH, "Script") as Script
	_expect(default_script != null, "localized default script loads")
	if default_script == null:
		return
	EditorInterface.edit_script(default_script)
	await process_frame
	await process_frame
	_expect(selector.visible, "scripts with localized files show the language selector")
	_expect(
		selector.get_index() == docs_button.get_index() + 1,
		"the language selector is immediately right of online documentation",
	)
	_expect_equal(selector.item_count, 6, "the selector exposes all demo language versions")

	var labels: Array[String] = []
	var english_index := -1
	for index in range(selector.item_count):
		var label := selector.get_item_text(index)
		labels.append(label)
		_expect(
			not label.contains(".ks") and not label.contains("demo_01"),
			"language selector labels omit filenames and extensions",
		)
		if label == "English":
			english_index = index
	for expected_label: String in [
		KonadoScriptEditorLocale.text("Default", "默认"),
		"简体中文",
		"繁體中文",
		"English",
		"日本語",
		"한국어",
	]:
		_expect(expected_label in labels, "language selector includes: %s" % expected_label)

	_expect(english_index >= 0, "the language selector exposes English")
	if english_index >= 0:
		selector.select(english_index)
		selector.item_selected.emit(english_index)
		await process_frame
		await process_frame
		_expect(
			(
				script_editor.get_current_script() != null
				and script_editor.get_current_script().resource_path == ENGLISH_SCRIPT_PATH
			),
			"selecting a language opens that KonadoScript",
		)
		_expect(
			selector.visible and selector.get_item_text(selector.selected) == "English",
			"the selector follows the active localized script",
		)

	var gd_script := load("res://tests/dotnet/fake_dialogue_manager.gd") as Script
	if gd_script != null:
		EditorInterface.edit_script(gd_script)
		await process_frame
		await process_frame
		_expect(not selector.visible, "non-Konado scripts hide the language selector")
		script_editor.close_file(gd_script.resource_path)
	script_editor.close_file(SINGLE_LANGUAGE_SCRIPT_PATH)
	script_editor.close_file(DEFAULT_SCRIPT_PATH)
	script_editor.close_file(ENGLISH_SCRIPT_PATH)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAILED: %s" % message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	_expect(actual == expected, "%s (actual: %s, expected: %s)" % [message, actual, expected])
