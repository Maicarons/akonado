extends RefCounted
class_name KonadoScriptSemanticAnalyzer

## AST contract analyzer. Executable control-flow semantics are owned exclusively
## by KonadoScriptProgramAnalyzer after lowering, so the compiler has one CFG model.

const MAX_CONTROL_FLOW_STEPS := 500_000
const MAX_DIAGNOSTICS := 256

var console_output_enabled := true
var _errors: Array[String] = []
var _warnings: Array[String] = []
var _diagnostics: Array[Dictionary] = []
var _branch_ids: Array[String] = []
var _branch_nodes: Dictionary = {}
var _dependent_characters: Array[String] = []
var _dependent_character_set: Dictionary = {}
var _dependencies: Dictionary = {}
var _path := ""
var _analysis_steps := 0
var _stable_ids: Dictionary = {}


func get_errors() -> Array[String]:
	return _errors


func get_warnings() -> Array[String]:
	return _warnings


func get_diagnostics() -> Array[Dictionary]:
	return _diagnostics


func get_dependent_characters() -> Array[String]:
	return _dependent_characters.duplicate()


func get_dependencies() -> Dictionary:
	var result := {}
	for kind: String in _dependencies:
		var values: Array = _dependencies[kind].keys()
		values.sort()
		result[kind] = values
	return result


func release_syntax_tree() -> void:
	_branch_nodes.clear()
	_stable_ids.clear()


func analyze(script: KonadoScriptSyntaxTree.ScriptNode, path: String = "") -> bool:
	_errors.clear()
	_warnings.clear()
	_diagnostics.clear()
	_branch_ids.clear()
	_branch_nodes.clear()
	_dependent_characters.clear()
	_dependent_character_set.clear()
	_dependencies = {
		"actors": {},
		"backgrounds": {},
		"bgm": {},
		"sfx": {},
		"voices": {},
		"cameras": {},
		"scripts": {},
	}
	_analysis_steps = 0
	_stable_ids.clear()
	_path = path

	_collect_metadata(script.statements, true)
	_validate_all_statements(script.statements)
	return _errors.is_empty()


func _validate_all_statements(root: Array) -> void:
	var stack: Array = [root]
	while not stack.is_empty():
		if _errors.size() >= MAX_DIAGNOSTICS:
			return
		var statements: Array = stack.pop_back()
		for statement in statements:
			_analysis_steps += 1
			if _analysis_steps > MAX_CONTROL_FLOW_STEPS:
				_error(statement.line, "语义分析超过安全预算，请拆分剧本")
				return
			if statement is KonadoScriptSyntaxTree.BackgroundNode:
				_validate_background(statement)
			elif statement is KonadoScriptSyntaxTree.ChoiceGroupNode:
				if statement.options.is_empty():
					_error(statement.line, "选项行没有有效的选项")
				for option in statement.options:
					if not _branch_nodes.has(option.branch_target):
						_error(
							statement.line,
							"跳转标签 '%s' 不存在（当前可选标签：%s）" % [option.branch_target, str(_branch_ids)]
						)
			elif (
				statement is KonadoScriptSyntaxTree.JumpBranchNode
				and not _branch_nodes.has(statement.target_branch)
			):
				_error(statement.line, "jump_branch 目标分支 '%s' 未找到" % statement.target_branch)
			elif (
				statement is KonadoScriptSyntaxTree.SignalNode
				and statement.signal_content.is_empty()
			):
				_error(statement.line, "信号指令内容为空")
			elif (
				statement is KonadoScriptSyntaxTree.AchievementNode
				and statement.target_id.is_empty()
			):
				_error(statement.line, "achievement 目标ID为空")
			elif statement is KonadoScriptSyntaxTree.JumpNode:
				_validate_script_jump(statement)
			if statement is KonadoScriptSyntaxTree.BranchNode:
				stack.append(statement.body)
			elif statement is KonadoScriptSyntaxTree.IfElseNode:
				stack.append(statement.if_body)
				stack.append(statement.else_body)


