@tool
extends Control

## Semantic links and hover information for KonadoScript in Godot's native CodeEdit.
##
## ScriptLanguageExtension lookup is limited to Script resources and Godot treats
## path separators as word boundaries. This controller resolves complete semantic
## spans itself and can open scenes, resources, audio files, KonadoScript files or
## local declarations while leaving non-KonadoScript editors untouched.

const DIAGNOSTIC_HOVER_DELAY := 0.35
const DIAGNOSTIC_DISMISS_DELAY := 0.2
const DIAGNOSTIC_MIN_CONTENT_WIDTH := 360.0
const DIAGNOSTIC_MAX_HEIGHT_RATIO := 0.6

var _code_edit: CodeEdit
var _navigation_service := KonadoScriptNavigationService.new()
var _hover_span := {}
var _hover_reference := {}
var _original_tooltip := ""
var _original_cursor_shape := Control.CURSOR_IBEAM
var _original_symbol_lookup_enabled := false
var _original_symbol_tooltip_enabled := false
var _target_menu: PopupMenu
var _menu_targets: Array[Dictionary] = []
var _diagnostic_hover_timer: Timer
var _diagnostic_dismiss_timer: Timer
var _diagnostic_panel: PanelContainer
var _diagnostic_scroll: ScrollContainer
var _diagnostic_content: VBoxContainer
var _diagnostic_wrap_labels: Array[Label] = []
var _diagnostic_wrap_buttons: Array[Button] = []
var _diagnostic_source := ""
var _diagnostics_by_line := {}
var _fixes_by_line := {}
var _pending_diagnostic_line := -1
var _pending_diagnostic_column := -1
var _pending_diagnostic_position := Vector2.ZERO
var _pending_diagnostic_key := ""


func setup(code_edit: CodeEdit) -> void:
	_code_edit = code_edit
	name = "KonadoJumpLinkOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_original_tooltip = _code_edit.tooltip_text
	_original_cursor_shape = _code_edit.mouse_default_cursor_shape
	_original_symbol_lookup_enabled = _code_edit.is_symbol_lookup_on_click_enabled()
	_original_symbol_tooltip_enabled = _code_edit.is_symbol_tooltip_on_hover_enabled()
	# Godot's native lookup works on lexical words instead of KonadoScript semantic
	# spans. It can underline a complete quoted dialogue or a single directory
	# inside a resource path, so semantic links are exclusively owned here.
	_code_edit.set_symbol_lookup_on_click_enabled(false)
	_code_edit.set_symbol_tooltip_on_hover_enabled(false)
	_code_edit.gui_input.connect(_on_code_edit_gui_input)
	_code_edit.mouse_exited.connect(_on_code_edit_mouse_exited)
	_code_edit.text_changed.connect(_on_text_changed)
	_code_edit.get_h_scroll_bar().value_changed.connect(_on_view_changed)
	_code_edit.get_v_scroll_bar().value_changed.connect(_on_view_changed)
	_code_edit.resized.connect(_on_view_changed)
	_diagnostic_hover_timer = Timer.new()
	_diagnostic_hover_timer.one_shot = true
	_diagnostic_hover_timer.wait_time = DIAGNOSTIC_HOVER_DELAY
	_diagnostic_hover_timer.timeout.connect(_show_diagnostic_hover)
	add_child(_diagnostic_hover_timer)
	_diagnostic_dismiss_timer = Timer.new()
	_diagnostic_dismiss_timer.one_shot = true
	_diagnostic_dismiss_timer.wait_time = DIAGNOSTIC_DISMISS_DELAY
	_diagnostic_dismiss_timer.timeout.connect(_cancel_diagnostic_hover)
	add_child(_diagnostic_dismiss_timer)


