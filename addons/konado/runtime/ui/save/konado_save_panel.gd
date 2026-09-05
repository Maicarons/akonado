extends Control

## Reusable save-slot panel for the default Konado dialogue template.

signal closed

const SAVE_SYSTEM_SCRIPT := preload("res://addons/konado/runtime/save/konado_save_system.gd")

@export var save_system: SAVE_SYSTEM_SCRIPT
@export var slot_container: VBoxContainer
@export var status_label: Label
@export var close_button: Button
@export var load_confirmation: ConfirmationDialog
@export var delete_confirmation: ConfirmationDialog

var _pending_load_slot := -1
var _pending_delete_slot := -1


func _ready() -> void:
	visible = false
	if close_button != null:
		close_button.pressed.connect(close_panel)
	if load_confirmation != null:
		load_confirmation.confirmed.connect(_confirm_load)
	if delete_confirmation != null:
		delete_confirmation.confirmed.connect(_confirm_delete)
	refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()


func set_save_system(value: SAVE_SYSTEM_SCRIPT) -> void:
	save_system = value
	if is_node_ready():
		refresh()


func open_panel() -> void:
	refresh()
	visible = true
	if close_button != null:
		close_button.grab_focus()


func close_panel() -> void:
	visible = false
	closed.emit()


func refresh() -> void:
	if slot_container == null:
		return
	for child: Node in slot_container.get_children():
		slot_container.remove_child(child)
		child.queue_free()
	if save_system == null:
		return
	for save_id: int in range(save_system.max_save_slots):
		_create_slot_row(save_id, save_system.get_save_info(save_id))


func show_status(message_key: StringName) -> void:
	if status_label != null:
		status_label.text = tr(message_key)


func _create_slot_row(save_id: int, info: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.name = "SaveSlot%d" % save_id
	row.custom_minimum_size.y = 42.0
	row.add_theme_constant_override("separation", 8)

	var slot_label := Label.new()
	slot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_label.text = (
		tr("KONADO_QUICK_SAVE") if save_id == 0 else tr("KONADO_SAVE_SLOT") % (save_id + 1)
	)
	row.add_child(slot_label)

	var time_label := Label.new()
	time_label.custom_minimum_size.x = 210.0
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_label.text = _format_save_time(info.get("save_time", {}))
	row.add_child(time_label)

	var exists := bool(info.get("exists", false))
	row.add_child(_create_action_button("KONADO_SAVE_ACTION", _save_slot.bind(save_id)))
	var load_button := _create_action_button("KONADO_SAVE_LOAD", _request_load.bind(save_id))
	load_button.disabled = not exists
	row.add_child(load_button)
	var delete_button := _create_action_button("KONADO_SAVE_DELETE", _request_delete.bind(save_id))
	delete_button.disabled = not exists
	row.add_child(delete_button)
	slot_container.add_child(row)


func _create_action_button(message_key: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = tr(message_key)
	button.pressed.connect(action)
	return button


func _format_save_time(value: Variant) -> String:
	if not value is Dictionary or value.is_empty():
		return tr("KONADO_SAVE_EMPTY_SLOT")
	return (
		"%04d-%02d-%02d %02d:%02d"
		% [
			int(value.get("year", 0)),
			int(value.get("month", 0)),
			int(value.get("day", 0)),
			int(value.get("hour", 0)),
			int(value.get("minute", 0)),
		]
	)


func _save_slot(save_id: int) -> void:
	if save_system == null:
		return
	show_status("KONADO_SAVE_SUCCEEDED" if save_system.save_game(save_id) else "KONADO_SAVE_FAILED")
	refresh()


func _request_load(save_id: int) -> void:
	if load_confirmation == null:
		_load_slot(save_id)
		return
	_pending_load_slot = save_id
	load_confirmation.dialog_text = tr("KONADO_LOAD_CONFIRM")
	load_confirmation.popup_centered()


func _confirm_load() -> void:
	_load_slot(_pending_load_slot)
	_pending_load_slot = -1


func _load_slot(save_id: int) -> void:
	if save_system == null or save_id < 0:
		return
	if save_system.load_game(save_id):
		close_panel()
	else:
		show_status("KONADO_SAVE_LOAD_FAILED")


func _request_delete(save_id: int) -> void:
	if delete_confirmation == null:
		_delete_slot(save_id)
		return
	_pending_delete_slot = save_id
	delete_confirmation.dialog_text = tr("KONADO_SAVE_DELETE_CONFIRM")
	delete_confirmation.popup_centered()


func _confirm_delete() -> void:
	_delete_slot(_pending_delete_slot)
	_pending_delete_slot = -1


func _delete_slot(save_id: int) -> void:
	if save_system == null or save_id < 0:
		return
	show_status(
		(
			"KONADO_SAVE_DELETE_SUCCEEDED"
			if save_system.delete_save(save_id)
			else "KONADO_SAVE_DELETE_FAILED"
		)
	)
	refresh()
