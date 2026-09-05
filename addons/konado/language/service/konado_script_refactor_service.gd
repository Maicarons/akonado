@tool
extends RefCounted
class_name KonadoScriptRefactorService

## Cross-file semantic rename planner. Plans are previewed before any file changes.

const RESOURCE_PROPERTIES := {
	"actors": "character_id",
	"backgrounds": "background_name",
	"background_music_tracks": "background_music_name",
	"sfx": "sound_effect_name",
	"voices": "voice_name",
}


static func create_rename_plan(
	kind: String,
	old_name: String,
	new_name: String,
	paths: PackedStringArray,
) -> Dictionary:
	var errors := PackedStringArray()
	if not KonadoScriptSymbolIndex.is_valid_local_symbol(kind, new_name):
		errors.append(KonadoScriptEditorLocale.text("Invalid symbol name.", "符号名称无效。"))
	var changes: Array[Dictionary] = []
	for path: String in paths:
		var document := KonadoScriptDocumentStore.shared().get_document(path)
		var references := document.get_references(kind, old_name)
		if references.is_empty():
			continue
		var updated := _apply_reference_edits(document.source, references, new_name)
		if updated == document.source:
			continue
		(
			changes
			. append(
				{
					"path": path,
					"before": document.source,
					"after": updated,
					"occurrences": references.size(),
				}
			)
		)
	return {
		"kind": kind,
		"old_name": old_name,
		"new_name": new_name,
		"changes": changes,
		"errors": errors,
		"valid": errors.is_empty() and not changes.is_empty(),
	}


static func create_project_resource_rename_plan(
	kind: String,
	old_name: String,
	new_name: String,
	current_path: String = "",
	current_source: String = "",
) -> Dictionary:
	var errors := PackedStringArray()
	if kind not in RESOURCE_PROPERTIES:
		errors.append(
			KonadoScriptEditorLocale.text(
				"This resource kind cannot be renamed safely.", "此类资源无法安全重命名。"
			)
		)
	if not KonadoScriptSymbolIndex.is_valid_identifier(new_name):
		errors.append(KonadoScriptEditorLocale.text("Invalid symbol name.", "符号名称无效。"))
	var changes_by_path := {}
	var index := KonadoScriptProjectIndex.shared()
	if not errors.is_empty():
		return _plan(kind, old_name, new_name, [], errors)
	if not index.get_definitions(kind, new_name).is_empty() and new_name != old_name:
		errors.append(
			KonadoScriptEditorLocale.text("The new resource name already exists.", "新的资源名称已存在。")
		)
	var declaration_changes := 0
	for definition: Dictionary in index.get_definitions(kind, old_name):
		var owner_path := String(definition.get("owner_path", ""))
		if owner_path.is_empty():
			continue
		var source := _read_source(owner_path, current_path, current_source)
		var updated := _rename_property_on_line(
			source,
			int(definition.get("line", 1)),
			String(RESOURCE_PROPERTIES[kind]),
			old_name,
			new_name,
		)
		if updated != source:
			declaration_changes += 1
		_merge_change(changes_by_path, owner_path, source, updated, 1)
	if declaration_changes == 0:
		(
			errors
			. append(
				(
					KonadoScriptEditorLocale
					. text(
						"No editable resource declaration was found.",
						"未找到可安全编辑的资源声明。",
					)
				)
			)
		)
	for script_path: String in index.get_values("scripts"):
		var source := _read_source(script_path, current_path, current_source)
		var document := KonadoScriptDocumentStore.shared().update_buffer(script_path, source)
		var references := document.get_references(kind, old_name)
		if references.is_empty():
			continue
		var updated := _apply_reference_edits(source, references, new_name)
		_merge_change(changes_by_path, script_path, source, updated, references.size())
	var changes: Array[Dictionary] = []
	for path: String in changes_by_path:
		changes.append(changes_by_path[path])
	changes.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return String(left["path"]).naturalnocasecmp_to(String(right["path"])) < 0
	)
	return _plan(kind, old_name, new_name, changes, errors)


