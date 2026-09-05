@tool
extends RefCounted
class_name KonadoScriptEditorLocale

## Small editor-facing locale adapter.
##
## Godot's editor language can differ from the operating-system locale. Konado
## editor UI therefore reads the current and legacy editor-language settings,
## resolves `auto` through Godot's tool locale, and only then falls back to the
## operating-system locale.

const EDITOR_LANGUAGE_SETTINGS := [
	"interface/editor/localization/editor_language",
	"interface/editor/editor_language",
]


static func get_editor_locale() -> String:
	if Engine.is_editor_hint():
		var settings := EditorInterface.get_editor_settings()
		if settings != null:
			for setting_path: String in EDITOR_LANGUAGE_SETTINGS:
				if not settings.has_setting(setting_path):
					continue
				var configured_locale := String(settings.get_setting(setting_path))
				if not configured_locale.is_empty():
					return resolve_locale(
						configured_locale,
						TranslationServer.get_tool_locale(),
						OS.get_locale(),
					)
	return resolve_locale("", TranslationServer.get_tool_locale(), OS.get_locale())


static func resolve_locale(
	configured_locale: String,
	tool_locale: String,
	os_locale: String,
) -> String:
	var normalized := configured_locale.strip_edges()
	if not normalized.is_empty() and normalized.to_lower() != "auto":
		return normalized
	if not tool_locale.is_empty() and tool_locale.to_lower() != "auto":
		return tool_locale
	return os_locale if not os_locale.is_empty() else "en"


static func is_chinese(locale: String = "") -> bool:
	var resolved_locale := locale if not locale.is_empty() else get_editor_locale()
	return resolved_locale.to_lower().begins_with("zh")


static func text(english: String, chinese: String, locale: String = "") -> String:
	return chinese if is_chinese(locale) else english
