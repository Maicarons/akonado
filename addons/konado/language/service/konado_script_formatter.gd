@tool
extends RefCounted
class_name KonadoScriptFormatter

## Deterministic KonadoScript formatter that never rewrites string or comment text.


static func format_document(source: String, indent_unit: String = "") -> String:
	return format_range(source, 0, maxi(0, source.split("\n").size() - 1), indent_unit)


static func format_range(
	source: String,
	from_line: int,
	to_line: int,
	indent_unit: String = "",
) -> String:
	var lines := source.split("\n")
	if lines.is_empty():
		return source
	indent_unit = _resolve_indent_unit(lines, indent_unit)
	var first := clampi(from_line, 0, lines.size() - 1)
	var last := clampi(to_line, first, lines.size() - 1)
	var depth := 0
	for line_index: int in lines.size():
		var raw_line := String(lines[line_index]).trim_suffix("\r").strip_edges(false, true)
		var content := raw_line.strip_edges(true, false)
		var structural := _strip_comment(content).strip_edges()
		if _closes_block(structural):
			depth = maxi(0, depth - 1)
		if line_index >= first and line_index <= last and not content.is_empty():
			lines[line_index] = indent_unit.repeat(depth) + _normalize_spacing(content)
		elif line_index >= first and line_index <= last:
			lines[line_index] = ""
		if _opens_block(structural):
			depth += 1
	return "\n".join(lines)


static func _normalize_spacing(content: String) -> String:
	var output := ""
	var inside_string := false
	var escaped := false
	var pending_space := false
	for index: int in content.length():
		var character := content.substr(index, 1)
		if escaped:
			output += character
			escaped = false
			continue
		if inside_string and character == "\\":
			output += character
			escaped = true
			continue
		if character == '"':
			if pending_space and not output.is_empty():
				output += " "
			pending_space = false
			inside_string = not inside_string
			output += character
			continue
		if not inside_string and character == "#":
			if not output.is_empty() and not output.ends_with(" "):
				output += " "
			output += content.substr(index)
			return output.strip_edges(false, true)
		if not inside_string and character in [" ", "\t"]:
			pending_space = true
			continue
		if pending_space and not output.is_empty():
			output += " "
		pending_space = false
		output += character
	return output.strip_edges(false, true)


static func _opens_block(content: String) -> bool:
	return (
		(content.begins_with("if ") and content.ends_with(":"))
		or content == "else:"
		or (content.begins_with("screentext") and content.ends_with("{"))
	)


static func _closes_block(content: String) -> bool:
	return content in ["endif", "else:", "}"] or content.begins_with("} [")


static func _strip_comment(line: String) -> String:
	var inside_string := false
	var escaped := false
	for index: int in line.length():
		var character := line.substr(index, 1)
		if escaped:
			escaped = false
		elif character == "\\" and inside_string:
			escaped = true
		elif character == '"':
			inside_string = not inside_string
		elif character == "#" and not inside_string:
			return line.left(index)
	return line


static func _resolve_indent_unit(lines: PackedStringArray, requested: String) -> String:
	if not requested.is_empty():
		return requested
	var minimum_spaces := 0
	for line: String in lines:
		if line.begins_with("\t"):
			return "\t"
		var spaces := line.length() - line.strip_edges(true, false).length()
		if spaces > 0 and (minimum_spaces == 0 or spaces < minimum_spaces):
			minimum_spaces = spaces
	if minimum_spaces > 0:
		return " ".repeat(minimum_spaces)
	if Engine.is_editor_hint():
		var settings := EditorInterface.get_editor_settings()
		if settings != null:
			var indent_type := int(settings.get_setting("text_editor/behavior/indent/type"))
			var indent_size := int(settings.get_setting("text_editor/behavior/indent/size"))
			return "\t" if indent_type == 0 else " ".repeat(maxi(1, indent_size))
	return "\t"
