@tool
extends EditorContextMenuPlugin
class_name KonadoScriptCreateMenu

const DEFAULT_FILE_NAME := "new_dialogue.ks"

var _dialog: EditorFileDialog


func _popup_menu(_paths: PackedStringArray) -> void:
	add_context_menu_item(
		KonadoScriptEditorLocale.text("KonadoScript...", "KonadoScript 剧本……"),
		_open_create_dialog,
	)


func cleanup() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null


func _open_create_dialog(context: Variant) -> void:
	if _dialog == null:
		_create_dialog()
	var directory := _resolve_directory(context)
	_dialog.current_dir = directory
	_dialog.current_file = DEFAULT_FILE_NAME
	_dialog.popup_file_dialog()


func _create_dialog() -> void:
	_dialog = EditorFileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_dialog.access = FileDialog.ACCESS_RESOURCES
	_dialog.filters = PackedStringArray(["*.ks ; KonadoScript"])
	_dialog.title = KonadoScriptEditorLocale.text("Create KonadoScript", "新建 KonadoScript 剧本")
	_dialog.file_selected.connect(_create_script)
	EditorInterface.get_base_control().add_child(_dialog)


func _resolve_directory(context: Variant) -> String:
	if context is PackedStringArray and not context.is_empty():
		return String(context[0])
	if context is Array and not context.is_empty():
		return String(context[0])
	var current_directory := EditorInterface.get_current_directory()
	return current_directory if not current_directory.is_empty() else "res://"


func _create_script(selected_path: String) -> void:
	var path := selected_path
	if path.get_extension().to_lower() != "ks":
		path += ".ks"
	path = ProjectSettings.localize_path(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_show_error(
			(
				KonadoScriptEditorLocale
				. text(
					"Could not create KonadoScript:\n%s" % path,
					"无法新建 KonadoScript：\n%s" % path,
				)
			)
		)
		return
	file.store_string(_get_template())
	var error := file.get_error()
	file.close()
	if error != OK and error != ERR_FILE_EOF:
		_show_error(
			(
				KonadoScriptEditorLocale
				. text(
					"Could not write KonadoScript:\n%s" % error_string(error),
					"无法写入 KonadoScript：\n%s" % error_string(error),
				)
			)
		)
		return
	EditorInterface.get_resource_filesystem().update_file(path)
	var script := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Script
	if script == null:
		_show_error(
			(
				KonadoScriptEditorLocale
				. text(
					"KonadoScript was created but could not be opened.",
					"KonadoScript 已创建，但无法打开。",
				)
			)
		)
		return
	EditorInterface.edit_script(script)


func _get_template() -> String:
	if KonadoScriptEditorLocale.is_chinese():
		return '"旁白" "在这里开始新的剧情。"\n\nend\n'
	return '"Narrator" "Start a new story here."\n\nend\n'


func _show_error(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = KonadoScriptEditorLocale.text("KonadoScript Error", "KonadoScript 错误")
	dialog.dialog_text = message
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()
