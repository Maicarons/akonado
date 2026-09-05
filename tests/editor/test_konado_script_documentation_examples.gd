extends SceneTree

const DOC_LOCALES := ["zh", "tc", "en", "ja", "ko"]
const DOC_VERSIONS := ["2.4", "latest"]
const OBSOLETE_LATEST_MARKERS := [
	".godot/export_credentials.cfg",
	"/2.5/",
	"/2.6/",
	"user://saves/",
]

var _failures := 0


func _init() -> void:
	var checked_blocks := 0
	for locale: String in DOC_LOCALES:
		_validate_version_directories(locale)
		var root_path := "res://docs/%s/latest/tutorial/script" % locale
		_validate_latest_markers("res://docs/%s/latest" % locale)
		_validate_latest_license(locale)
		for path: String in _collect_markdown_files(root_path):
			var source := _read_text(path)
			for block: Dictionary in _extract_text_blocks(source):
				var snippet := String(block["source"])
				if not _is_executable_example(snippet):
					continue
				checked_blocks += 1
				_validate_example(path, int(block["line"]), snippet)
	for path: String in _collect_konado_script_files("res://skills/konado-script/examples"):
		checked_blocks += 1
		_validate_example(path, 1, _read_text(path))
	if checked_blocks == 0:
		_fail("no executable KonadoScript documentation examples were found")
	elif _failures == 0:
		print("PASS: %d KonadoScript documentation examples" % checked_blocks)
	quit(_failures)


func _validate_version_directories(locale: String) -> void:
	var actual := PackedStringArray()
	for directory_name: String in DirAccess.get_directories_at("res://docs/%s" % locale):
		actual.append(directory_name)
	actual.sort()
	var expected := PackedStringArray(DOC_VERSIONS)
	expected.sort()
	if actual != expected:
		_fail(
			(
				"docs/%s must contain only the 2.4 LTS and latest documentation: found %s"
				% [locale, ", ".join(actual)]
			)
		)


func _validate_latest_markers(root_path: String) -> void:
	for path: String in _collect_markdown_files(root_path):
		var source := _read_text(path)
		for marker: String in OBSOLETE_LATEST_MARKERS:
			if marker in source:
				_fail("%s contains obsolete latest-documentation marker: %s" % [path, marker])


func _validate_latest_license(locale: String) -> void:
	var path := "res://docs/%s/latest/introduction/license.md" % locale
	var source := _read_text(path)
	for license_path: String in ["/LICENSE)", "/LICENSE-BSD)", "/LICENSE-MULANPSL)"]:
		if license_path not in source:
			_fail("%s does not document the current multi-license option %s" % [path, license_path])


func _collect_markdown_files(root_path: String) -> PackedStringArray:
	var result := PackedStringArray()
	for file_name: String in DirAccess.get_files_at(root_path):
		if file_name.get_extension().to_lower() == "md":
			result.append(root_path.path_join(file_name))
	for directory_name: String in DirAccess.get_directories_at(root_path):
		result.append_array(_collect_markdown_files(root_path.path_join(directory_name)))
	result.sort()
	return result


func _collect_konado_script_files(root_path: String) -> PackedStringArray:
	var result := PackedStringArray()
	for file_name: String in DirAccess.get_files_at(root_path):
		if file_name.get_extension().to_lower() == "ks":
			result.append(root_path.path_join(file_name))
	for directory_name: String in DirAccess.get_directories_at(root_path):
		result.append_array(_collect_konado_script_files(root_path.path_join(directory_name)))
	result.sort()
	return result


func _extract_text_blocks(markdown: String) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	var lines := markdown.split("\n")
	var inside_text_block := false
	var block_start := 0
	var block_lines := PackedStringArray()
	for line_index: int in lines.size():
		var line := String(lines[line_index])
		if not inside_text_block and line.strip_edges() in ["```", "```text", "```konadoscript"]:
			inside_text_block = true
			block_start = line_index + 2
			block_lines.clear()
			continue
		if inside_text_block and line.strip_edges() == "```":
			blocks.append({"line": block_start, "source": "\n".join(block_lines)})
			inside_text_block = false
			continue
		if inside_text_block:
			block_lines.append(line)
	return blocks


func _is_executable_example(source: String) -> bool:
	if "<" in source or "[" in source or "..." in source or "…" in source:
		return false
	for line: String in source.split("\n"):
		var content := line.strip_edges()
		if content.is_empty() or content.begins_with("#"):
			continue
		if content.begins_with('"'):
			return true
		return content.get_slice(" ", 0) in KonadoScriptLanguageCatalog.ROOT_KEYWORDS
	return false


func _validate_example(path: String, line: int, source: String) -> void:
	var lexer := KonadoScriptLexer.new()
	var parser := KonadoScriptParser.new()
	lexer.console_output_enabled = false
	parser.console_output_enabled = false
	var tokens := lexer.tokenize(source, path)
	var ast := parser.parse(tokens, path)
	if ast != null and lexer.get_errors().is_empty() and parser.get_errors().is_empty():
		return
	_fail(
		(
			"%s:%d contains an invalid KonadoScript example: %s"
			% [
				path,
				line,
				"\n".join(PackedStringArray(lexer.get_errors() + parser.get_errors())),
			]
		)
	)


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else file.get_as_text()


func _fail(message: String) -> void:
	_failures += 1
	push_error("FAIL: %s" % message)
