extends RefCounted
class_name KonadoScriptProjectLinker

## Resolves and validates the complete cross-script Program dependency graph.

const MAX_PROGRAMS := 4096
const COMPILER_SCRIPT := preload("res://addons/konado/language/compiler/konado_script_compiler.gd")

var _errors: Array[Dictionary] = []
var _programs: Dictionary = {}


func link(entry_path: String) -> bool:
	_errors.clear()
	_programs.clear()
	return link_additional(entry_path)


## Add an entry to the current project-link snapshot. Previously compiled
## dependencies are reused, keeping multi-entry exports linear in project size.
func link_additional(entry_path: String) -> bool:
	var normalized_entry := _normalize_path(entry_path)
	if normalized_entry.is_empty():
		_error("link.invalid_path", entry_path, "剧本路径必须是规范的 res:// 路径")
		return false
	var queue := PackedStringArray([normalized_entry])
	var queued := {normalized_entry: true}
	var cursor := 0
	while cursor < queue.size():
		if _programs.size() >= MAX_PROGRAMS:
			_error("link.budget", normalized_entry, "跨剧本依赖超过 4096 个文件")
			break
		var path := queue[cursor]
		cursor += 1
		queued.erase(path)
		if _programs.has(path):
			continue
		if not ResourceLoader.exists(path):
			_error("link.missing_script", path, "目标剧本不存在")
			continue
		var compiler: RefCounted = COMPILER_SCRIPT.new()
		compiler.set_console_output_enabled(false)
		var shot: KonadoShot = compiler.call("compile_file", path)
		if shot == null or shot.program == null:
			_error("link.compile_failed", path, "目标剧本无法编译", compiler.get_diagnostics())
			continue
		if shot.program.compiler_abi != KonadoProgram.COMPILER_ABI:
			_error("link.abi_mismatch", path, "目标剧本 ABI 与当前编译器不一致")
			continue
		_programs[path] = shot.program
		for target: String in shot.program.dependencies.get("scripts", []):
			var normalized_target := _normalize_path(target)
			if normalized_target.is_empty():
				_error("link.invalid_path", path, "jump 使用了非法路径：%s" % target)
			elif not _programs.has(normalized_target) and not queued.has(normalized_target):
				queue.append(normalized_target)
				queued[normalized_target] = true
	return _errors.is_empty()


func get_errors() -> Array[Dictionary]:
	return _errors.duplicate(true)


func get_programs() -> Dictionary:
	return _programs.duplicate(false)


func dependency_fingerprint() -> String:
	var records := PackedStringArray()
	var paths: Array = _programs.keys()
	paths.sort()
	for path: String in paths:
		var program: KonadoProgram = _programs[path]
		records.append("%s=%s" % [path, program.fingerprint()])
	return "\n".join(records).sha256_text()


func _normalize_path(path: String) -> String:
	var stripped := path.strip_edges()
	if not stripped.begins_with("res://") or stripped.get_extension().to_lower() != "ks":
		return ""
	var normalized := stripped.simplify_path()
	return normalized if normalized.begins_with("res://") else ""


func _error(code: String, path: String, message: String, causes: Array = []) -> void:
	(
		_errors
		. append(
			{
				"severity": "error",
				"stage": "linker",
				"code": code,
				"path": path,
				"line": 1,
				"column": 1,
				"end_line": 1,
				"end_column": 2,
				"raw_message": message,
				"causes": causes.duplicate(true),
			}
		)
	)
