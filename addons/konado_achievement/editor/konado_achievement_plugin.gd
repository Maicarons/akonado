@tool
extends EditorPlugin

const AUTOLOAD_NAME := "KonadoAchievements"
const AUTOLOAD_PATH := "res://addons/konado_achievement/runtime/konado_achievement_manager.gd"


func _enter_tree() -> void:
	_ensure_autoload()


func _disable_plugin() -> void:
	_remove_owned_autoload()


func _ensure_autoload() -> void:
	var setting_name := "autoload/" + AUTOLOAD_NAME
	if not ProjectSettings.has_setting(setting_name):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
		return
	var configured_path := _resolve_autoload_path(ProjectSettings.get_setting(setting_name))
	if configured_path != AUTOLOAD_PATH:
		push_error(
			(
				"Cannot enable Konado Achievement: autoload '%s' already points to '%s'."
				% [AUTOLOAD_NAME, configured_path]
			)
		)


func _remove_owned_autoload() -> void:
	var setting_name := "autoload/" + AUTOLOAD_NAME
	if (
		ProjectSettings.has_setting(setting_name)
		and _resolve_autoload_path(ProjectSettings.get_setting(setting_name)) == AUTOLOAD_PATH
	):
		remove_autoload_singleton(AUTOLOAD_NAME)


func _resolve_autoload_path(value: Variant) -> String:
	var path := String(value).trim_prefix("*")
	if path.begins_with("uid://"):
		return ResourceUID.get_id_path(ResourceUID.text_to_id(path))
	return path
