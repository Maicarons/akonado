extends RefCounted
class_name KonadoScriptDiagnostics

var _location_regex := RegEx.new()
var _project_index := KonadoScriptProjectIndex.shared()


func _init() -> void:
	_location_regex.compile("\\[行：(\\d+)(?:, 列：(\\d+))?\\]\\s*(.*)$")


func analyze(source: String, path: String, locale: String = "") -> Array[Dictionary]:
	var compiler := KonadoScriptCompiler.new()
	compiler.set_console_output_enabled(false)
	var analysis := compiler.analyze_string(source, path)
	return analyze_result(source, path, locale, analysis)


func analyze_result(
	source: String,
	path: String,
	locale: String,
	analysis: Dictionary,
	semantic_references: Variant = null,
) -> Array[Dictionary]:
	var diagnostics: Array[Dictionary] = []
	var structured: Array = analysis.get("diagnostics", [])
	if structured.is_empty():
		for error: String in analysis.get("errors", []):
			diagnostics.append(_parse_message(error, "error", locale, source, path))
		for warning: String in analysis.get("warnings", []):
			diagnostics.append(_parse_message(warning, "warning", locale, source, path))
	else:
		for record: Dictionary in structured:
			diagnostics.append(_from_structured(record, locale, source, path))
	# Project-resource checks are independent of syntax/semantic checks. Reporting
	# both in one pass lets an IDE present all actionable problems on the line.
	_append_project_diagnostics(diagnostics, source, path, locale, semantic_references)
	diagnostics.sort_custom(_sort_diagnostics)
	return diagnostics


func _from_structured(
	record: Dictionary,
	locale: String,
	source: String,
	fallback_path: String,
) -> Dictionary:
	var line := maxi(1, int(record.get("line", 1)))
	var column := maxi(1, int(record.get("column", 1)))
	var raw_message := String(record.get("raw_message", record.get("message", "")))
	var description := KonadoScriptDiagnosticMessages.describe(raw_message, locale)
	var end_column := int(record.get("end_column", column + 1))
	if end_column <= column + 1:
		end_column = _infer_end_column(source, line, column)
	return {
		"severity": String(record.get("severity", "error")),
		"stage": String(record.get("stage", "compiler")),
		"line": line,
		"column": column,
		"end_line": maxi(line, int(record.get("end_line", line))),
		"end_column": maxi(column + 1, end_column),
		"code": String(record.get("code", description["code"])),
		"arguments": record.get("arguments", description["arguments"]),
		"message": description["message"],
		"raw_message": raw_message,
		"path": String(record.get("path", fallback_path)),
		"actions": record.get("actions", []),
	}


func _append_project_diagnostics(
	diagnostics: Array[Dictionary],
	source: String,
	path: String,
	locale: String,
	semantic_references: Variant,
) -> void:
	var seen := {}
	var references: Array[Dictionary]
	if semantic_references == null:
		references = KonadoScriptSymbolIndex.get_semantic_references(source)
	else:
		for reference: Dictionary in semantic_references:
			references.append(reference)
	for reference: Dictionary in references:
		if bool(reference.get("optional", false)):
			var optional_definitions := _project_index.get_definitions(
				String(reference.get("kind", "")), String(reference.get("name", ""))
			)
			if optional_definitions.is_empty():
				continue
		var kind := String(reference.get("kind", ""))
		if (
			kind
			not in [
				"actors",
				"backgrounds",
				"background_music_tracks",
				"sfx",
				"voices",
				"states",
				"motions",
				"cameras",
			]
		):
			continue
		var name := String(reference.get("name", ""))
		var definitions: Array[Dictionary]
		if kind in ["states", "motions"]:
			definitions = (
				_project_index
				. get_actor_scoped_targets(
					String(reference.get("scope_name", "")),
					kind,
					name,
				)
			)
		else:
			definitions = _project_index.get_definitions(kind, name)
		var message := ""
		var code := ""
		var actions: Array[Dictionary] = []
		if definitions.is_empty():
			message = "未找到%s '%s'" % [_kind_label(kind), name]
			code = "resource.unknown"
		elif (
			kind in KonadoScriptProjectIndex.DUPLICATE_GLOBAL_KINDS
			and _has_same_owner_duplicate(definitions)
		):
			message = "%s '%s' 存在 %d 个重复定义" % [_kind_label(kind), name, definitions.size()]
			code = "resource.duplicate"
			actions = _definition_actions(definitions)
		else:
			for definition: Dictionary in definitions:
				var target_path := String(definition.get("target_path", ""))
				if (
					target_path.is_empty()
					and (
						kind
						in ["actors", "backgrounds", "background_music_tracks", "sfx", "voices"]
					)
				):
					message = "%s '%s' 未配置目标资源" % [_kind_label(kind), name]
					code = "resource.unassigned"
					actions = _definition_actions([definition])
					break
				if not target_path.is_empty() and not FileAccess.file_exists(target_path):
					message = (
						"%s '%s' 的目标资源不存在：%s"
						% [
							_kind_label(kind),
							name,
							target_path,
						]
					)
					code = "resource.missing_target"
					actions = _definition_actions([definition])
					break
		if message.is_empty():
			continue
		var line := int(reference.get("line", 1))
		var key := "%d:%s" % [line, message]
		if seen.has(key):
			continue
		seen[key] = true
		var start_column := int(reference.get("column", 1))
		var end_column := int(reference.get("end", start_column)) + 1
		(
			diagnostics
			. append(
				{
					"severity": "warning",
					"line": line,
					"column": start_column,
					"end_line": line,
					"end_column": maxi(start_column + 1, end_column),
					"code": code,
					"arguments": [kind, name],
					"message": KonadoScriptDiagnosticMessages.localize(message, locale),
					"raw_message": message,
					"path": path,
					"kind": kind,
					"symbol": name,
					"actions": actions,
				}
			)
		)


