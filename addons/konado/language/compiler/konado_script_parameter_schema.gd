extends RefCounted
class_name KonadoScriptParameterSchema

## Validates named parameters exclusively from KonadoScriptCommandRegistry.


static func validate(node: KonadoScriptSyntaxTree.ASTNode) -> Array[String]:
	var errors: Array[String] = []
	var command := KonadoScriptCommandRegistry.command_for_node(node)
	if command.is_empty() and node is KonadoScriptSyntaxTree.BranchNode:
		return errors
	if command.is_empty() or not KonadoScriptCommandRegistry.COMMANDS.has(command):
		errors.append("指令没有注册的语义契约")
		return errors
	var allowed := KonadoScriptCommandRegistry.parameters_for_node(node)
	for name: String in node.parameters:
		if not allowed.has(name):
			errors.append("参数 '%s' 不适用于当前指令" % name)
			continue
		_validate_value(name, node.parameters[name], allowed[name], errors)
	if node.parameters.has("speed") and node.parameters.has("interval"):
		errors.append("speed 与 interval 不能同时设置")
	if node is KonadoScriptSyntaxTree.CameraNode or node is KonadoScriptSyntaxTree.AsyncCamNode:
		if node.parameters.has("duration"):
			var positional: float = (
				node.tween_time if node.action in ["move", "reset"] else node.shake_time
			)
			if positional > 0.0:
				errors.append("镜头时长不能同时使用位置参数和 [duration=...] 设置")
	return errors


static func _validate_value(
	name: String, value: Variant, definition: Dictionary, errors: Array[String]
) -> void:
	match String(definition.get("type", "")):
		"number":
			if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
				errors.append("参数 '%s' 必须是数字" % name)
				return
			var number := float(value)
			if definition.has("min") and number < float(definition["min"]):
				errors.append("参数 '%s' 不能小于 %s" % [name, definition["min"]])
			if definition.has("min_exclusive") and number <= float(definition["min_exclusive"]):
				errors.append("参数 '%s' 必须大于 %s" % [name, definition["min_exclusive"]])
		"identifier":
			if typeof(value) != TYPE_STRING or not String(value).is_valid_identifier():
				errors.append("参数 '%s' 必须是有效标识符" % name)