func cleanup() -> void:
	if is_instance_valid(_target_menu):
		_target_menu.queue_free()
	_target_menu = null
	_menu_targets.clear()
	_hide_diagnostic_hover()
	if is_instance_valid(_diagnostic_hover_timer):
		_diagnostic_hover_timer.stop()
	_diagnostic_hover_timer = null
	if is_instance_valid(_diagnostic_dismiss_timer):
		_diagnostic_dismiss_timer.stop()
	_diagnostic_dismiss_timer = null
	_diagnostic_panel = null
	_diagnostic_scroll = null
	_diagnostic_content = null
	_diagnostic_wrap_labels.clear()
	_diagnostic_wrap_buttons.clear()
	_diagnostics_by_line.clear()
	_fixes_by_line.clear()
	if not is_instance_valid(_code_edit):
		_code_edit = null
		return
	if _code_edit.gui_input.is_connected(_on_code_edit_gui_input):
		_code_edit.gui_input.disconnect(_on_code_edit_gui_input)
	if _code_edit.mouse_exited.is_connected(_on_code_edit_mouse_exited):
		_code_edit.mouse_exited.disconnect(_on_code_edit_mouse_exited)
	if _code_edit.text_changed.is_connected(_on_text_changed):
		_code_edit.text_changed.disconnect(_on_text_changed)
	if _code_edit.get_h_scroll_bar().value_changed.is_connected(_on_view_changed):
		_code_edit.get_h_scroll_bar().value_changed.disconnect(_on_view_changed)
	if _code_edit.get_v_scroll_bar().value_changed.is_connected(_on_view_changed):
		_code_edit.get_v_scroll_bar().value_changed.disconnect(_on_view_changed)
	if _code_edit.resized.is_connected(_on_view_changed):
		_code_edit.resized.disconnect(_on_view_changed)
	_code_edit.set_symbol_lookup_on_click_enabled(_original_symbol_lookup_enabled)
	_code_edit.set_symbol_tooltip_on_hover_enabled(_original_symbol_tooltip_enabled)
	_code_edit.tooltip_text = _original_tooltip
	_code_edit.mouse_default_cursor_shape = _original_cursor_shape
	_code_edit = null
	_hover_span.clear()
	_hover_reference.clear()


func get_diagnostics_for_line(line: int) -> Array[Dictionary]:
	_refresh_diagnostic_cache()
	var result: Array[Dictionary] = []
	for diagnostic: Dictionary in _diagnostics_by_line.get(line, []):
		result.append(diagnostic.duplicate(true))
	return result


func get_quick_fixes_for_line(line: int) -> Array[Dictionary]:
	_refresh_diagnostic_cache()
	var result: Array[Dictionary] = []
	for fix: Dictionary in _fixes_by_line.get(line, []):
		result.append(fix.duplicate(true))
	return result


func get_hover_span() -> Dictionary:
	return _hover_span.duplicate(true)


func resolve_navigation_targets(reference: Dictionary, source: String) -> Array[Dictionary]:
	return _navigation_service.resolve_targets(reference, source)


func get_reference_tooltip(reference: Dictionary) -> String:
	var source := _code_edit.text if is_instance_valid(_code_edit) else ""
	return _navigation_service.tooltip(reference, source)


func _on_code_edit_gui_input(event: InputEvent) -> void:
	if not is_instance_valid(_code_edit):
		return
	if event is InputEventMouseMotion:
		_update_reference(event.position, event.is_command_or_control_pressed())
		_schedule_diagnostic_hover(event.position)
		return
	if event is InputEventMouseButton and event.pressed:
		_cancel_diagnostic_hover()
	if event is InputEventKey and event.keycode in [KEY_CTRL, KEY_META]:
		_update_reference(
			_code_edit.get_local_mouse_position(),
			event.is_command_or_control_pressed(),
		)
		return
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and event.is_command_or_control_pressed()
	):
		_update_reference(event.position, true)
		if _hover_span.is_empty():
			return
		var targets := resolve_navigation_targets(_hover_reference, _code_edit.text)
		if targets.is_empty():
			return
		_code_edit.accept_event()
		if targets.size() == 1:
			_open_target.call_deferred(targets[0])
		else:
			_show_target_menu.call_deferred(targets, event.global_position)


