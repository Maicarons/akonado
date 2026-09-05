extends RefCounted

## Shared token cursor and diagnostic context for the KonadoScript parser.
##
## Keeping stream traversal here lets KonadoScriptParser focus on grammar rules while
## preserving a single source of truth for position tracking and error output.

const MAX_DIAGNOSTICS := 256

var console_output_enabled := true
var _tokens: Variant = []
var _pos: int = 0
var _cached_token: KonadoScriptToken
var _cached_token_position := -1
var _path: String = ""
var _errors: Array[String] = []
var _diagnostics: Array[Dictionary] = []
var _last_error_line := 0


func release_token_stream() -> void:
	_tokens.clear()
	_tokens = []
	_pos = 0
	_cached_token = null
	_cached_token_position = -1


func _token_count() -> int:
	return _tokens.size()


func _token_type_at(index: int) -> int:
	if not _tokens is Array:
		return int(_tokens.call("type_at", index))
	return (
		_tokens[index].type if index >= 0 and index < _tokens.size() else KonadoScriptToken.Type.EOF
	)


func _token_at(index: int) -> KonadoScriptToken:
	if not _tokens is Array:
		return _tokens.call("token_at", index) as KonadoScriptToken
	if index >= 0 and index < _tokens.size():
		return _tokens[index]
	return KonadoScriptToken.new(KonadoScriptToken.Type.EOF, "", 0, 0)


## 查看当前 Token（不消费）
func _peek() -> KonadoScriptToken:
	if _cached_token_position != _pos:
		_cached_token = _token_at(_pos)
		_cached_token_position = _pos
	return _cached_token


## 消费并返回当前 Token
func _advance() -> KonadoScriptToken:
	var tok := _peek()
	if _pos < _token_count():
		_pos += 1
		_cached_token_position = -1
	return tok


## 检查当前 Token 类型
func _check(type: KonadoScriptToken.Type) -> bool:
	return _peek().type == type


## 期望指定类型的 Token，否则报错
func _expect(type: KonadoScriptToken.Type) -> KonadoScriptToken:
	if _check(type):
		return _advance()
	_error("期望 %s，实际为 %s" % [KonadoScriptToken.Type.keys()[type], str(_peek())])
	return null


## 期望任意值 Token（STRING_LITERAL / NUMBER_LITERAL / IDENTIFIER / VARIABLE_REF / 关键字）
func _expect_any_value() -> KonadoScriptToken:
	var tok := _peek()
	if tok.type == KonadoScriptToken.Type.NEWLINE or tok.type == KonadoScriptToken.Type.EOF:
		return null
	return _advance()


## 是否在行末（NEWLINE 或 EOF）
func _at_line_end() -> bool:
	var tok := _peek()
	return tok.type == KonadoScriptToken.Type.NEWLINE or tok.type == KonadoScriptToken.Type.EOF


## 跳过所有 NEWLINE
func _skip_newlines() -> void:
	while _pos < _token_count() and _token_type_at(_pos) == KonadoScriptToken.Type.NEWLINE:
		_pos += 1
	_cached_token_position = -1


## 跳到下一行（消费到 NEWLINE 或 EOF）
func _skip_to_next_line() -> void:
	while _pos < _token_count():
		if _token_type_at(_pos) == KonadoScriptToken.Type.NEWLINE:
			_pos += 1
			_cached_token_position = -1
			return
		if _token_type_at(_pos) == KonadoScriptToken.Type.EOF:
			return
		_pos += 1
	_cached_token_position = -1


## 拒绝固定语法语句后的多余参数，并始终恢复到下一行。
func _finish_statement_line(trailing_message: String) -> bool:
	if not _at_line_end():
		_error(trailing_message)
		_skip_to_next_line()
		return false
	_skip_to_next_line()
	return true


func _skip_screen_text_remainder() -> void:
	while not _at_end():
		if _check(KonadoScriptToken.Type.INDENT) or _check(KonadoScriptToken.Type.DEDENT):
			_advance()
		if _check(KonadoScriptToken.Type.RBRACE):
			_advance()
			_skip_to_next_line()
			return
		_skip_to_next_line()


