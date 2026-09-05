extends SceneTree

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var story_localization := root.get_node_or_null("KonadoStoryLocalization")
	var settings := root.get_node_or_null("KonadoSettings")
	_expect(story_localization != null, "KonadoStoryLocalization autoload exists")
	_expect(settings != null, "KonadoSettings autoload exists")
	_expect(
		root.get_node_or_null("KonadoLocalization") == null,
		"the obsolete parallel localization service is absent",
	)
	if story_localization == null or settings == null:
		_finish()
		return

	var configured_locale := TranslationServer.standardize_locale(
		str(settings.get_setting("display", "language"))
	)
	_expect_equal(
		TranslationServer.get_locale(),
		configured_locale,
		"Konado Settings applies its persisted preference to Godot",
	)
	for locale: String in ["zh_Hans", "zh_Hant", "en", "ja", "ko"]:
		_expect(
			locale in TranslationServer.get_loaded_locales(),
			"Godot project translations include %s" % locale,
		)

	var original_locale := str(settings.get_setting("display", "language"))
	var target_locale := "ja" if original_locale != "ja" else "en"
	_expect(
		settings.set_setting("display", "language", target_locale),
		"language preference can be changed",
	)
	_expect_equal(
		TranslationServer.get_locale(),
		target_locale,
		"the settings plugin changes Godot directly",
	)
	settings.set_setting("display", "language", original_locale)
	_finish()


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
	if _failures == 0:
		print("PASS: Godot-native localization autoload integration tests")
	quit(_failures)