func _update_reference(mouse_position: Vector2, modifier_pressed: bool) -> void:
	var position := _code_edit.get_line_column_at_pos(mouse_position, false, false)
	if position.y < 0 or position.x < 0:
		_clear_reference()
		return
	var reference := (
		KonadoScriptSymbolIndex
		. get_semantic_reference_at(
			_code_edit.get_line(position.y),
			position.x,
			KonadoScriptSymbolIndex.is_screentext_content_line(_code_edit.text, position.y),
		)
	)
	if not reference.is_empty():
		reference["line"] = position.y
	_hover_reference = reference
	_code_edit.tooltip_text = (
		get_reference_tooltip(reference) if not reference.is_empty() else _original_tooltip
	)
	var span := {}
	if modifier_pressed and not resolve_navigation_targets(reference, _code_edit.text).is_empty():
		span = reference.duplicate(true)
	if span == _hover_span:
		return
	_hover_span = span
	_code_edit.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if not span.is_empty() else _original_cursor_shape
	)
	queue_redraw()


func _clear_reference() -> void:
	_hover_reference.clear()
	if is_instance_valid(_code_edit):
		_code_edit.tooltip_text = _original_tooltip
		_code_edit.mouse_default_cursor_shape = _original_cursor_shape
	if _hover_span.is_empty():
		return
	_hover_span.clear()
	if is_instance_valid(_code_edit):
		queue_redraw()


func _on_code_edit_mouse_exited() -> void:
	_clear_reference()
	_cancel_hover_if_pointer_left.call_deferred()


func _cancel_hover_if_pointer_left() -> void:
	var mouse_position := (
		_code_edit.get_local_mouse_position() if is_instance_valid(_code_edit) else Vector2.ZERO
	)
	if (
		_is_pointer_over_diagnostic_panel()
		or _is_pointer_over_pending_diagnostic()
		or _is_pointer_in_diagnostic_bridge(mouse_position)
	):
		_cancel_diagnostic_dismissal()
		return
	_schedule_diagnostic_dismissal()


func _on_text_changed() -> void:
	_clear_reference()
	_diagnostic_source = ""
	_cancel_diagnostic_hover()


func _on_view_changed(_value: Variant = null) -> void:
	if not _hover_span.is_empty():
		queue_redraw()
	_cancel_diagnostic_hover()


func _schedule_diagnostic_hover(mouse_position: Vector2) -> void:
	if not is_instance_valid(_code_edit) or not is_instance_valid(_diagnostic_hover_timer):
		return
	var position := _code_edit.get_line_column_at_pos(mouse_position, false, false)
	_update_diagnostic_hover_target(position.y, position.x, mouse_position)


func _update_diagnostic_hover_target(line: int, column: int, mouse_position: Vector2) -> void:
	var target := _get_diagnostic_target(line, column)
	if target.is_empty():
		_diagnostic_hover_timer.stop()
		if is_instance_valid(_diagnostic_panel) and _diagnostic_panel.visible:
			if _is_pointer_in_diagnostic_bridge(mouse_position):
				_cancel_diagnostic_dismissal()
			else:
				_schedule_diagnostic_dismissal()
		else:
			_reset_pending_diagnostic()
		return
	_cancel_diagnostic_dismissal()
	_code_edit.tooltip_text = ""
	_pending_diagnostic_position = mouse_position
	_pending_diagnostic_column = column
	var target_key := String(target.get("key", ""))
	if target_key == _pending_diagnostic_key:
		return
	_pending_diagnostic_line = line
	_pending_diagnostic_key = target_key
	_hide_diagnostic_hover()
	_diagnostic_hover_timer.start()


