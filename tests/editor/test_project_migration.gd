extends SceneTree

const PLUGIN_SCRIPT := preload("res://addons/konado/konado_editor_plugin.gd")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var configured := PackedStringArray(
		[
			"res://addons/konado/plugin.cfg",
			"res://addons/konado_webtool/plugin.cfg",
			"res://addons/konadotnet/plugin.cfg",
			"res://addons/konado_web_tool/plugin.cfg",
		]
	)
	_expect_equal(
		(
			PLUGIN_SCRIPT
			. migrate_enabled_plugin_paths(
				configured,
				PackedStringArray(
					[
						"res://addons/konado_web_tool/plugin.cfg",
						"res://addons/konado_dotnet/plugin.cfg",
					]
				),
			)
		),
		PackedStringArray(
			[
				"res://addons/konado/plugin.cfg",
				"res://addons/konado_web_tool/plugin.cfg",
				"res://addons/konado_dotnet/plugin.cfg",
			]
		),
		"legacy plugin paths migrate without duplicates",
	)
	_expect_equal(
		(
			PLUGIN_SCRIPT
			. migrate_enabled_plugin_paths(
				PackedStringArray(["res://addons/konadotnet/plugin.cfg"]),
				PackedStringArray(),
			)
		),
		PackedStringArray(["res://addons/konadotnet/plugin.cfg"]),
		"an optional plugin path is retained when its replacement is not installed",
	)
	_expect(
		(
			PLUGIN_SCRIPT
			. is_owned_legacy_autoload(
				"*res://addons/konado/i18n/knd_i18n.gd",
				["res://addons/konado/i18n/knd_i18n.gd"],
			)
		),
		"the official 2.7 localization path is recognized",
	)
	_expect(
		(
			PLUGIN_SCRIPT
			. is_owned_legacy_autoload(
				"*uid://c8y8inlr3ga6w",
				[
					"uid://c8y8inlr3ga6w",
					"res://addons/konado/i18n/knd_i18n.gd",
				],
			)
		),
		"the official UID-based 2.7 localization autoload is recognized",
	)
	_expect(
		(
			PLUGIN_SCRIPT
			. is_owned_legacy_autoload(
				"*uid://dlhxd0ixnuo6i",
				[
					"uid://dlhxd0ixnuo6i",
					"res://addons/konado_achievement/runtime/konado_achievement_manager.gd",
				],
			)
		),
		"official UID-based auxiliary autoloads are recognized",
	)
	_expect(
		not (
			PLUGIN_SCRIPT
			. is_owned_legacy_autoload(
				"*res://game/custom_i18n.gd",
				["res://addons/konado/i18n/knd_i18n.gd"],
			)
		),
		"same-name user autoloads are not treated as Konado-owned",
	)
	if _failures == 0:
		print("PASS: project migration tests")
	quit(_failures)


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
