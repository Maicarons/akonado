extends SceneTree

const SERVICE_PATH := "res://addons/konado/localization/konado_story_localization.gd"
const TRANSLATION_PATHS := {
	"zh_Hans": "res://addons/konado/localization/translations/konado.zh_Hans.po",
	"zh_Hant": "res://addons/konado/localization/translations/konado.zh_Hant.po",
	"en": "res://addons/konado/localization/translations/konado.en.po",
	"ja": "res://addons/konado/localization/translations/konado.ja.po",
	"ko": "res://addons/konado/localization/translations/konado.ko.po",
}

var _failures := 0
var _service: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var service_script := load(SERVICE_PATH) as GDScript
	_expect(service_script != null, "story localization service script exists")
	if service_script == null:
		_finish()
		return
	_expect(service_script.can_instantiate(), "story localization service compiles")
	if not service_script.can_instantiate():
		_finish()
		return

	_service = service_script.new()
	root.add_child(_service)
	for method: String in [
		"get_script_candidates",
		"resolve_script_path",
		"load_localized_script",
		"get_base_script_path",
		"get_script_locale",
	]:
		_expect(_service.has_method(method), "story service exposes %s()" % method)

	_test_godot_owns_locale_state(_service)
	_test_script_candidates(_service)
	_test_script_resolution(_service)
	_test_localized_script_loading(_service)
	_test_native_translation_registration()
	_test_builtin_ui_translations()
	_test_demo_localized_scripts(_service)
	await _test_dialogue_manager_native_notification(_service)
	_finish()


func _test_godot_owns_locale_state(service: Node) -> void:
	_expect(not service.has_method("set_locale"), "story service does not own locale state")
	_expect(not service.has_method("get_locale"), "story service does not mirror Godot locale")
	_expect(
		not service.has_signal("locale_changed"),
		"story service does not duplicate Godot translation notifications",
	)
	TranslationServer.set_locale("zh-Hant")
	_expect_equal(
		TranslationServer.get_locale(),
		"zh_Hant",
		"Godot standardizes and owns the active locale",
	)
	_expect_equal(
		service.resolve_script_path("res://tests/localization/fixtures/story.ks", ""),
		"res://tests/localization/fixtures/story.zh_Hant.ks",
		"an omitted story locale follows TranslationServer",
	)


func _test_script_candidates(service: Node) -> void:
	var candidates: PackedStringArray = service.get_script_candidates(
		"res://story/chapter1.ks", "zh-CN"
	)
	_expect_equal(candidates[0], "res://story/chapter1.zh_CN.ks", "exact locale wins")
	_expect(
		"res://story/chapter1.zh_Hans.ks" in candidates,
		"Godot's expanded Chinese script locale participates in fallback",
	)
	_expect_equal(candidates[-1], "res://story/chapter1.ks", "base script is final fallback")
	_expect_equal(
		service.get_script_candidates("res://story/chapter1.en.ks", "ja")[-1],
		"res://story/chapter1.ks",
		"localized input paths resolve from the base script",
	)
	_expect_equal(
		service.get_base_script_path("res://story/chapter.one.ks"),
		"res://story/chapter.one.ks",
		"ordinary filename suffixes are not treated as locales",
	)
	_expect_equal(
		service.get_base_script_path("res://story/chapter.v1.ks"),
		"res://story/chapter.v1.ks",
		"non-alphabetic two-character suffixes are not locales",
	)


func _test_script_resolution(service: Node) -> void:
	_expect_equal(
		service.resolve_script_path("res://tests/localization/fixtures/story.ks", "zh_Hant"),
		"res://tests/localization/fixtures/story.zh_Hant.ks",
		"resolver selects the matching localized script",
	)
	_expect_equal(
		service.resolve_script_path("res://tests/localization/fixtures/story.ks", "ko", false),
		"res://tests/localization/fixtures/story.ks",
		"resolver falls back to the base script",
	)


func _test_localized_script_loading(service: Node) -> void:
	var shot := (
		service.load_localized_script("res://tests/localization/fixtures/story.ks", "zh_Hant")
		as KonadoShot
	)
	_expect(shot != null, "localized script loader returns a KonadoShot")
	if shot == null:
		return
	_expect_equal(
		shot.source_path,
		"res://tests/localization/fixtures/story.zh_Hant.ks",
		"localized shot retains its resolved source path",
	)
	_expect_equal(
		shot.instruction_at(1).value(&"content"),
		"Traditional second line",
		"localized values come from the validated overlay",
	)


