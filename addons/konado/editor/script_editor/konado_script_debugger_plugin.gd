@tool
extends EditorDebuggerPlugin

## KonadoScript debugger UI layered on Godot's native breakpoint lifecycle.

const CAPTURE_PREFIX := "konado"

var _session_views := {}
var _latest_state := {}
var _active_sessions := {}


func _has_capture(capture: String) -> bool:
	return capture == CAPTURE_PREFIX


func _capture(message: String, data: Array, session_id: int) -> bool:
	if message not in ["konado:line", "konado:breakpoint"]:
		return false
	if data.is_empty() or not data[0] is Dictionary:
		return true
	var state: Dictionary = data[0]
	_latest_state[session_id] = state.duplicate(true)
	_update_session_view(session_id, state, message.ends_with(":breakpoint"))
	if message.ends_with(":breakpoint"):
		_open_source.call_deferred(String(state.get("path", "")), int(state.get("line", 1)))
	return true


func _setup_session(session_id: int) -> void:
	var root := VBoxContainer.new()
	root.name = "KonadoScript"
	root.set_meta("session_id", session_id)

	var location := Label.new()
	location.name = "Location"
	location.text = KonadoScriptEditorLocale.text(
		"Waiting for KonadoScript…", "正在等待 KonadoScript……"
	)
	location.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	root.add_child(location)

	var controls := HBoxContainer.new()
	var continue_button := Button.new()
	continue_button.text = KonadoScriptEditorLocale.text("Continue", "继续")
	continue_button.pressed.connect(_send_control.bind(session_id, "continue"))
	controls.add_child(continue_button)
	var step_button := Button.new()
	step_button.text = KonadoScriptEditorLocale.text("Step", "单步")
	step_button.pressed.connect(_send_control.bind(session_id, "step"))
	controls.add_child(step_button)
	var pause_button := Button.new()
	pause_button.text = KonadoScriptEditorLocale.text("Pause at next line", "在下一行暂停")
	pause_button.pressed.connect(_send_control.bind(session_id, "pause_next"))
	controls.add_child(pause_button)
	root.add_child(controls)

	var state_tree := Tree.new()
	state_tree.name = "State"
	state_tree.columns = 2
	state_tree.set_column_title(0, KonadoScriptEditorLocale.text("Name", "名称"))
	state_tree.set_column_title(1, KonadoScriptEditorLocale.text("Value", "值"))
	state_tree.column_titles_visible = true
	state_tree.hide_root = true
	state_tree.set_v_size_flags(Control.SIZE_EXPAND_FILL)
	state_tree.custom_minimum_size = Vector2(540, 180)
	root.add_child(state_tree)

	var session := get_session(session_id)
	session.add_session_tab(root)
	session.started.connect(_on_session_started.bind(session_id))
	session.stopped.connect(_on_session_stopped.bind(session_id))
	_session_views[session_id] = root
	_active_sessions[session_id] = false


func _goto_script_line(script: Script, line: int) -> void:
	if script is KonadoShot:
		_open_source(script.resource_path, line)


func cleanup() -> void:
	for view: Control in _session_views.values():
		if is_instance_valid(view):
			view.queue_free()
	_session_views.clear()
	_latest_state.clear()
	_active_sessions.clear()


func _update_session_view(session_id: int, state: Dictionary, paused: bool) -> void:
	var root: VBoxContainer = _session_views.get(session_id)
	if not is_instance_valid(root):
		return
	var location := root.get_node("Location") as Label
	var path := String(state.get("path", ""))
	var line := int(state.get("line", 1))
	location.text = (
		("%s:%d — %s" % [path, line, KonadoScriptEditorLocale.text("Paused", "已暂停")])
		if paused
		else "%s:%d" % [path, line]
	)
	var tree := root.get_node("State") as Tree
	tree.clear()
	var root_item := tree.create_item()
	_add_value(
		tree, root_item, KonadoScriptEditorLocale.text("Shot", "镜头"), state.get("shot_id", "")
	)
	_add_value(
		tree, root_item, KonadoScriptEditorLocale.text("Node", "节点"), state.get("node_id", "")
	)
	_add_dictionary(
		tree,
		root_item,
		KonadoScriptEditorLocale.text("Persistent variables", "持久变量"),
		state.get("persistent_variables", {}),
	)
	_add_dictionary(
		tree,
		root_item,
		KonadoScriptEditorLocale.text("Temporary variables", "临时变量"),
		state.get("temporary_variables", {}),
	)


func _add_dictionary(tree: Tree, parent: TreeItem, label: String, values: Dictionary) -> void:
	var group := tree.create_item(parent)
	group.set_text(0, label)
	group.set_selectable(0, false)
	for key: Variant in values:
		_add_value(tree, group, str(key), values[key])


func _add_value(tree: Tree, parent: TreeItem, label: String, value: Variant) -> void:
	var item := tree.create_item(parent)
	item.set_text(0, label)
	item.set_text(1, str(value))
	item.set_tooltip_text(1, str(value))


func _open_source(path: String, line: int) -> void:
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var script := ResourceLoader.load(path, "Script") as Script
	if script != null:
		EditorInterface.edit_script(script, maxi(1, line))


func _on_session_stopped(session_id: int) -> void:
	_active_sessions[session_id] = false
	_latest_state.erase(session_id)
	var root: VBoxContainer = _session_views.get(session_id)
	if not is_instance_valid(root):
		return
	var location := root.get_node("Location") as Label
	location.text = KonadoScriptEditorLocale.text("Debugger stopped.", "调试已停止。")
	var tree := root.get_node("State") as Tree
	tree.clear()


func _send_control(session_id: int, command: String) -> void:
	if not bool(_active_sessions.get(session_id, false)):
		return
	var session := get_session(session_id)
	if session != null:
		session.send_message("%s:%s" % [CAPTURE_PREFIX, command])


func _on_session_started(session_id: int) -> void:
	_active_sessions[session_id] = true
