extends SceneTree

const DIALOGUE_SCENE := preload("res://addons/konado/templates/default/dialogue_runtime.tscn")
const SETTINGS_PANEL_SCENE := preload("res://addons/konado_settings/ui/konado_settings_panel.tscn")
const DIALOGUE_LAYER := 10

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := root.get_node_or_null("KonadoAchievements")
	_expect(manager != null, "achievement manager autoload is available")
	if manager == null:
		_finish()
		return

	manager.hide_panel()
	manager.call("_dismiss_popup")
	await process_frame

	_test_builtin_layer_contract()
	await _test_panel_lifecycle(manager)
	await _test_popup_layer(manager)
	_test_settings_layer()

	paused = false
	_finish()


func _test_builtin_layer_contract() -> void:
	var dialogue := DIALOGUE_SCENE.instantiate()
	var stage_layer := dialogue.get_node("KonadoUI/StageLayer") as CanvasLayer
	var dialogue_layer := dialogue.get_node("KonadoUI/DialogueLayer") as CanvasLayer
	var system_layer := dialogue.get_node("KonadoUI/SystemLayer") as CanvasLayer
	_expect_equal(stage_layer.layer, 1, "stage rendering uses the documented layer")
	_expect_equal(dialogue_layer.layer, 10, "dialogue UI renders above the stage")
	_expect_equal(system_layer.layer, 120, "runtime errors render above all built-in UI")
	_expect(
		stage_layer.layer < dialogue_layer.layer and dialogue_layer.layer < system_layer.layer,
		"built-in UI layers have an explicit monotonic order"
	)
	dialogue.free()


func _test_panel_lifecycle(manager: Node) -> void:
	var previous_focus := Button.new()
	previous_focus.name = "PreviousFocus"
	root.add_child(previous_focus)
	previous_focus.grab_focus()
	await process_frame

	manager.show_panel()
	await process_frame
	await process_frame

	var panel := manager.get("_active_panel") as Control
	_expect(panel != null and is_instance_valid(panel), "achievement button creates the panel")
	if panel == null or not is_instance_valid(panel):
		previous_focus.queue_free()
		return
	var canvas_layer := panel.get_canvas_layer_node()
	_expect(canvas_layer != null, "achievement panel is attached to a CanvasLayer")
	if canvas_layer:
		_expect_equal(
			canvas_layer.layer,
			manager.panel_layer,
			"achievement panel uses its configurable modal layer"
		)
		var original_panel_layer: int = manager.panel_layer
		manager.panel_layer = original_panel_layer - 1
		_expect_equal(
			canvas_layer.layer,
			original_panel_layer - 1,
			"changing panel_layer updates the active CanvasLayer immediately"
		)
		manager.panel_layer = original_panel_layer
		_expect(canvas_layer.layer > DIALOGUE_LAYER, "achievement panel renders above dialogue UI")
		manager.panel_layer = 1000
		_expect_equal(manager.panel_layer, 127, "panel layer is clamped to Godot's valid maximum")
		manager.panel_layer = original_panel_layer
	_expect(panel.visible, "achievement panel is visible after opening")
	_expect_equal(
		(panel.get("_item_container") as VBoxContainer).get_child_count(),
		manager.get_all_achievements().size(),
		"achievement panel renders every configured achievement"
	)
	_expect_equal(
		panel.process_mode,
		Node.PROCESS_MODE_ALWAYS,
		"achievement panel remains interactive while the game is paused"
	)

	paused = true
	var close_button := panel.get("_close_btn") as Button
	_expect(close_button != null, "achievement panel exposes an interactive close button")
	if close_button:
		close_button.pressed.emit()
	else:
		manager.hide_panel()
	await process_frame
	_expect(not manager.is_panel_visible(), "close button works while the game is paused")
	_expect(
		root.gui_get_focus_owner() == previous_focus,
		"closing the panel restores the previous keyboard focus"
	)

	manager.show_panel()
	await process_frame
	_expect(manager.get("_active_panel") == panel, "reopening reuses the existing panel")
	_expect(manager.is_panel_visible(), "achievement panel reopens while the game is paused")
	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	Input.parse_input_event(escape_event)
	await process_frame
	await process_frame
	_expect(not manager.is_panel_visible(), "Escape closes the achievement panel")
	_expect(
		root.gui_get_focus_owner() == previous_focus,
		"closing with Escape restores the previous keyboard focus"
	)

	manager.show_panel()
	await process_frame
	manager.hide_panel()
	manager.show_panel()
	await process_frame
	_expect(
		manager.is_panel_visible() and root.gui_get_focus_owner() != previous_focus,
		"an immediate reopen cancels stale focus restoration"
	)
	manager.hide_panel()
	await process_frame
	await process_frame
	_expect(
		root.gui_get_focus_owner() == previous_focus,
		"the final close restores focus after an immediate reopen"
	)

	manager.show_panel()
	await process_frame
	var replacement_focus := Button.new()
	replacement_focus.name = "ReplacementFocus"
	root.add_child(replacement_focus)
	manager.hide_panel()
	replacement_focus.grab_focus()
	await process_frame
	_expect(
		root.gui_get_focus_owner() == replacement_focus,
		"closing the panel does not steal focus from a newly opened interface"
	)
	paused = false
	replacement_focus.queue_free()
	previous_focus.queue_free()
	await process_frame