func _show_diagnostic_hover() -> void:
	if (
		not is_instance_valid(_code_edit)
		or _pending_diagnostic_line < 0
		or (
			_get_diagnostics_at_position(
				_pending_diagnostic_line,
				_pending_diagnostic_column,
			)
			. is_empty()
		)
	):
		return
	_ensure_diagnostic_panel()
	_clear_diagnostic_content()
	var diagnostics := _get_diagnostics_at_position(
		_pending_diagnostic_line,
		_pending_diagnostic_column,
	)
	var fixes := get_quick_fixes_for_line(_pending_diagnostic_line)
	var source_snapshot := _code_edit.text
	for index: int in diagnostics.size():
		if index > 0:
			_diagnostic_content.add_child(HSeparator.new())
		_add_diagnostic_entry(
			diagnostics[index],
			fixes,
			source_snapshot,
		)
	_layout_diagnostic_content()
	var max_content_height := maxf(80.0, _code_edit.size.y * DIAGNOSTIC_MAX_HEIGHT_RATIO - 24.0)
	_diagnostic_scroll.custom_minimum_size.y = minf(
		_diagnostic_content.get_combined_minimum_size().y,
		max_content_height,
	)
	_diagnostic_panel.reset_size()
	var panel_size := _diagnostic_panel.get_combined_minimum_size()
	_diagnostic_panel.size = panel_size
	_diagnostic_panel.position = Vector2(
		clampf(
			_pending_diagnostic_position.x + 14.0,
			0.0,
			maxf(0.0, _code_edit.size.x - panel_size.x),
		),
		clampf(
			_pending_diagnostic_position.y + 20.0,
			0.0,
			maxf(0.0, _code_edit.size.y - panel_size.y),
		),
	)
	_cancel_diagnostic_dismissal()
	_diagnostic_panel.show()


func _add_diagnostic_entry(
	diagnostic: Dictionary,
	fixes: Array[Dictionary],
	source_snapshot: String,
) -> void:
	var severity := String(diagnostic.get("severity", "error"))
	var severity_color := Color(1.0, 0.45, 0.4) if severity == "error" else Color(1.0, 0.75, 0.35)
	var message_row := HBoxContainer.new()
	message_row.add_theme_constant_override("separation", 8)
	var severity_icon := Label.new()
	severity_icon.text = "✕" if severity == "error" else "△"
	severity_icon.tooltip_text = (
		KonadoScriptEditorLocale.text("Error", "错误")
		if severity == "error"
		else KonadoScriptEditorLocale.text("Warning", "警告")
	)
	severity_icon.accessibility_name = severity_icon.tooltip_text
	severity_icon.modulate = severity_color
	severity_icon.mouse_filter = Control.MOUSE_FILTER_PASS
	message_row.add_child(severity_icon)
	var message := Label.new()
	message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message.autowrap_mode = TextServer.AUTOWRAP_OFF
	message.text = String(diagnostic.get("message", ""))
	message.tooltip_text = String(diagnostic.get("code", ""))
	message.modulate = severity_color
	message_row.add_child(message)
	_diagnostic_wrap_labels.append(message)
	_diagnostic_content.add_child(message_row)

	var matched_fixes := KonadoScriptQuickFixService.rank_fixes_for_diagnostic(fixes, diagnostic)
	var actions: Array = diagnostic.get("actions", [])
	if matched_fixes.is_empty() and actions.is_empty():
		actions = [{"kind": "docs"}]
	for fix: Dictionary in matched_fixes:
		var fix_button := Button.new()
		fix_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fix_button.autowrap_mode = TextServer.AUTOWRAP_OFF
		fix_button.clip_text = false
		fix_button.text = (
			KonadoScriptEditorLocale.text("Try: %s", "尝试：%s") % String(fix.get("title", ""))
		)
		fix_button.accessibility_name = fix_button.text
		fix_button.tooltip_text = (
			KonadoScriptEditorLocale
			. text(
				"Apply this change to the current KonadoScript.",
				"将此修改应用到当前 KonadoScript。",
			)
		)
		fix_button.pressed.connect(_apply_hover_fix.bind(fix.duplicate(true), source_snapshot))
		_diagnostic_content.add_child(fix_button)
		_diagnostic_wrap_buttons.append(fix_button)
	for action: Dictionary in actions:
		var action_button := Button.new()
		action_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_button.autowrap_mode = TextServer.AUTOWRAP_OFF
		action_button.clip_text = false
		action_button.text = _diagnostic_action_label(action)
		action_button.accessibility_name = action_button.text
		action_button.pressed.connect(_apply_diagnostic_action.bind(action.duplicate(true)))
		_diagnostic_content.add_child(action_button)
		_diagnostic_wrap_buttons.append(action_button)


