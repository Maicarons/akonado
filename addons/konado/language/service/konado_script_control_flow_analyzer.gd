@tool
extends RefCounted
class_name KonadoScriptControlFlowAnalyzer

## Reports local branch-control-flow problems for one semantic document.


static func analyze(document: KonadoScriptDocument, locale: String = "") -> Array[Dictionary]:
	var incoming := {}
	var diagnostics: Array[Dictionary] = []
	for reference: Dictionary in document.references:
		if reference.get("kind") != "branches" or reference.get("role") != "reference":
			continue
		var target := String(reference.get("name", ""))
		incoming[target] = int(incoming.get(target, 0)) + 1
		if document.branch_definitions.has(target):
			continue
		var line := int(reference.get("line", 1))
		var column := int(reference.get("column", 1))
		(
			diagnostics
			. append(
				{
					"severity": "error",
					"line": line,
					"column": column,
					"end_line": line,
					"end_column": int(reference.get("end", column)) + 1,
					"path": document.path,
					"code": "missing_branch",
					"arguments": [target],
					"symbol": target,
					"actions": [],
					"message":
					(
						KonadoScriptEditorLocale
						. text(
							"Branch '%s' does not exist." % target,
							"分支“%s”不存在。" % target,
							locale,
						)
					),
				}
			)
		)
	for branch_name: String in document.branch_definitions:
		if incoming.has(branch_name):
			continue
		var definition_line := int(document.branch_definitions[branch_name])
		var reference := _find_branch_reference(
			document, definition_line, branch_name, "definition"
		)
		var column := int(reference.get("column", 1))
		(
			diagnostics
			. append(
				{
					"severity": "warning",
					"line": definition_line,
					"column": column,
					"end_line": definition_line,
					"end_column": int(reference.get("end", column)) + 1,
					"path": document.path,
					"code": "unreachable_branch",
					"arguments": [branch_name],
					"symbol": branch_name,
					"actions": [],
					"message":
					(
						KonadoScriptEditorLocale
						. text(
							"Branch '%s' is not referenced." % branch_name,
							"分支“%s”未被引用。" % branch_name,
							locale,
						)
					),
				}
			)
		)
	return diagnostics


static func _find_branch_reference(
	document: KonadoScriptDocument,
	line: int,
	name: String,
	role: String,
) -> Dictionary:
	for reference: Dictionary in document.references:
		if (
			reference.get("kind") == "branches"
			and reference.get("name") == name
			and reference.get("role") == role
			and int(reference.get("line", 0)) == line
		):
			return reference
	return {}
