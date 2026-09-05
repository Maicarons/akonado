@tool
extends RefCounted
class_name KonadoSettingsUIFactory

## 设置UI工厂类用于创建设置项的控制界面


## 为给定的设置项创建一个行（HBoxContainer）并返回
## 连接值变化信号到提供的回调函数：
##   callback(category_id: String, key: String, value: Variant)
## @param category_id: 分类ID
## @param item: 设置项
## @param callback: 回调函数
## @return: 创建的HBoxContainer
static func create_control(
	category_id: String, item: KonadoSettingItem, callback: Callable
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label := Label.new()
	label.text = TranslationServer.translate(item.label)
	label.custom_minimum_size.x = 160
	# tooltip
	if item.tooltip != "":
		label.set_mouse_filter(Control.MOUSE_FILTER_STOP)
		label.tooltip_text = TranslationServer.translate(item.tooltip)
	row.add_child(label)

	match item.type:
		KonadoSettingItem.Type.SLIDER:
			_add_slider(row, category_id, item, callback)
		KonadoSettingItem.Type.TOGGLE:
			_add_toggle(row, category_id, item, callback)
		KonadoSettingItem.Type.OPTION:
			_add_option(row, category_id, item, callback)

	return row


## 添加滑块控件
## @param row: 容器
## @param category_id: 分类ID
## @param item: 设置项
## @param callback: 回调函数
static func _add_slider(
	row: HBoxContainer, category_id: String, item: KonadoSettingItem, callback: Callable
) -> void:
	var slider := HSlider.new()
	slider.min_value = item.min_value
	slider.max_value = item.max_value
	slider.step = item.step
	slider.value = _current(category_id, item)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 200

	var value_label := Label.new()
	value_label.custom_minimum_size.x = 60
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = _format_number(slider.value, item.step)

	slider.value_changed.connect(
		func(value: float) -> void:
			value_label.text = _format_number(value, item.step)
			callback.call(category_id, item.key, value)
	)

	row.add_child(slider)
	row.add_child(value_label)


## 添加开关控件
## @param row: 容器
## @param category_id: 分类ID
## @param item: 设置项
## @param callback: 回调函数
static func _add_toggle(
	row: HBoxContainer, category_id: String, item: KonadoSettingItem, callback: Callable
) -> void:
	var checkbox := CheckBox.new()
	checkbox.button_pressed = _current(category_id, item) as bool
	checkbox.toggled.connect(
		func(pressed: bool) -> void: callback.call(category_id, item.key, pressed)
	)
	row.add_child(checkbox)


## 添加选项控件
## @param row: 容器
## @param category_id: 分类ID
## @param item: 设置项
## @param callback: 回调函数
static func _add_option(
	row: HBoxContainer, category_id: String, item: KonadoSettingItem, callback: Callable
) -> void:
	var option_button := OptionButton.new()
	var current_value: String = str(_current(category_id, item))
	var selected_index := -1
	for index in item.options.size():
		option_button.add_item(_localized_option_name(item.options[index]))
		option_button.set_item_metadata(index, item.options[index])
		if item.options[index] == current_value:
			selected_index = index
	if selected_index < 0:
		push_warning("KonadoSettings: 选项值无效，已显示默认值：%s/%s" % [category_id, item.key])
		selected_index = maxi(item.options.find(str(item.default_value)), 0)
	option_button.selected = selected_index
	option_button.custom_minimum_size.x = 140
	option_button.item_selected.connect(
		func(index: int) -> void:
			callback.call(category_id, item.key, str(option_button.get_item_metadata(index)))
	)
	row.add_child(option_button)


static func _localized_option_name(value: String) -> String:
	var built_in_message_key: String = (
		{
			"zh_Hans": "KONADO_LOCALE_SIMPLIFIED_CHINESE",
			"zh_Hant": "KONADO_LOCALE_TRADITIONAL_CHINESE",
			"en": "KONADO_LOCALE_ENGLISH",
			"ja": "KONADO_LOCALE_JAPANESE",
			"ko": "KONADO_LOCALE_KOREAN",
		}
		. get(value, "")
	)
	if not built_in_message_key.is_empty():
		return TranslationServer.translate(built_in_message_key)
	var locale_name := TranslationServer.get_locale_name(value)
	return locale_name if not locale_name.is_empty() else value


## 获取设置项的当前值
## @param category_id: 分类ID
## @param item: 设置项
## @return: 当前值或默认值
static func _current(category_id: String, item: KonadoSettingItem) -> Variant:
	var manager := (
		Engine.get_singleton("KonadoSettings") if Engine.has_singleton("KonadoSettings") else null
	)
	if manager == null:
		# 备用方案：通过场景树自动加载访问
		var tree := Engine.get_main_loop() as SceneTree
		if tree:
			manager = tree.root.get_node_or_null("KonadoSettings")
	if manager != null and manager.has_method("get_setting"):
		return manager.get_setting(category_id, item.key)
	return item.default_value


## 格式化数字显示
## @param value: 数值
## @param step: 步长
## @return: 格式化后的字符串
static func _format_number(value: float, step: float) -> String:
	if step >= 1.0:
		return str(int(value))
	# 根据步长确定小数位数
	var step_text := str(step)
	var decimal_separator := step_text.find(".")
	var decimals := 2
	if decimal_separator >= 0:
		decimals = step_text.length() - decimal_separator - 1
	return ("%." + str(decimals) + "f") % value
