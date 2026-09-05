extends Node

## KonadoScript 剧情本地化适配层。
##
## 语言状态、UI 翻译、语言回退和语言变更通知全部由 Godot
## TranslationServer 管理。本服务只处理 Godot 不理解的 KonadoScript
## 语言变体、编译覆盖层与控制流一致性校验。

const SCRIPT_LOADER := preload("res://addons/konado/localization/konado_localized_script_loader.gd")

var _script_loader := SCRIPT_LOADER.new()


func get_script_candidates(script_path: String, locale: String = "") -> PackedStringArray:
	return _script_loader.get_script_candidates(script_path, _resolve_locale(locale))


func resolve_script_path(
	script_path: String, locale: String = "", warn_on_fallback: bool = true
) -> String:
	return _script_loader.resolve_script_path(
		script_path, _resolve_locale(locale), warn_on_fallback
	)


func load_localized_script(
	script_path: String, locale: String = "", warn_on_fallback: bool = true
) -> KonadoShot:
	return _script_loader.load_localized_script(
		script_path, _resolve_locale(locale), warn_on_fallback
	)


func get_base_script_path(script_path: String) -> String:
	return _script_loader.get_base_script_path(script_path)


func get_script_locale(script_path: String) -> String:
	return _script_loader.get_script_locale(script_path)


func _resolve_locale(locale: String) -> String:
	var requested := (
		locale if not locale.strip_edges().is_empty() else TranslationServer.get_locale()
	)
	return TranslationServer.standardize_locale(requested)