func _kind_label(kind: String) -> String:
	return (
		{
			"actors": "角色",
			"backgrounds": "背景",
			"background_music_tracks": "背景音乐",
			"sfx": "音效",
			"voices": "语音",
			"states": "角色状态",
			"motions": "演员动作",
			"cameras": "镜头配置",
		}
		. get(kind, kind)
	)


func _has_same_owner_duplicate(definitions: Array[Dictionary]) -> bool:
	var owners := {}
	for definition: Dictionary in definitions:
		var owner := String(definition.get("owner_path", ""))
		if owners.has(owner):
			return true
		owners[owner] = true
	return false


func _definition_actions(definitions: Array) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	var seen := {}
	for definition: Dictionary in definitions:
		var owner_path := String(definition.get("owner_path", ""))
		if owner_path.is_empty() or not FileAccess.file_exists(owner_path) or seen.has(owner_path):
			continue
		seen[owner_path] = true
		(
			actions
			. append(
				{
					"kind": "open_path",
					"path": owner_path,
					"line": int(definition.get("line", 1)),
				}
			)
		)
	return actions


func _parse_message(
	message: String,
	severity: String,
	locale: String,
	source: String,
	path: String,
) -> Dictionary:
	var result := {
		"severity": severity,
		"line": 1,
		"column": 1,
		"end_line": 1,
		"end_column": 2,
		"code": "compiler.diagnostic",
		"arguments": [],
		"message": message,
		"raw_message": message,
		"path": path,
		"actions": [],
	}
	var match_result := _location_regex.search(message)
	if match_result == null:
		var description := KonadoScriptDiagnosticMessages.describe(message, locale)
		result.merge(description, true)
		result["end_column"] = _infer_end_column(source, 1, 1)
		return result
	result["line"] = maxi(1, int(match_result.get_string(1)))
	if not match_result.get_string(2).is_empty():
		result["column"] = maxi(1, int(match_result.get_string(2)))
	result["end_line"] = result["line"]
	result["end_column"] = _infer_end_column(source, result["line"], result["column"])
	var description := KonadoScriptDiagnosticMessages.describe(match_result.get_string(3), locale)
	result.merge(description, true)
	return result


func _infer_end_column(source: String, line_number: int, start_column: int) -> int:
	var lines := source.split("\n")
	var line_index := line_number - 1
	if line_index < 0 or line_index >= lines.size():
		return start_column + 1
	var line := String(lines[line_index])
	var start := clampi(start_column - 1, 0, line.length())
	if start >= line.length():
		return start_column + 1
	var end := start
	while end < line.length() and line[end] not in [" ", "\t"]:
		end += 1
	return maxi(start_column + 1, end + 1)


func _sort_diagnostics(left: Dictionary, right: Dictionary) -> bool:
	if left["line"] == right["line"]:
		return left["column"] < right["column"]
	return left["line"] < right["line"]
