@tool
extends RefCounted
class_name KonadoScriptNavigationService

## Resolves semantic KonadoScript references and builds editor tooltips without
## depending on a concrete CodeEdit. Rendering and input remain in the overlay.

const LOCAL_KINDS := ["branches", "variables", "signals"]
const RESOURCE_KINDS := [
	"actors",
	"backgrounds",
	"background_music_tracks",
	"sfx",
	"voices",
	"states",
	"motions",
	"cameras",
	"scripts",
]

var _project_index := KonadoScriptProjectIndex.shared()


func resolve_targets(reference: Dictionary, source: String) -> Array[Dictionary]:
	var kind := String(reference.get("kind", ""))
	var name := String(reference.get("name", ""))
	if kind in LOCAL_KINDS:
		var line := KonadoScriptSymbolIndex.find_local_definition(source, kind, name)
		var local_targets: Array[Dictionary] = []
		if line >= 0:
			local_targets.append({"kind": kind, "name": name, "line": line, "path": ""})
		return local_targets
	if kind == "scripts":
		var script_targets: Array[Dictionary] = []
		if FileAccess.file_exists(name):
			script_targets.append({"kind": kind, "name": name, "line": 1, "path": name})
		return script_targets
	if kind not in RESOURCE_KINDS:
		return []
	var targets: Array[Dictionary]
	if kind in ["states", "motions"]:
		targets = _project_index.get_actor_scoped_targets(
			String(reference.get("scope_name", "")), kind, name
		)
	else:
		targets = _project_index.get_navigation_targets(kind, name)
	var existing: Array[Dictionary] = []
	for target: Dictionary in targets:
		var target_path := String(target.get("path", ""))
		if not target_path.is_empty() and FileAccess.file_exists(target_path):
			existing.append(target)
	return existing


func tooltip(reference: Dictionary, source: String) -> String:
	var kind := String(reference.get("kind", ""))
	var name := String(reference.get("name", ""))
	if kind == "commands":
		return _command_tooltip(name)
	if kind == "effects":
		return KonadoScriptEditorLocale.text("Background transition: %s" % name, "背景转场：%s" % name)
	var targets := resolve_targets(reference, source)
	if targets.is_empty():
		return (
			KonadoScriptEditorLocale
			. text(
				"Unresolved %s: %s" % [_kind_label(kind, false), name],
				"未解析的%s：%s" % [_kind_label(kind, true), name],
			)
		)
	if targets.size() == 1:
		return _single_target_tooltip(kind, name, targets[0], source)
	return (
		KonadoScriptEditorLocale
		. text(
			(
				"%s '%s' has %d targets; Ctrl/Command-click to choose."
				% [_kind_label(kind, false), name, targets.size()]
			),
			(
				"%s“%s”有 %d 个目标；按住 Ctrl/Command 点击以选择。"
				% [_kind_label(kind, true), name, targets.size()]
			),
		)
	)


func _command_tooltip(name: String) -> String:
	var signature := KonadoScriptLanguageCatalog.get_signature(name)
	var description := KonadoScriptLanguageCatalog.get_command_description(
		name, KonadoScriptEditorLocale.get_editor_locale()
	)
	return signature if description.is_empty() else "%s\n%s" % [signature, description]


func _single_target_tooltip(
	kind: String, name: String, target: Dictionary, source: String
) -> String:
	var path := String(target.get("path", ""))
	if path.is_empty():
		var declaration_line := int(target.get("line", 1))
		var preview := _source_line_preview(source, declaration_line)
		return (
			KonadoScriptEditorLocale
			. text(
				(
					"%s '%s', declared on line %d\n%s"
					% [_kind_label(kind, false), name, declaration_line, preview]
				),
				"%s“%s”，声明于第 %d 行\n%s" % [_kind_label(kind, true), name, declaration_line, preview],
			)
		)
	var details := _target_details(target, path)
	return (
		KonadoScriptEditorLocale
		. text(
			"%s '%s'\n%s" % [_kind_label(kind, false), name, details],
			"%s“%s”\n%s" % [_kind_label(kind, true), name, details],
		)
	)


func _target_details(target: Dictionary, path: String) -> String:
	var details := path
	var owner := String(target.get("owner_path", ""))
	if not owner.is_empty() and owner != path:
		details += (
			"\n" + KonadoScriptEditorLocale.text("Declared in: %s" % owner, "声明文件：%s" % owner)
		)
	if int(target.get("line", 0)) > 0:
		details += (
			"\n"
			+ (
				KonadoScriptEditorLocale
				. text(
					"Declaration line: %d" % int(target["line"]),
					"声明行：%d" % int(target["line"]),
				)
			)
		)
	if path.get_extension().to_lower() == "ks":
		var preview := _file_line_preview(path, int(target.get("line", 1)))
		if not preview.is_empty():
			details += "\n" + preview
	return details


func _source_line_preview(source: String, line_number: int) -> String:
	var lines := source.split("\n")
	var index := line_number - 1
	return String(lines[index]).strip_edges() if index >= 0 and index < lines.size() else ""


func _file_line_preview(path: String, line_number: int) -> String:
	if not FileAccess.file_exists(path) or FileAccess.get_size(path) > 8 * 1024 * 1024:
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	return "" if file == null else _source_line_preview(file.get_as_text(), line_number)


func _kind_label(kind: String, chinese: bool) -> String:
	var labels := {
		"branches": ["branch", "分支"],
		"variables": ["variable", "变量"],
		"signals": ["signal", "信号"],
		"actors": ["actor", "演员"],
		"states": ["actor state", "演员状态"],
		"motions": ["actor motion", "演员动作"],
		"backgrounds": ["background", "背景"],
		"background_music_tracks": ["background music", "背景音乐"],
		"sfx": ["sound effect", "音效"],
		"voices": ["voice", "语音"],
		"cameras": ["camera", "镜头"],
		"scripts": ["script", "剧本"],
	}
	var pair: Array = labels.get(kind, [kind, kind])
	return String(pair[1] if chinese else pair[0])
