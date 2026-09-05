## 设置面板 - 用于显示和管理设置的界面
extends CanvasLayer

## 标签容器，用于显示不同分类的设置
@export var tab_container: TabContainer

## 恢复默认按钮
@export var reset_button: Button

## 关闭按钮
@export var close_button: Button

## 面板标题
@export var title_label: Label

## 确认对话框，用于恢复默认设置的确认
var _confirm_dialog: ConfirmationDialog

## 当前标签页的分类ID
var _current_category_id: String = ""

var _ignore_setting_signal: bool = false
var _rebuild_queued: bool = false
var _rebuild_generation: int = 0


func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSLATION_CHANGED or not is_node_ready():
		return
	_refresh_translated_ui()


## 节点就绪时调用
func _ready() -> void:
	# 设置按钮文本和信号连接
	title_label.text = tr("KONADO_SETTINGS_TITLE")
	reset_button.text = tr("KONADO_SETTINGS_RESET")
	reset_button.pressed.connect(_on_reset_pressed)

	close_button.text = tr("KONADO_CLOSE")
	close_button.pressed.connect(_on_close_pressed)

	# 创建确认对话框
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.dialog_text = tr("KONADO_SETTINGS_RESET_CONFIRM")
	_confirm_dialog.confirmed.connect(_on_reset_confirmed)
	add_child(_confirm_dialog)
	var manager := _get_manager()
	if manager != null:
		manager.setting_changed.connect(_on_setting_changed)

	# 从注册的分类构建标签页
	_build_tabs()


## 构建设置标签页
func _build_tabs() -> void:
	var manager := _get_manager()
	if manager == null:
		return
	for category: KonadoSettingCategory in manager.get_categories():
		var margin_container: MarginContainer = MarginContainer.new()
		margin_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		margin_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin_container.name = tr(category.display_name)
		var margin_value := 20
		margin_container.add_theme_constant_override("margin_top", margin_value)
		margin_container.add_theme_constant_override("margin_left", margin_value)
		margin_container.add_theme_constant_override("margin_bottom", margin_value)
		margin_container.add_theme_constant_override("margin_right", margin_value)

		var scroll := ScrollContainer.new()
		scroll.name = tr(category.display_name)
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

		margin_container.add_child(scroll)

		var settings_list := VBoxContainer.new()
		settings_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(settings_list)

		for item: KonadoSettingItem in category.items:
			var row: HBoxContainer = KonadoSettingsUIFactory.create_control(
				category.id, item, _on_value_changed
			)
			settings_list.add_child(row)

		tab_container.add_child(margin_container, true)


## 重建UI
func rebuild() -> void:
	_rebuild_generation += 1
	var generation := _rebuild_generation
	for child in tab_container.get_children():
		child.queue_free()
	# 等待一帧让节点被移除
	await get_tree().process_frame
	if generation != _rebuild_generation:
		return
	_build_tabs()


func _refresh_translated_ui() -> void:
	title_label.text = tr("KONADO_SETTINGS_TITLE")
	reset_button.text = tr("KONADO_SETTINGS_RESET")
	close_button.text = tr("KONADO_CLOSE")
	_confirm_dialog.dialog_text = tr("KONADO_SETTINGS_RESET_CONFIRM")
	rebuild()


## 当设置值改变时调用
## @param category_id: 分类ID
## @param key: 设置项的键
## @param value: 新的设置值
func _on_value_changed(category_id: String, key: String, value: Variant) -> void:
	var manager := _get_manager()
	if manager != null:
		_ignore_setting_signal = true
		var saved: bool = manager.set_setting(category_id, key, value)
		_ignore_setting_signal = false
		if not saved:
			_queue_rebuild()


## 当点击恢复默认按钮时调用
func _on_reset_pressed() -> void:
	# 获取当前标签页的分类ID
	var manager := _get_manager()
	var tab_index := tab_container.current_tab
	var categories: Array = manager.get_categories() if manager != null else []
	if tab_index >= 0 and tab_index < categories.size():
		_current_category_id = categories[tab_index].id
		_confirm_dialog.popup_centered()


## 当确认恢复默认设置时调用
func _on_reset_confirmed() -> void:
	var manager := _get_manager()
	if manager != null and not _current_category_id.is_empty():
		_ignore_setting_signal = true
		var reset: bool = manager.reset_category(_current_category_id)
		_ignore_setting_signal = false
		if not reset:
			push_warning("KonadoSettings: 无法恢复当前分类的默认设置")
		rebuild()


## 当点击关闭按钮时调用
func _on_close_pressed() -> void:
	queue_free()


## 获取设置管理器实例
## @return: 设置管理器节点
func _get_manager() -> Node:
	return get_tree().root.get_node_or_null("KonadoSettings")


func _on_setting_changed(_category: String, _key: String, _value: Variant) -> void:
	if not _ignore_setting_signal:
		_queue_rebuild()


func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	_run_queued_rebuild.call_deferred()


func _run_queued_rebuild() -> void:
	_rebuild_queued = false
	rebuild()