static func validate_plan(plan: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray(plan.get("errors", PackedStringArray()))
	for change: Dictionary in plan.get("changes", []):
		var path := String(change.get("path", ""))
		var disk_source := _read_disk_source(path)
		if disk_source != String(change.get("before", "")):
			(
				errors
				. append(
					(
						KonadoScriptEditorLocale
						. text(
							(
								"File changed after the refactor preview; save or reload it first: %s"
								% path
							),
							"文件在重构预览后已发生变化；请先保存或重新加载：%s" % path,
						)
					)
				)
			)
			continue
		if path.get_extension().to_lower() != "ks":
			continue
		var compiler := KonadoScriptCompiler.new()
		compiler.set_console_output_enabled(false)
		if not compiler.validate_string(String(change.get("after", "")), path):
			(
				errors
				. append(
					(
						KonadoScriptEditorLocale
						. text(
							"Refactored script is invalid: %s" % path,
							"重构后的剧本无效：%s" % path,
						)
					)
				)
			)
	return errors


static func apply_plan(plan: Dictionary) -> Error:
	var errors := validate_plan(plan)
	if not errors.is_empty():
		return ERR_INVALID_DATA
	var written: Array[Dictionary] = []
	for change: Dictionary in plan.get("changes", []):
		var path := String(change["path"])
		var after := String(change["after"])
		var save_error := _save_source(path, after)
		if save_error != OK:
			for completed: Dictionary in written:
				_save_source(String(completed["path"]), String(completed["before"]))
			return save_error
		written.append(change)
		KonadoScriptDocumentStore.shared().update_buffer(path, after)
	KonadoScriptProjectIndex.shared().invalidate()
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan_sources()
	return OK


static func _apply_reference_edits(
	source: String,
	references: Array[Dictionary],
	new_name: String,
) -> String:
	var offsets := PackedInt32Array([0])
	for index: int in source.length():
		if source[index] == "\n":
			offsets.append(index + 1)
	var edits: Array[Dictionary] = []
	for reference: Dictionary in references:
		var line_index := int(reference["line"]) - 1
		if line_index < 0 or line_index >= offsets.size():
			continue
		(
			edits
			. append(
				{
					"start": offsets[line_index] + int(reference["start"]),
					"end": offsets[line_index] + int(reference["end"]),
				}
			)
		)
	edits.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return int(left["start"]) > int(right["start"])
	)
	var updated := source
	for edit: Dictionary in edits:
		updated = (updated.left(int(edit["start"])) + new_name + updated.substr(int(edit["end"])))
	return updated


static func _plan(
	kind: String,
	old_name: String,
	new_name: String,
	changes: Array,
	errors: PackedStringArray,
) -> Dictionary:
	return {
		"kind": kind,
		"old_name": old_name,
		"new_name": new_name,
		"changes": changes,
		"errors": errors,
		"valid": errors.is_empty() and not changes.is_empty(),
	}


static func _read_source(path: String, current_path: String, current_source: String) -> String:
	if path == current_path:
		return current_source
	if path.get_extension().to_lower() == "ks":
		return KonadoScriptDocumentStore.shared().get_document(path).source
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()


static func _rename_property_on_line(
	source: String,
	line_number: int,
	property_name: String,
	old_name: String,
	new_name: String,
) -> String:
	var lines := source.split("\n")
	var line_index := line_number - 1
	if line_index < 0 or line_index >= lines.size():
		return source
	var regex := RegEx.new()
	if (
		regex.compile(
			(
				'^(\\s*%s\\s*=\\s*")%s(".*)$'
				% [property_name, old_name.replace("\\", "\\\\").replace('"', '\\"')]
			)
		)
		!= OK
	):
		return source
	var line := String(lines[line_index])
	var match_result := regex.search(line)
	if match_result == null:
		return source
	lines[line_index] = (match_result.get_string(1) + new_name + match_result.get_string(2))
	return "\n".join(lines)


static func _merge_change(
	changes: Dictionary,
	path: String,
	before: String,
	after: String,
	occurrences: int,
) -> void:
	if before == after:
		return
	if changes.has(path):
		var existing: Dictionary = changes[path]
		existing["after"] = after
		existing["occurrences"] = int(existing["occurrences"]) + occurrences
	else:
		changes[path] = {
			"path": path,
			"before": before,
			"after": after,
			"occurrences": occurrences,
		}


static func _save_source(path: String, source: String) -> Error:
	return KonadoScriptAtomicFile.replace_text(path, source)


static func _read_disk_source(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()