func _skip_condition_remainder() -> void:
	var depth := 1
	while not _at_end():
		if _check_keyword_on_line(KonadoScriptToken.Type.KW_IF):
			depth += 1
		elif _check_keyword_on_line(KonadoScriptToken.Type.KW_ENDIF):
			depth -= 1
			_skip_to_next_line()
			if depth == 0:
				return
			continue
		_skip_to_next_line()


## 是否到达 Token 流末尾
func _at_end() -> bool:
	return _pos >= _token_count() or _peek().type == KonadoScriptToken.Type.EOF


## 检查当前逻辑行是否以指定关键字开头。缩进 Token 仅在错误恢复时
## 可能残留在游标前，因此这里跨过所有层级边界。
func _check_keyword_on_line(kw: KonadoScriptToken.Type) -> bool:
	var look := _pos
	while (
		look < _token_count()
		and _token_type_at(look) in [KonadoScriptToken.Type.INDENT, KonadoScriptToken.Type.DEDENT]
	):
		look += 1
	return look < _token_count() and _token_type_at(look) == kw


## 跳过到指定关键字之后（含行末 NEWLINE）
func _skip_past_keyword(kw: KonadoScriptToken.Type) -> void:
	while _check(KonadoScriptToken.Type.INDENT) or _check(KonadoScriptToken.Type.DEDENT):
		_advance()
	if _check(kw):
		_advance()
	if _check(KonadoScriptToken.Type.COLON):
		_advance()
	_skip_to_next_line()


## 消费块头的必需冒号，并拒绝冒号后的尾随内容。
func _consume_required_colon_line(missing_message: String, trailing_message: String) -> bool:
	if not _check(KonadoScriptToken.Type.COLON):
		_error(missing_message)
		return false
	_advance()
	if not _at_line_end():
		_error(trailing_message)
		return false
	_skip_to_next_line()
	return true


## 消费 else/endif 等块关键字所在行，并严格检查冒号及尾随内容。
func _consume_keyword_line(
	keyword: KonadoScriptToken.Type,
	require_colon: bool,
	missing_colon_message: String,
	trailing_message: String,
) -> bool:
	while _check(KonadoScriptToken.Type.INDENT) or _check(KonadoScriptToken.Type.DEDENT):
		_advance()
	if not _check(keyword):
		return false
	var keyword_token := _advance()
	var has_colon := str(keyword_token.value).ends_with(":")
	if require_colon and not has_colon and _check(KonadoScriptToken.Type.COLON):
		_advance()
		has_colon = true
	if require_colon and not has_colon:
		_error(missing_colon_message)
		return false
	if not _at_line_end():
		_error(trailing_message)
		return false
	_skip_to_next_line()
	return true


## 错误记录
func _error(msg: String) -> void:
	var token := _peek()
	_error_at(token.line, msg, token.column)


## 在指定源码行记录错误，用于文件结尾处发现的未闭合结构。
func _error_at(line_num: int, msg: String, column: int = 0) -> void:
	if _errors.size() >= MAX_DIAGNOSTICS:
		return
	_last_error_line = line_num
	var location := "[行：%d]" % line_num
	if column > 0:
		location = "[行：%d, 列：%d]" % [line_num, column]
	var err := "语法错误：%s %s %s" % [_path, location, msg]
	_errors.append(err)
	var description := KonadoScriptDiagnosticMessages.describe(msg, "zh_CN")
	(
		_diagnostics
		. append(
			{
				"severity": "error",
				"stage": "parser",
				"path": _path,
				"line": maxi(1, line_num),
				"column": maxi(1, column),
				"end_line": maxi(1, line_num),
				"end_column": maxi(2, column + 1),
				"code": description["code"],
				"arguments": description["arguments"],
				"raw_message": msg,
			}
		)
	)
	if console_output_enabled:
		push_error(err)


func get_diagnostics() -> Array[Dictionary]:
	return _diagnostics