func _test_native_translation_registration() -> void:
	var translation := Translation.new()
	translation.locale = "fr_CA"
	translation.add_message("KONADO_NATIVE_TRANSLATION_TEST", "Traduction native")
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale("fr-CA")
	_expect_equal(
		TranslationServer.translate("KONADO_NATIVE_TRANSLATION_TEST"),
		"Traduction native",
		"custom translations use Godot directly",
	)
	_expect(
		"fr_CA" in TranslationServer.get_loaded_locales(),
		"Godot exposes custom loaded locales",
	)
	TranslationServer.remove_translation(translation)


func _test_builtin_ui_translations() -> void:
	var reference := load(TRANSLATION_PATHS["zh_Hans"]) as Translation
	_expect(reference != null, "reference UI translation loads")
	if reference == null:
		return
	var reference_keys := reference.get_message_list()
	reference_keys.sort()
	_expect(not reference_keys.is_empty(), "built-in UI translation catalog is not empty")
	for message_key: StringName in reference_keys:
		_expect(
			String(message_key).begins_with("KONADO_"),
			"built-in UI translations use collision-resistant message IDs",
		)
	for locale: String in TRANSLATION_PATHS:
		var translation := load(TRANSLATION_PATHS[locale]) as Translation
		_expect(translation != null, "built-in translation exists for %s" % locale)
		if translation == null:
			continue
		_expect_equal(translation.locale, locale, "%s declares its locale" % locale)
		var keys := translation.get_message_list()
		keys.sort()
		_expect_equal(keys, reference_keys, "%s has the complete UI catalog" % locale)
		_expect(
			locale in TranslationServer.get_loaded_locales(),
			"%s is registered through Godot project translations" % locale,
		)
	TranslationServer.set_locale("en")
	_expect_equal(
		TranslationServer.translate("KONADO_SAVE_ACTION"),
		"Save",
		"runtime UI follows Godot's active locale",
	)


func _test_demo_localized_scripts(service: Node) -> void:
	var expected_second_lines := {
		"zh_Hans": "和我一起用Konado做视觉小说吧！",
		"zh_Hant": "和我一起用 Konado 製作視覺小說吧！",
		"en": "Let's create a visual novel with Konado!",
		"ja": "Konadoで一緒にビジュアルノベルを作りましょう！",
		"ko": "Konado로 함께 비주얼 노벨을 만들어 봐요!",
	}
	var expected_instruction_count := -1
	for locale: String in expected_second_lines:
		var shot := (
			service.load_localized_script("res://sample/demo/demo_01.ks", locale) as KonadoShot
		)
		_expect(shot != null, "demo script loads for %s" % locale)
		if shot == null:
			continue
		if expected_instruction_count < 0:
			expected_instruction_count = shot.instruction_count()
		_expect_equal(
			shot.instruction_count(),
			expected_instruction_count,
			"localized Programs keep one control-flow shape",
		)
		var dialogue_lines: Array[String] = []
		for pc: int in range(shot.instruction_count()):
			var instruction := shot.instruction_at(pc)
			if instruction.opcode() == KonadoOpcode.Type.DIALOGUE:
				dialogue_lines.append(instruction.value(&"content"))
		_expect_equal(
			dialogue_lines[1],
			expected_second_lines[locale],
			"demo dialogue is translated for %s" % locale,
		)


func _test_dialogue_manager_native_notification(service: Node) -> void:
	var manager := KonadoDialogueManager.new()
	manager.initialize_on_ready = false
	manager.require_visible_in_tree = false
	root.add_child(manager)
	await process_frame
	manager.set("_story_localization", service)
	var base_shot := (
		service.load_localized_script("res://tests/localization/fixtures/story.ks", "ko", false)
		as KonadoShot
	)
	_expect(manager._install_shot(base_shot), "dialogue manager installs the base Program")
	manager.start_dialogue_shot = base_shot
	manager._vm.pc = 1
	var stable_key := manager._current_instruction().stable_key()
	TranslationServer.set_locale("zh_Hant")
	await process_frame
	await process_frame
	_expect_equal(
		manager._current_instruction().stable_key(),
		stable_key,
		"native locale notification preserves the current instruction",
	)
	_expect_equal(
		manager._current_instruction().value(&"content"),
		"Traditional second line",
		"native locale notification swaps the story overlay",
	)
	manager.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("FAIL: " + message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		return
	_failures += 1
	printerr("FAIL: %s\n  expected: %s\n  actual:   %s" % [message, expected, actual])


func _finish() -> void:
	if is_instance_valid(_service):
		root.remove_child(_service)
		_service.free()
	if _failures == 0:
		print("PASS: Godot-native localization and KonadoScript story adapter tests")
	quit(_failures)