func _collect_metadata(statements: Array, top_level: bool = false) -> void:
	for statement in statements:
		if _errors.size() >= MAX_DIAGNOSTICS:
			return
		for parameter_error: String in KonadoScriptParameterSchema.validate(statement):
			_error(statement.line, parameter_error)
		if statement.parameters.has("id"):
			var stable_id := String(statement.parameters["id"])
			if _stable_ids.has(stable_id):
				_error(
					statement.line,
					"指令 ID '%s' 重复（首次出现在第 %d 行）" % [stable_id, int(_stable_ids[stable_id])]
				)
			else:
				_stable_ids[stable_id] = statement.line
		if statement is KonadoScriptSyntaxTree.ActorNode and statement.action == "show":
			if not _dependent_character_set.has(statement.actor_name):
				_dependent_characters.append(statement.actor_name)
				_dependent_character_set[statement.actor_name] = true
			_add_dependency("actors", statement.actor_name)
		elif statement is KonadoScriptSyntaxTree.BackgroundNode:
			_add_dependency("backgrounds", statement.background_name)
		elif statement is KonadoScriptSyntaxTree.AudioNode:
			if statement.action == "play":
				_add_dependency(statement.target, statement.resource_name)
		elif statement is KonadoScriptSyntaxTree.DialogueNode:
			if statement.speaker_kind == KonadoScriptSyntaxTree.DialogueNode.SpeakerKind.ACTOR:
				if not _dependent_character_set.has(statement.speaker):
					_dependent_characters.append(statement.speaker)
					_dependent_character_set[statement.speaker] = true
				_add_dependency("actors", statement.speaker)
			_add_dependency("voices", statement.voice_id)
		elif (
			statement is KonadoScriptSyntaxTree.CameraNode
			or statement is KonadoScriptSyntaxTree.AsyncCamNode
		):
			_add_dependency("cameras", statement.target_cam)
		elif statement is KonadoScriptSyntaxTree.JumpNode:
			_add_dependency("scripts", statement.target_path)
		elif statement is KonadoScriptSyntaxTree.BranchNode:
			if not top_level:
				_error(statement.line, "branch 只能在脚本顶层声明")
				continue
			if _branch_nodes.has(statement.branch_id):
				_error(statement.line, "branch 标签 '%s' 重复" % statement.branch_id)
				continue
			_branch_ids.append(statement.branch_id)
			_branch_nodes[statement.branch_id] = statement
			if statement.body.is_empty():
				_error(statement.line, "branch 标签 '%s' 没有可执行内容" % statement.branch_id)
			_collect_metadata(statement.body)
		elif statement is KonadoScriptSyntaxTree.IfElseNode:
			_collect_metadata(statement.if_body)
			_collect_metadata(statement.else_body)


func _add_dependency(kind: String, value: String) -> void:
	if value.is_empty() or not _dependencies.has(kind):
		return
	_dependencies[kind][value] = true


func _validate_background(node: KonadoScriptSyntaxTree.BackgroundNode) -> void:
	if not KonadoScriptProgramEmitter.BACKGROUND_EFFECTS_MAP.has(node.effect):
		_error(node.line, "背景过渡效果 '%s' 不存在" % node.effect)


func _validate_script_jump(node: KonadoScriptSyntaxTree.JumpNode) -> void:
	if not FileAccess.file_exists(node.target_path):
		_error(node.line, "jump 目标剧本 '%s' 不存在" % node.target_path)


func _error(line_num: int, message: String) -> void:
	if _errors.size() >= MAX_DIAGNOSTICS:
		return
	var error := "错误：%s [行：%d] %s" % [_path, line_num, message]
	if _errors.has(error):
		return
	_errors.append(error)
	_append_diagnostic("error", line_num, message)
	if console_output_enabled:
		push_error(error)


func _warning(line_num: int, message: String) -> void:
	if _warnings.size() >= MAX_DIAGNOSTICS:
		return
	var warning := "警告：%s [行：%d] %s" % [_path, line_num, message]
	if _warnings.has(warning):
		return
	_warnings.append(warning)
	_append_diagnostic("warning", line_num, message)
	if console_output_enabled:
		push_warning(warning)


func _append_diagnostic(severity: String, line_num: int, message: String) -> void:
	var description := KonadoScriptDiagnosticMessages.describe(message, "zh_CN")
	(
		_diagnostics
		. append(
			{
				"severity": severity,
				"stage": "analyzer",
				"path": _path,
				"line": maxi(1, line_num),
				"column": 1,
				"end_line": maxi(1, line_num),
				"end_column": 2,
				"code": description["code"],
				"arguments": description["arguments"],
				"raw_message": message,
			}
		)
	)