func _layout_diagnostic_content() -> void:
	var max_content_width := maxf(
		120.0,
		_code_edit.size.x - 56.0,
	)
	_diagnostic_content.custom_minimum_size = Vector2.ZERO
	_diagnostic_scroll.custom_minimum_size = Vector2.ZERO
	_diagnostic_content.update_minimum_size()
	var natural_width := maxf(
		DIAGNOSTIC_MIN_CONTENT_WIDTH,
		_diagnostic_content.get_combined_minimum_size().x,
	)
	var content_width := minf(natural_width, max_content_width)
	var should_wrap := natural_width > max_content_width
	for message: Label in _diagnostic_wrap_labels:
		message.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART if should_wrap else TextServer.AUTOWRAP_OFF
		)
		message.custom_minimum_size.x = maxf(120.0, content_width - 32.0) if should_wrap else 0.0
	for button: Button in _diagnostic_wrap_buttons:
		button.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART if should_wrap else TextServer.AUTOWRAP_OFF
		)
	_diagnostic_content.custom_minimum_size.x = content_width
	_diagnostic_scroll.custom_minimum_size.x = content_width
	_diagnostic_content.update_minimum_size()
	_diagnostic_scroll.update_minimum_size()


func _ensure_diagnostic_panel() -> void:
	if is_instance_valid(_diagnostic_panel):
		return
	_diagnostic_panel = PanelContainer.new()
	_diagnostic_panel.name = "KonadoDiagnosticHover"
	_diagnostic_panel.accessibility_name = (
		KonadoScriptEditorLocale
		. text(
			"KonadoScript diagnostic",
			"KonadoScript 诊断",
		)
	)
	_diagnostic_panel.z_index = 100
	_diagnostic_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_diagnostic_panel.mouse_entered.connect(_on_diagnostic_panel_mouse_entered)
	_diagnostic_panel.mouse_exited.connect(_on_diagnostic_panel_mouse_exited)
	_diagnostic_panel.add_theme_stylebox_override("panel", _create_diagnostic_panel_style())
	_diagnostic_panel.hide()
	_diagnostic_scroll = ScrollContainer.new()
	_diagnostic_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_diagnostic_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_diagnostic_content = VBoxContainer.new()
	_diagnostic_content.add_theme_constant_override("separation", 6)
	_diagnostic_scroll.add_child(_diagnostic_content)
	_diagnostic_panel.add_child(_diagnostic_scroll)
	add_child(_diagnostic_panel)


func _create_diagnostic_panel_style() -> StyleBoxFlat:
	var base_color := Color(0.12, 0.12, 0.13)
	if is_instance_valid(_code_edit) and _code_edit.has_theme_color("base_color", "Editor"):
		base_color = _code_edit.get_theme_color("base_color", "Editor")
	base_color.a = 0.8
	var style := StyleBoxFlat.new()
	style.bg_color = base_color
	style.set_corner_radius_all(20)
	style.content_margin_left = 14.0
	style.content_margin_top = 12.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 12.0
	return style


func _clear_diagnostic_content() -> void:
	if not is_instance_valid(_diagnostic_content):
		return
	_diagnostic_wrap_labels.clear()
	_diagnostic_wrap_buttons.clear()
	_diagnostic_content.custom_minimum_size = Vector2.ZERO
	_diagnostic_scroll.custom_minimum_size = Vector2.ZERO
	for child: Node in _diagnostic_content.get_children():
		_diagnostic_content.remove_child(child)
		child.free()


func _hide_diagnostic_hover() -> void:
	if is_instance_valid(_diagnostic_panel):
		_diagnostic_panel.hide()


func _on_diagnostic_panel_mouse_exited() -> void:
	_cancel_hover_if_pointer_left.call_deferred()


func _on_diagnostic_panel_mouse_entered() -> void:
	_cancel_diagnostic_dismissal()