func _test_popup_layer(manager: Node) -> void:
	var original_popup_duration: float = manager.popup_duration
	manager.popup_duration = 0.1
	(
		manager
		. call(
			"_show_popup",
			{
				"name": "Test Achievement",
				"description": "Overlay verification",
				"icon": "",
			}
		)
	)
	await process_frame
	await process_frame
	var popup := manager.get("_active_popup") as Control
	_expect(popup != null and is_instance_valid(popup), "achievement notification is created")
	if popup and is_instance_valid(popup):
		var canvas_layer := popup.get_canvas_layer_node()
		_expect(canvas_layer != null, "achievement notification is attached to a CanvasLayer")
		if canvas_layer:
			_expect_equal(
				canvas_layer.layer,
				manager.popup_layer,
				"achievement notification uses its configurable notification layer"
			)
			var original_popup_layer: int = manager.popup_layer
			manager.popup_layer = original_popup_layer - 1
			_expect_equal(
				canvas_layer.layer,
				original_popup_layer - 1,
				"changing popup_layer updates the active CanvasLayer immediately"
			)
			manager.popup_layer = original_popup_layer
			_expect(
				canvas_layer.layer > DIALOGUE_LAYER,
				"achievement notification renders above dialogue UI"
			)
			manager.popup_layer = -1000
			_expect_equal(
				manager.popup_layer, -128, "popup layer is clamped to Godot's valid minimum"
			)
			manager.popup_layer = original_popup_layer
		_expect_equal(
			popup.mouse_filter,
			Control.MOUSE_FILTER_IGNORE,
			"achievement notification does not block gameplay input"
		)
		var popup_timer := manager.get("_popup_timer") as Timer
		_expect_equal(
			popup_timer.process_mode,
			Node.PROCESS_MODE_ALWAYS,
			"achievement notification timeout continues while the game is paused"
		)
	paused = true
	await create_timer(0.2, true, false, true).timeout
	_expect(
		manager.get("_active_popup") == null,
		"achievement notification closes on schedule while the game is paused"
	)
	paused = false
	manager.popup_duration = original_popup_duration
	manager.call("_dismiss_popup")
	await process_frame


func _test_settings_layer() -> void:
	var settings_panel := SETTINGS_PANEL_SCENE.instantiate() as CanvasLayer
	_expect_equal(settings_panel.layer, 100, "settings UI uses the modal overlay layer")
	settings_panel.free()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("FAIL: %s" % message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	_expect(actual == expected, "%s (expected %s, got %s)" % [message, expected, actual])


func _finish() -> void:
	if _failures == 0:
		print("PASS: achievement UI tests")
	quit(_failures)
