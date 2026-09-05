extends SceneTree

const ACHIEVEMENT_MANAGER_SCRIPT := preload(
	"res://addons/konado_achievement/runtime/konado_achievement_manager.gd"
)
const SETTINGS_MANAGER_SCRIPT := preload(
	"res://addons/konado_settings/runtime/konado_settings_manager.gd"
)
const WEBTOOL_SCRIPT := preload("res://addons/konado_web_tool/runtime/konado_web_tool.gd")

const ACHIEVEMENT_SAVE_PATH := "user://konado_test_achievements.json"
const SETTINGS_SAVE_PATH := "user://konado_test_settings.cfg"

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_test_files()
	await _test_settings()
	await _test_achievements()
	_test_webtool_configuration()
	_cleanup_test_files()
	if _failures == 0:
		print("PASS: auxiliary plugin tests")
	quit(_failures)


func _test_settings() -> void:
	var manager: Node = SETTINGS_MANAGER_SCRIPT.new()
	manager.save_path = SETTINGS_SAVE_PATH
	root.add_child(manager)
	await process_frame

	var changes: Array[Array] = []
	manager.setting_changed.connect(
		func(category: String, key: String, value: Variant) -> void:
			changes.append([category, key, value])
	)
	_expect(
		manager.set_setting("audio", "master_volume", 0.5),
		"settings accept an in-range numeric value"
	)
	_expect_equal(
		manager.get_setting("audio", "master_volume"),
		0.5,
		"settings expose a persisted numeric value"
	)
	_expect(
		not manager.set_setting("audio", "master_volume", 2.0),
		"settings reject an out-of-range numeric value"
	)
	_expect(
		not manager.set_setting("display", "language", "invalid"),
		"settings reject a value outside an option list"
	)
	_expect(
		not manager.set_setting("unknown", "value", true),
		"settings reject an unknown category and key"
	)
	_expect_equal(changes.size(), 1, "rejected settings do not emit change signals")

	var category := _create_runtime_category()
	manager.register_category(category)
	_expect(
		manager.set_setting("runtime", "enabled", true),
		"runtime categories can persist valid values"
	)

	var restored_manager: Node = SETTINGS_MANAGER_SCRIPT.new()
	restored_manager.save_path = SETTINGS_SAVE_PATH
	root.add_child(restored_manager)
	await process_frame
	restored_manager.register_category(_create_runtime_category())
	_expect_equal(
		restored_manager.get_setting("runtime", "enabled"),
		true,
		"runtime categories restore values loaded before registration"
	)

	var reset_changes: Array[String] = []
	restored_manager.setting_changed.connect(
		func(category_id: String, key: String, _value: Variant) -> void:
			if category_id == "runtime":
				reset_changes.append(key)
	)
	_expect(restored_manager.reset_category("runtime"), "category reset succeeds")
	_expect_equal(
		restored_manager.get_setting("runtime", "enabled"),
		false,
		"category reset restores the default value"
	)
	_expect_equal(reset_changes, ["enabled"], "category reset emits one change per changed item")
	_expect(
		not FileAccess.file_exists(SETTINGS_SAVE_PATH + ".tmp"),
		"settings persistence leaves no temporary file"
	)

	manager.queue_free()
	restored_manager.queue_free()
	await process_frame


func _test_achievements() -> void:
	var manager: Node = ACHIEVEMENT_MANAGER_SCRIPT.new()
	manager.save_path = ACHIEVEMENT_SAVE_PATH
	root.add_child(manager)
	await process_frame
	manager.set("_popup_scene", null)

	var achievement: Dictionary = manager.get_achievement("first_blood")
	achievement["conditions"]["target_key"] = "mutated"
	_expect_equal(
		manager.get_achievement("first_blood")["conditions"]["target_key"],
		"story_branch_unlocked",
		"achievement queries return deep copies"
	)
	var missing_result: Dictionary = manager.try_unlock_achievement("missing")
	_expect_equal(
		missing_result.get("operation"),
		"achievement.unlock",
		"structured achievement failures identify the exact operation",
	)
	_expect_equal(
		missing_result.get("resource_id"),
		"missing",
		"structured achievement failures identify the exact resource",
	)
	var invalid_progress: Dictionary = manager.try_increment_progress("", 1.0)
	_expect_equal(
		invalid_progress.get("resource_kind"),
		"progress_key",
		"progress failures identify their resource kind",
	)

	var unlocked_ids: Array[String] = []
	manager.achievement_unlocked.connect(
		func(achievement_id: String, _data: Dictionary) -> void: unlocked_ids.append(achievement_id)
	)
	manager.increment_progress("story_branch_unlocked", 1.0)
	_expect(manager.is_unlocked("first_blood"), "counter progress unlocks its achievement")
	_expect_equal(unlocked_ids, ["first_blood"], "unlock signal is emitted once")
	_expect(
		not FileAccess.file_exists(ACHIEVEMENT_SAVE_PATH + ".tmp"),
		"achievement persistence leaves no temporary file"
	)

	var restored_manager: Node = ACHIEVEMENT_MANAGER_SCRIPT.new()
	restored_manager.save_path = ACHIEVEMENT_SAVE_PATH
	root.add_child(restored_manager)
	await process_frame
	restored_manager.set("_popup_scene", null)
	_expect(
		restored_manager.is_unlocked("first_blood"), "achievement state survives a manager reload"
	)

	var reset_ids: Array[String] = []
	restored_manager.achievement_reset.connect(
		func(achievement_id: String) -> void: reset_ids.append(achievement_id)
	)
	restored_manager.reset_achievement("first_blood")
	_expect(not restored_manager.is_unlocked("first_blood"), "single achievement reset succeeds")
	_expect_equal(reset_ids, ["first_blood"], "single achievement reset emits its signal")

	manager.queue_free()
	restored_manager.queue_free()
	await process_frame


func _test_webtool_configuration() -> void:
	var webtool: Node = WEBTOOL_SCRIPT.new()
	var shortcuts: String = webtool._build_shortcuts_js_array()
	_expect(shortcuts.contains("macAlt"), "WebTool defines macOS Option-key shortcuts")
	_expect(
		not shortcuts.contains("keyCode"), "WebTool does not generate deprecated keyCode checks"
	)
	_expect(not webtool.allow_in_release, "WebTool disables release shortcuts by default")
	webtool.free()


func _create_runtime_category() -> KonadoSettingCategory:
	var category := KonadoSettingCategory.new()
	category.id = "runtime"
	category.display_name = "Runtime"
	var item := KonadoSettingItem.new()
	item.key = "enabled"
	item.label = "Enabled"
	item.type = KonadoSettingItem.Type.TOGGLE
	item.default_value = false
	item.platforms.append("all")
	category.items.append(item)
	return category


func _cleanup_test_files() -> void:
	for path: String in [
		ACHIEVEMENT_SAVE_PATH,
		ACHIEVEMENT_SAVE_PATH + ".tmp",
		ACHIEVEMENT_SAVE_PATH + ".bak",
		SETTINGS_SAVE_PATH,
		SETTINGS_SAVE_PATH + ".tmp",
		SETTINGS_SAVE_PATH + ".bak",
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("FAIL: %s" % message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		return
	_failures += 1
	push_error("FAIL: %s (expected %s, got %s)" % [message, expected, actual])