func _schedule_diagnostic_dismissal() -> void:
	if not is_instance_valid(_diagnostic_dismiss_timer):
		_cancel_diagnostic_hover()
		return
	if _diagnostic_dismiss_timer.is_stopped():
		_diagnostic_dismiss_timer.start()


func _cancel_diagnostic_dismissal() -> void:
	if is_instance_valid(_diagnostic_dismiss_timer):
		_diagnostic_dismiss_timer.stop()


func _is_pointer_over_diagnostic_panel() -> bool:
	return (
		is_instance_valid(_diagnostic_panel)
		and _diagnostic_panel.visible
		and Rect2(Vector2.ZERO, _diagnostic_panel.size).has_point(
			_diagnostic_panel.get_local_mouse_position()
		)
	)


func _is_pointer_over_pending_diagnostic() -> bool:
	if not is_instance_valid(_code_edit) or _pending_diagnostic_key.is_empty():
		return false
	var mouse_position := _code_edit.get_local_mouse_position()
	if not Rect2(Vector2.ZERO, _code_edit.size).has_point(mouse_position):
		return false
	var position := _code_edit.get_line_column_at_pos(mouse_position, false, false)
	var target := _get_diagnostic_target(position.y, position.x)
	return String(target.get("key", "")) == _pending_diagnostic_key


func _is_pointer_in_diagnostic_bridge(mouse_position: Vector2) -> bool:
	if not is_instance_valid(_diagnostic_panel) or not _diagnostic_panel.visible:
		return false
	var panel_rect := Rect2(_diagnostic_panel.position, _diagnostic_panel.size)
	var closest_panel_point := Vector2(
		clampf(_pending_diagnostic_position.x, panel_rect.position.x, panel_rect.end.x),
		clampf(_pending_diagnostic_position.y, panel_rect.position.y, panel_rect.end.y),
	)
	var bridge_start := Vector2(
		minf(_pending_diagnostic_position.x, closest_panel_point.x),
		minf(_pending_diagnostic_position.y, closest_panel_point.y),
	)
	var bridge_end := Vector2(
		maxf(_pending_diagnostic_position.x, closest_panel_point.x),
		maxf(_pending_diagnostic_position.y, closest_panel_point.y),
	)
	return Rect2(bridge_start, bridge_end - bridge_start).grow(8.0).has_point(mouse_position)


func _reset_pending_diagnostic() -> void:
	_pending_diagnostic_line = -1
	_pending_diagnostic_column = -1
	_pending_diagnostic_key = ""


func _cancel_diagnostic_hover() -> void:
	_reset_pending_diagnostic()
	if is_instance_valid(_diagnostic_hover_timer):
		_diagnostic_hover_timer.stop()
	_cancel_diagnostic_dismissal()
	_hide_diagnostic_hover()


func _apply_hover_fix(fix: Dictionary, expected_source: String) -> void:
	if not is_instance_valid(_code_edit) or _code_edit.text != expected_source:
		_cancel_diagnostic_hover()
		return
	var materialized := KonadoScriptQuickFixService.materialize_line_fix(expected_source, fix)
	if materialized.is_empty():
		_cancel_diagnostic_hover()
		return
	var updated := KonadoScriptQuickFixService.apply_fix(expected_source, materialized)
	KonadoScriptCodeEditTransaction.replace_text(_code_edit, updated)
	if _code_edit.is_inside_tree():
		_code_edit.grab_focus()
	_cancel_diagnostic_hover()


