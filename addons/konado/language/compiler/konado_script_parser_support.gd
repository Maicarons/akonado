extends "res://addons/konado/language/compiler/konado_script_parser_context.gd"

## Shared parsing primitives for blocks, literal values, and named parameters.
## Statement parsing remains in KonadoScriptParser; this class keeps the parser
## focused without exposing implementation details as a second public API.

const MAX_BLOCK_DEPTH := 128

var _block_depth := 0


func _validate_camera_values(
	action: String,
	tween_type: String,
	tween_time: float,
	shake_time: float,
) -> bool:
	if (
		not tween_type.is_empty()
		and tween_type not in KonadoScriptLanguageCatalog.CAMERA_TRANSITIONS
	):
		_error("镜头过渡类型无效：%s" % tween_type)
		return false
	if action in ["move", "reset"] and tween_time < 0.0:
		_error("镜头过渡时长不能为负数")
		return false
	if action == "shake" and shake_time < 0.0:
		_error("镜头震动时长不能为负数")
		return false
	return true


func _parse_named_parameters(node: KonadoScriptSyntaxTree.ASTNode) -> bool:
	while _check(KonadoScriptToken.Type.LBRACKET):
		_advance()
		var name_token := _expect(KonadoScriptToken.Type.IDENTIFIER)
		if name_token == null:
			return false
		var name := String(name_token.value)
		if node.parameters.has(name):
			_error("命名参数 '%s' 重复" % name)
			return false
		if _expect(KonadoScriptToken.Type.OP_ASSIGN) == null:
			_error("命名参数 '%s' 缺少 =" % name)
			return false
		var value_token := _peek()
		if (
			value_token.type
			in [
				KonadoScriptToken.Type.NEWLINE,
				KonadoScriptToken.Type.EOF,
				KonadoScriptToken.Type.LBRACKET,
				KonadoScriptToken.Type.RBRACKET,
				KonadoScriptToken.Type.OP_ASSIGN,
			]
		):
			_error("命名参数 '%s' 缺少有效值" % name)
			return false
		_advance()
		if _expect(KonadoScriptToken.Type.RBRACKET) == null:
			_error("命名参数 '%s' 缺少 ]" % name)
			return false
		node.parameters[name] = _literal_value(value_token)
	return true


func _literal_value(token: KonadoScriptToken) -> Variant:
	if token.type == KonadoScriptToken.Type.NUMBER_LITERAL:
		var number_text := String(token.value)
		return number_text.to_int() if number_text.is_valid_int() else number_text.to_float()
	if token.type == KonadoScriptToken.Type.VARIABLE_REF:
		return {
			"kind": "variable",
			"name": String(token.value.name),
			"persistent": String(token.value.prefix) == "%",
		}
	var text := String(token.value)
	if token.type == KonadoScriptToken.Type.IDENTIFIER and text.to_lower() in ["true", "false"]:
		return text.to_lower() == "true"
	return text


func _parse_indented_block(owner: String, parse_statement: Callable) -> Array:
	var statements: Array = []
	if _block_depth >= MAX_BLOCK_DEPTH:
		_error("嵌套深度超过 128 层安全上限")
		return statements
	_skip_newlines()
	if not _check(KonadoScriptToken.Type.INDENT):
		_error("%s 内容必须缩进一级" % owner)
		return statements
	_advance()
	_block_depth += 1

	while not _at_end():
		_skip_newlines()
		if _at_end():
			break
		if _check(KonadoScriptToken.Type.DEDENT):
			_advance()
			break

		var position_before_statement := _pos
		var statement: KonadoScriptSyntaxTree.ASTNode = parse_statement.call()
		if not _errors.is_empty():
			break
		if statement != null:
			statements.append(statement)
		if _pos <= position_before_statement:
			_error("解析器未能消费当前语句")
			_skip_to_next_line()
			break

	_block_depth -= 1
	return statements


func _parse_condition_block(parse_statement: Callable) -> Array:
	return _parse_indented_block("条件块", parse_statement)
