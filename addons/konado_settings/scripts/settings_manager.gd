extends Node

## 设置管理器全局设置单例，作为自动加载由插件加载

## 当设置值改变时发出的信号
## @param category: 设置分类
## @param key: 设置项的键
## @param value: 新的设置值
signal setting_changed(category: String, key: String, value: Variant)

## 保存设置的文件路径
const SAVE_PATH := "user://knd_settings.cfg"

## 默认设置的JSON文件路径
const DEFAULT_JSON := "res://addons/konado_settings/resources/default_settings.json"

## 存储所有设置分类 { category_id: SettingCategory }
var _categories: Dictionary = {}

## 存储所有设置值 { category_id: { key: value } }
var _values: Dictionary = {}

## 配置文件对象，用于保存设置
var _config := ConfigFile.new()

## 当前运行平台
var _current_platform: String = "all"


## 获取设置的当前值
## @param category: 设置分类
## @param key: 设置项的键
## @return: 设置值，如果不存在则返回默认值或null
func get_setting(category: String, key: String) -> Variant:
	if _values.has(category) and _values[category].has(key):
		return _values[category][key]
	# 如果没有找到值，返回默认值
	if _categories.has(category):
		for item: KND_SettingItem in _categories[category].items:
			if item.key == key:
				return item.default_value
	push_warning("KND_Settings: 未知设置 %s/%s" % [category, key])
	return null

## 修改设置，持久化并发出信号
## @param category: 设置分类
## @param key: 设置项的键
## @param value: 新的设置值
func set_setting(category: String, key: String, value: Variant) -> void:
	if not _values.has(category):
		_values[category] = {}
	_values[category][key] = value
	_config.set_value(category, key, value)
	_config.save(SAVE_PATH)
	setting_changed.emit(category, key, value)

## 在运行时注册额外的设置分类
## @param cat: 要注册的设置分类
func register_category(cat: KND_SettingCategory) -> void:
	_categories[cat.id] = cat
	if not _values.has(cat.id):
		_values[cat.id] = {}
	for item: KND_SettingItem in cat.items:
		if not _values[cat.id].has(item.key):
			_values[cat.id][item.key] = item.default_value

## 将指定分类的所有设置重置为默认值
## @param category_id: 分类ID
func reset_category(category_id: String) -> void:
	if not _categories.has(category_id):
		return
	var cat: KND_SettingCategory = _categories[category_id]
	for item: KND_SettingItem in cat.items:
		set_setting(category_id, item.key, item.default_value)

## 获取所有注册的分类（根据当前平台过滤）
## @return: 过滤后的分类数组
func get_categories() -> Array:
	var filtered_categories = []
	for cat in _categories.values():
		var filtered_cat = _filter_category_for_platform(cat)
		if not filtered_cat.items.is_empty():
			filtered_categories.append(filtered_cat)
	return filtered_categories

## 根据ID获取单个分类（根据当前平台过滤）
## @param id: 分类ID
## @return: 过滤后的分类对象
func get_category(id: String) -> KND_SettingCategory:
	var cat = _categories.get(id)
	if cat:
		return _filter_category_for_platform(cat)
	return cat

## 根据平台过滤分类中的设置项
## @param cat: 原始分类
## @return: 过滤后的分类
func _filter_category_for_platform(cat: KND_SettingCategory) -> KND_SettingCategory:
	var filtered_cat = KND_SettingCategory.new()
	filtered_cat.id = cat.id
	filtered_cat.display_name = cat.display_name
	
	for item: KND_SettingItem in cat.items:
		if _is_item_visible(item):
			filtered_cat.items.append(item)
	
	return filtered_cat

