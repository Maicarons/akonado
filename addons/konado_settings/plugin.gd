@tool
extends EditorPlugin

const AUTOLOAD_NAME := "KND_Settings"
const AUTOLOAD_PATH := "res://addons/konado_settings/scripts/settings_manager.gd"

func _enter_tree() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)

func _exit_tree() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
