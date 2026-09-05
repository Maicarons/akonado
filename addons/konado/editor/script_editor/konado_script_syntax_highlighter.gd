@tool
extends EditorSyntaxHighlighter
class_name KonadoScriptSyntaxHighlighter

## KonadoScript 语法高亮器。
##
## 关键字来自 KonadoScriptLanguageCatalog，正则表达式仅编译一次。字符串和注释
## 使用轻量词法扫描处理，避免注释标记覆盖字符串内容。每行最终只输出
## 颜色发生变化的位置，避免为每个字符创建高亮字典项。

const ROOT_COLOR := Color(0.85, 0.6, 1.0)
const SUBCOMMAND_COLOR := Color(0.95, 0.7, 0.8)
const STRING_COLOR := Color(0.405, 0.842, 0.512)
const NUMBER_COLOR := Color(0.55, 0.78, 1.0)
const VARIABLE_COLOR := Color(0.96, 0.76, 0.38)
const OPERATOR_COLOR := Color(0.75, 0.75, 0.75)
const COMMENT_COLOR := Color(0.5, 0.5, 0.5, 0.8)

var _compiled_rules: Array[Dictionary] = []
var _named_parameter_regex := RegEx.new()


func _create() -> EditorSyntaxHighlighter:
	return KonadoScriptSyntaxHighlighter.new()


func _get_name() -> String:
	return "KonadoScript"


func _get_supported_languages() -> PackedStringArray:
	return PackedStringArray(["KonadoScript"])


func _get_line_syntax_highlighting(line: int) -> Dictionary:
	_ensure_rules()
	var text_edit := get_text_edit()
	if text_edit == null:
		return {}

	var line_text := text_edit.get_line(line)
	if line_text.is_empty():
		return {}

	var default_color := text_edit.get_theme_color("font_color")
	return _highlight_line_text(line_text, default_color)


func _highlight_line_text(line_text: String, default_color: Color) -> Dictionary:
	_ensure_rules()
	var column_colors: Array[Color] = []
	column_colors.resize(line_text.length())
	column_colors.fill(default_color)

	for rule: Dictionary in _compiled_rules:
		var regex: RegEx = rule["regex"]
		for match_result: RegExMatch in regex.search_all(line_text):
			for column: int in range(match_result.get_start(), match_result.get_end()):
				column_colors[column] = rule["color"]

	_apply_named_parameter_colors(line_text, column_colors)
	_apply_string_and_comment_colors(line_text, column_colors)
	_apply_dialogue_variable_colors(line_text, column_colors)

	var highlighting := {}
	var previous_color := default_color
	for column: int in range(column_colors.size()):
		var color := column_colors[column]
		if color != previous_color:
			highlighting[column] = {"color": color}
			previous_color = color
	if previous_color != default_color:
		highlighting[line_text.length()] = {"color": default_color}
	return highlighting


func _ensure_rules() -> void:
	if not _compiled_rules.is_empty():
		return

	var root_keywords := "|".join(KonadoScriptLanguageCatalog.ROOT_KEYWORDS)
	var subcommands := PackedStringArray()
	for root_keyword: String in KonadoScriptLanguageCatalog.CONTEXT_COMPLETIONS:
		for keyword: String in KonadoScriptLanguageCatalog.CONTEXT_COMPLETIONS[root_keyword]:
			if not subcommands.has(keyword):
				subcommands.append(keyword)

	_add_rule("\\b(%s)\\b" % root_keywords, ROOT_COLOR)
	_add_rule("\\b(%s)\\b" % "|".join(subcommands), SUBCOMMAND_COLOR)
	_add_rule(
		"\\b(%s)\\b" % "|".join(KonadoScriptLanguageCatalog.STRUCTURAL_KEYWORDS), OPERATOR_COLOR
	)
	_add_rule("(%|\\$)[\\p{L}_][\\p{L}\\p{N}_-]*", VARIABLE_COLOR)
	_add_rule("(?<![\\p{L}\\p{N}_])-?\\d+(?:\\.\\d+)?", NUMBER_COLOR)
	_add_rule("(==|!=|>=|<=|->|=|>|<|:|\\{|\\}|\\[|\\])", OPERATOR_COLOR)
	var parameter_error := _named_parameter_regex.compile(
		"\\[\\s*([\\p{L}_][\\p{L}\\p{N}_-]*)\\s*="
	)
	if parameter_error != OK:
		push_error("KonadoScript 命名参数高亮规则无效")


func _apply_named_parameter_colors(line_text: String, column_colors: Array[Color]) -> void:
	if not _named_parameter_regex.is_valid():
		return
	for match_result: RegExMatch in _named_parameter_regex.search_all(line_text):
		for column: int in range(match_result.get_start(1), match_result.get_end(1)):
			column_colors[column] = SUBCOMMAND_COLOR


func _apply_string_and_comment_colors(line_text: String, column_colors: Array[Color]) -> void:
	var column := 0
	var inside_string := false
	while column < line_text.length():
		var character := line_text.substr(column, 1)
		if inside_string:
			column_colors[column] = STRING_COLOR
			if character == "\\" and column + 1 < line_text.length():
				if line_text.substr(column + 1, 1) == '"':
					column += 1
					column_colors[column] = STRING_COLOR
			elif character == '"':
				inside_string = false
		elif character == '"':
			inside_string = true
			column_colors[column] = STRING_COLOR
		elif character == "#":
			for comment_column: int in range(column, line_text.length()):
				column_colors[comment_column] = COMMENT_COLOR
			return
		column += 1


func _apply_dialogue_variable_colors(line_text: String, column_colors: Array[Color]) -> void:
	for reference: Dictionary in KonadoScriptSymbolIndex.get_dialogue_variable_references(
		line_text
	):
		for column: int in range(int(reference["start"]), int(reference["end"])):
			if column >= 0 and column < column_colors.size():
				column_colors[column] = VARIABLE_COLOR


func _add_rule(pattern: String, color: Color) -> void:
	var regex := RegEx.new()
	var error := regex.compile(pattern)
	if error != OK:
		push_error("KonadoScript 高亮规则无效：%s" % pattern)
		return
	_compiled_rules.append({"regex": regex, "color": color})


func get_compiled_rule_count() -> int:
	_ensure_rules()
	return _compiled_rules.size()


func _clear_highlighting_cache() -> void:
	pass


func _update_cache() -> void:
	_ensure_rules()