## 检查设置项是否在当前平台可见
## @param item: 设置项
## @return: 是否可见
func _is_item_visible(item: KND_SettingItem) -> bool:
	if item.platforms.is_empty():
		push_warning("建议补充配置platforms: [all]")
	if item.platforms.has("all"):
		return true
	
	if item.platforms.has(_current_platform):
		return true
	
	# 处理linuxbsd别名
	if _current_platform in ["linux", "bsd"] and item.platforms.has("linuxbsd"):
		return true
	
	# 处理debug/release
	if OS.has_feature("debug") and item.platforms.has("debug"):
		return true
	if not OS.has_feature("debug") and item.platforms.has("release"):
		return true
	
	return false


## 节点就绪时调用
func _ready() -> void:
	_detect_platform()  # 检测当前平台
	_load_defaults()    # 加载默认设置
	_load_saved()       # 加载已保存的设置

## 检测当前运行平台
func _detect_platform() -> void:
	if Engine.is_editor_hint():
		_current_platform = "editor"
		return
	
	# 使用OS.has_feature进行更可靠的平台检测
	if OS.has_feature("android"):
		_current_platform = "android"
	elif OS.has_feature("ios"):
		_current_platform = "ios"
	elif OS.has_feature("macos"):
		_current_platform = "macos"
	elif OS.has_feature("windows"):
		_current_platform = "windows"
	elif OS.has_feature("linux"):
		_current_platform = "linux"
	elif OS.has_feature("bsd"):
		_current_platform = "bsd"
	elif OS.has_feature("visionos"):
		_current_platform = "visionos"
	else:
		_current_platform = "all"

## 加载默认设置
func _load_defaults() -> void:
	if not FileAccess.file_exists(DEFAULT_JSON):
		push_warning("KND_Settings: 未找到default_settings.json文件")
		return
	
	var json_string := FileAccess.get_file_as_string(DEFAULT_JSON)
	var json := JSON.new()
	if json.parse(json_string) != OK:
		push_warning("KND_Settings: 解析default_settings.json失败: " + json.get_error_message())
		return
	
	var data: Dictionary = json.get_data()
	if not data.has("categories"):
		push_warning("KND_Settings: default_settings.json缺少'categories'键")
		return
	
	for cat_data: Dictionary in data["categories"]:
		var cat := _parse_category(cat_data)
		if cat:
			register_category(cat)

## 解析分类数据
## @param data: 分类数据字典
## @return: 解析后的分类对象
func _parse_category(data: Dictionary) -> KND_SettingCategory:
	if not data.has("id") or not data.has("items"):
		return null
	
	var cat := KND_SettingCategory.new()
	cat.id = data.get("id", "")
	cat.display_name = data.get("display_name", "")
	
	var items_array: Array = data.get("items", [])
	for item_data: Dictionary in items_array:
		var item := _parse_item(item_data)
		if item:
			cat.items.append(item)
	
	return cat

## 解析设置项数据
## @param data: 设置项数据字典
## @return: 解析后的设置项对象
func _parse_item(data: Dictionary) -> KND_SettingItem:
	if not data.has("key"):
		return null
	
	var item := KND_SettingItem.new()
	item.key = data.get("key", "")
	item.label = data.get("label", "")
	item.type = data.get("type", KND_SettingItem.Type.SLIDER)
	item.min_value = data.get("min_value", 0.0)
	item.max_value = data.get("max_value", 1.0)
	item.step = data.get("step", 0.01)
	item.default_value = data.get("default_value", 0.0)
	
	if data.has("options"):
		item.options = Array(data.get("options", []), TYPE_STRING, "", null)
	
	if data.has("platforms"):
		item.platforms = Array(data.get("platforms", []), TYPE_STRING, "", null)
	
	if data.has("tooltip"):
		item.tooltip = data.get("tooltip", "")
	
	return item

## 加载已保存的设置
func _load_saved() -> void:
	if _config.load(SAVE_PATH) != OK:
		return  # 还没有保存文件 - 默认值就可以
	for category_id: String in _values.keys():
		for key: String in _values[category_id].keys():
			if _config.has_section_key(category_id, key):
				_values[category_id][key] = _config.get_value(category_id, key)