func _get_diagnostics_at_position(line: int, column: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for diagnostic: Dictionary in get_diagnostics_for_line(line):
		var start_column := maxi(0, int(diagnostic.get("column", 1)) - 1)
		var end_column := maxi(start_column + 1, int(diagnostic.get("end_column", 2)) - 1)
		if column >= start_column and column < end_column:
			result.append(diagnostic)
	return result


func _get_diagnostic_target(line: int, column: int) -> Dictionary:
	if line < 0 or column < 0:
		return {}
	var diagnostics := _get_diagnostics_at_position(line, column)
	if diagnostics.is_empty():
		return {}
	var identity_parts := PackedStringArray()
	for diagnostic: Dictionary in diagnostics:
		(
			identity_parts
			. append(
				(
					"%d:%d:%s:%s"
					% [
						int(diagnostic.get("column", 1)),
						int(diagnostic.get("end_column", 2)),
						String(diagnostic.get("code", "")),
						String(diagnostic.get("message", "")),
					]
				)
			)
		)
	return {
		"line": line,
		"key": "%d|%s" % [line, "|".join(identity_parts)],
	}


func _diagnostic_action_label(action: Dictionary) -> String:
	if action.get("kind") == "open_path":
		var path := String(action.get("path", ""))
		if not path.is_empty():
			return KonadoScriptEditorLocale.text(
				"Open: %s" % path.get_file(), "打开：%s" % path.get_file()
			)
		return KonadoScriptEditorLocale.text("Open resource configuration", "打开资源配置")
	return KonadoScriptEditorLocale.text("View documentation", "查看文档")


func _apply_diagnostic_action(action: Dictionary) -> void:
	if action.get("kind") == "open_path":
		_open_target(
			{
				"path": String(action.get("path", "")),
				"line": int(action.get("line", 1)),
			}
		)
	else:
		_open_diagnostic_docs()
	_cancel_diagnostic_hover()


func _open_diagnostic_docs() -> void:
	var config := ConfigFile.new()
	var version := ""
	if config.load("res://addons/konado/plugin.cfg") == OK:
		version = String(config.get_value("plugin", "version", ""))
	var url := (
		KonadoScriptEditorIntegration
		. get_docs_url(
			version,
			KonadoScriptEditorLocale.get_editor_locale(),
		)
	)
	var open_error := OS.shell_open(url)
	if open_error != OK:
		push_error("Unable to open KonadoScript documentation: %s" % url)


func _refresh_diagnostic_cache() -> void:
	if not is_instance_valid(_code_edit) or _diagnostic_source == _code_edit.text:
		return
	_diagnostic_source = _code_edit.text
	_diagnostics_by_line.clear()
	_fixes_by_line.clear()
	var path := ""
	var current_script := EditorInterface.get_script_editor().get_current_script()
	if current_script != null:
		path = current_script.resource_path
	var document := KonadoScriptDocumentStore.shared().update_buffer(path, _diagnostic_source)
	var locale := KonadoScriptEditorLocale.get_editor_locale()
	for diagnostic: Dictionary in document.get_diagnostics(locale):
		var line := maxi(0, int(diagnostic.get("line", 1)) - 1)
		if not _diagnostics_by_line.has(line):
			_diagnostics_by_line[line] = []
		_diagnostics_by_line[line].append(diagnostic)
	for fix: Dictionary in KonadoScriptQuickFixService.get_fixes(document, locale):
		var line := maxi(0, int(fix.get("line", 1)) - 1)
		if not _fixes_by_line.has(line):
			_fixes_by_line[line] = []
		_fixes_by_line[line].append(fix)


func _show_target_menu(targets: Array[Dictionary], global_position: Vector2) -> void:
	_ensure_target_menu()
	_target_menu.clear()
	_menu_targets = targets
	for index: int in targets.size():
		var target := targets[index]
		var path := String(target.get("path", ""))
		var owner := String(target.get("owner_path", ""))
		var label := path if owner.is_empty() or owner == path else "%s  (%s)" % [path, owner]
		_target_menu.add_item(label, index)
	_target_menu.position = Vector2i(global_position)
	_target_menu.popup()


func _ensure_target_menu() -> void:
	if is_instance_valid(_target_menu):
		return
	_target_menu = PopupMenu.new()
	_target_menu.name = "KonadoNavigationTargets"
	_target_menu.id_pressed.connect(_on_target_selected)
	EditorInterface.get_base_control().add_child(_target_menu)


func _on_target_selected(index: int) -> void:
	if index < 0 or index >= _menu_targets.size():
		return
	_open_target(_menu_targets[index])


func _open_target(target: Dictionary) -> void:
	var path := String(target.get("path", ""))
	if path.is_empty():
		_go_to_local_line(int(target.get("line", 1)))
		return
	if not FileAccess.file_exists(path):
		push_error("Unable to open KonadoScript semantic target: %s" % path)
		return
	match path.get_extension().to_lower():
		"ks":
			var script := ResourceLoader.load(path, "Script") as Script
			if script != null:
				EditorInterface.edit_script(script, maxi(1, int(target.get("line", 1))))
				_schedule_filesystem_selection(path)
		"tscn":
			EditorInterface.open_scene_from_path(path)
			_focus_open_scene_editor.call_deferred()
		_:
			var resource := ResourceLoader.load(path)
			if resource != null:
				EditorInterface.edit_resource(resource)


func _schedule_filesystem_selection(
	path: String,
	navigator: Callable = Callable(),
) -> void:
	if not navigator.is_valid():
		var filesystem_dock := EditorInterface.get_file_system_dock()
		if filesystem_dock == null:
			return
		navigator = Callable(filesystem_dock, "navigate_to_path")
	navigator.call_deferred(path)


func _focus_open_scene_editor() -> void:
	var base_control := EditorInterface.get_base_control()
	if base_control != null and base_control.get_tree() != null:
		await base_control.get_tree().process_frame
	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return
	var main_screen := "3D" if scene_root is Node3D else "2D"
	EditorInterface.set_main_screen_editor(main_screen)
	var selection := EditorInterface.get_selection()
	if selection != null:
		selection.clear()
		selection.add_node(scene_root)


func _go_to_local_line(line_number: int) -> void:
	if not is_instance_valid(_code_edit):
		return
	var line := clampi(line_number - 1, 0, _code_edit.get_line_count() - 1)
	_code_edit.set_caret_line(line)
	_code_edit.set_caret_column(0)
	_code_edit.center_viewport_to_caret()
	_code_edit.grab_focus()


func _draw() -> void:
	if _hover_span.is_empty() or not is_instance_valid(_code_edit):
		return
	var line := int(_hover_span["line"])
	var start_column := int(_hover_span["start"])
	var end_column := int(_hover_span["end"])
	var color := _code_edit.get_theme_color("font_color")
	var font := _code_edit.get_theme_font("font")
	var font_size := _code_edit.get_theme_font_size("font_size")
	var line_spacing := _code_edit.get_theme_constant("line_spacing")
	var thickness := maxf(1.0, font.get_underline_thickness(font_size))
	var segment_start := Vector2.ZERO
	var segment_end := Vector2.ZERO
	var segment_y := -1.0
	for column: int in range(start_column, end_column):
		var rect := _get_character_rect(line, column)
		if rect.position.x < 0:
			continue
		var underline_y := (
			float(rect.position.y)
			+ float(line_spacing) / 2.0
			+ ceilf(font.get_ascent(font_size))
			+ ceilf(font.get_underline_position(font_size))
		)
		var character_start := minf(float(rect.position.x), float(rect.end.x))
		var character_end := maxf(float(rect.position.x), float(rect.end.x))
		var starts_new_segment := (
			segment_y < 0.0
			or not is_equal_approx(segment_y, underline_y)
			or character_start > segment_end.x + 1.0
			or character_end < segment_start.x - 1.0
		)
		if starts_new_segment:
			if segment_y >= 0.0:
				draw_line(segment_start, segment_end, color, thickness)
			segment_y = underline_y
			segment_start = Vector2(character_start, underline_y)
			segment_end = Vector2(character_end, underline_y)
		else:
			segment_start.x = minf(segment_start.x, character_start)
			segment_end.x = maxf(segment_end.x, character_end)
	if segment_y >= 0.0:
		draw_line(segment_start, segment_end, color, thickness)


func _get_character_rect(line: int, column: int) -> Rect2i:
	# TextEdit columns describe caret boundaries. At a boundary, Godot returns the
	# preceding grapheme, so the visible character at zero-based `column` is
	# represented by the boundary immediately after it.
	var line_length := _code_edit.get_line(line).length()
	if column < 0 or column >= line_length:
		return Rect2i(-1, -1, 0, 0)
	return _code_edit.get_rect_at_line_column(line, column + 1)
