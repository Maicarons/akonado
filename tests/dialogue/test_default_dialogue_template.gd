extends SceneTree

const DIALOGUE_SCENE := preload("res://addons/konado/templates/default/dialogue_runtime.tscn")

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := DIALOGUE_SCENE.instantiate() as KonadoDialogueManager
	manager.initialize_on_ready = false
	manager.start_on_ready = false
	root.add_child(manager)
	await process_frame

	_expect(manager.quick_save_button != null, "default template exposes Quick Save")
	_expect(manager.quick_load_button != null, "default template exposes Quick Load")
	_expect(manager.save_panel_button != null, "default template exposes the save panel")
	_expect(manager.achievement_button != null, "default template exposes achievements")
	_expect(manager.save_panel != null, "default template contains a save panel")
	_expect(
		manager.error_tooltip_panel != null, "default template contains the runtime error overlay"
	)
	_expect(
		manager.error_action_container != null,
		"default template exposes the runtime recovery action container",
	)
	_expect(
		manager.error_action_container is HFlowContainer,
		"runtime recovery actions wrap on narrow viewports",
	)
	_expect(
		manager.error_tooltip_label.get_parent() == manager.error_action_container.get_parent(),
		"runtime diagnostics and actions share one responsive vertical layout",
	)
	if manager.save_panel != null:
		_expect_equal(
			manager.save_panel.slot_container.get_child_count(),
			manager.save_system.max_save_slots,
			"the save panel renders every configured slot",
		)
		manager.save_panel_button.pressed.emit()
		_expect(manager.save_panel.visible, "the save button opens the save panel")
		manager.save_panel.close_panel()
		_expect(not manager.save_panel.visible, "the save panel can be closed")

	manager.queue_free()
	await process_frame
	if _failures == 0:
		print("PASS: default dialogue template tests")
	quit(_failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("FAIL: " + message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		return
	_failures += 1
	printerr("FAIL: %s\n  expected: %s\n  actual:   %s" % [message, expected, actual])
