@tool
extends RefCounted
class_name KonadoScriptDocument

## Immutable-by-revision semantic snapshot for one KonadoScript document.
##
## A revision owns the compact token stream, semantic references, outline and
## diagnostics used by every editor feature. The compiler AST is released after
## these immutable projections are built; updating with identical content is a
## no-op so completion, navigation and validation never parse the same revision
## independently.

const LOCALIZED_SCRIPT_LOADER_SCRIPT := preload(
	"res://addons/konado/localization/konado_localized_script_loader.gd"
)
const TOKEN_TAPE_SCRIPT := preload(
	"res://addons/konado/language/compiler/konado_script_token_tape.gd"
)

var path := ""
var source := ""
var source_sha256 := ""
var revision := 0
var valid := false
var tokens: RefCounted = TOKEN_TAPE_SCRIPT.new()
var references: Array[Dictionary] = []
var branch_definitions := {}
var dependencies := PackedStringArray()

var _analysis := {}
var _diagnostics_by_locale := {}
var _input_sha256 := ""


func update(new_source: String, new_path: String = "") -> bool:
	var input_sha256 := new_source.sha256_text()
	if input_sha256 == _input_sha256 and (new_path.is_empty() or new_path == path):
		return false
	if not new_path.is_empty():
		path = new_path
	_input_sha256 = input_sha256
	revision += 1

	var compiler := KonadoScriptCompiler.new()
	compiler.set_console_output_enabled(false)
	# Live editor diagnostics include the same lowered Program graph and data-flow
	# checks as a build. The compiler still parses this revision only once.
	_analysis = compiler.analyze_string(new_source, path, true, true)
	source = String(_analysis.get("source", ""))
	source_sha256 = String(_analysis.get("source_sha256", ""))
	valid = bool(_analysis.get("valid", false))
	tokens = _analysis.get("tokens", TOKEN_TAPE_SCRIPT.new()) as RefCounted
	references = KonadoScriptSymbolIndex.get_semantic_references_from_tokens(source, tokens)
	branch_definitions = _branch_definitions_from_references()
	dependencies = _collect_dependencies()
	# Editor consumers use the compact tape and immutable semantic projections.
	# Keeping the full object AST in every cached revision multiplies memory use
	# without providing additional information to any current service.
	_analysis.erase("ast")
	_diagnostics_by_locale.clear()
	return true


func get_analysis() -> Dictionary:
	return _analysis.duplicate(false)


func get_diagnostics(locale: String = "") -> Array[Dictionary]:
	var normalized_locale := (
		locale if not locale.is_empty() else KonadoScriptEditorLocale.get_editor_locale()
	)
	if not _diagnostics_by_locale.has(normalized_locale):
		var diagnostics := KonadoScriptDiagnostics.new().analyze_result(
			source, path, normalized_locale, _analysis, references
		)
		if valid:
			diagnostics.append_array(
				KonadoScriptControlFlowAnalyzer.analyze(self, normalized_locale)
			)
			diagnostics.append_array(_get_localization_diagnostics(normalized_locale))
		diagnostics.sort_custom(
			func(left: Dictionary, right: Dictionary) -> bool:
				if left.get("line", 1) == right.get("line", 1):
					return int(left.get("column", 1)) < int(right.get("column", 1))
				return int(left.get("line", 1)) < int(right.get("line", 1))
		)
		_diagnostics_by_locale[normalized_locale] = diagnostics
	var result: Array[Dictionary] = []
	for diagnostic: Dictionary in _diagnostics_by_locale[normalized_locale]:
		result.append(diagnostic.duplicate(true))
	return result


func _get_localization_diagnostics(locale: String) -> Array[Dictionary]:
	if path.is_empty() or not FileAccess.file_exists(path):
		return []
	var loader := LOCALIZED_SCRIPT_LOADER_SCRIPT.new()
	var default_path: String = loader.get_base_script_path(path)
	if default_path == path or not FileAccess.file_exists(default_path):
		return []
	var default_file := FileAccess.open(default_path, FileAccess.READ)
	if default_file == null:
		return []
	return (
		KonadoScriptLocalizationValidator
		. compare(
			default_file.get_as_text(),
			source,
			default_path,
			path,
			locale,
		)["diagnostics"]
	)


func get_outline() -> PackedStringArray:
	var outline := PackedStringArray()
	for branch_name: String in branch_definitions:
		outline.append("%s:%d" % [branch_name, branch_definitions[branch_name]])
	return outline


func get_references(kind: String = "", name: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for reference: Dictionary in references:
		if not kind.is_empty() and reference.get("kind") != kind:
			continue
		if not name.is_empty() and reference.get("name") != name:
			continue
		result.append(reference.duplicate(true))
	return result


func get_reference_at(line: int, column: int) -> Dictionary:
	if line < 0:
		return {}
	for reference: Dictionary in references:
		if (
			int(reference.get("line", 0)) == line + 1
			and column >= int(reference.get("start", -1))
			and column < int(reference.get("end", -1))
		):
			return reference.duplicate(true)
	return {}


func _branch_definitions_from_references() -> Dictionary:
	var result := {}
	for reference: Dictionary in references:
		if reference.get("kind") == "branches" and reference.get("role") == "definition":
			var name := String(reference.get("name", ""))
			if not result.has(name):
				result[name] = int(reference.get("line", -1))
	return result


func _collect_dependencies() -> PackedStringArray:
	var result := PackedStringArray()
	var seen := {}
	for reference: Dictionary in references:
		if reference.get("kind") != "scripts":
			continue
		var target := String(reference.get("name", ""))
		if not target.is_empty() and not seen.has(target):
			result.append(target)
			seen[target] = true
	result.sort()
	return result
