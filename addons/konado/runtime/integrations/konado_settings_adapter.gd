extends Node

## Konado 与可选 Konado Settings 插件之间的运行时适配层。
## 核心插件只依赖这个稳定接口，不直接引用辅助插件的类型或脚本。

## 设置变更信号
## @param category: 设置分类
## @param key: 设置项的键
## @param value: 新的设置值
signal setting_changed(category: String, key: String, value: Variant)

## 设置键常量定义
const CATEGORY_AUDIO: String = "audio"
const CATEGORY_TEXT: String = "text"
const CATEGORY_DISPLAY: String = "display"

const KEY_MASTER_VOLUME: String = "master_volume"
const KEY_MUSIC_VOLUME: String = "music_volume"
const KEY_SFX_VOLUME: String = "sfx_volume"
const KEY_VOICE_VOLUME: String = "voice_volume"
const KEY_TEXT_SPEED: String = "text_speed"
const KEY_AUTO_DELAY: String = "auto_delay"
const KEY_AUTO_MODE: String = "auto_mode"
const KEY_SKIP_READ: String = "skip_read"
const KEY_SKIP_ALL: String = "skip_all"
const KEY_FULLSCREEN: String = "fullscreen"
const KEY_LANGUAGE: String = "language"

var _settings_manager: Node = null


## 获取设置管理器实例
## @return: 设置管理器节点，如果不存在返回 null
func _get_settings_manager() -> Node:
	if _settings_manager != null and is_instance_valid(_settings_manager):
		return _settings_manager
	_settings_manager = get_tree().root.get_node_or_null("KonadoSettings")
	if (
		_settings_manager != null
		and not _settings_manager.setting_changed.is_connected(_on_setting_changed)
	):
		_settings_manager.setting_changed.connect(_on_setting_changed)
	return _settings_manager


## 通用设置获取方法
## @param category: 设置分类
## @param key: 设置项的键
## @param default_value: 默认值
## @return: 设置值
func get_setting(category: String, key: String, default_value: Variant = null) -> Variant:
	var manager := _get_settings_manager()
	if manager == null:
		return default_value

	var value: Variant = manager.call("get_setting", category, key)
	if value == null:
		return default_value
	return value


## 通用设置设置方法
## @param category: 设置分类
## @param key: 设置项的键
## @param value: 新的设置值
func set_setting(category: String, key: String, value: Variant) -> bool:
	var manager := _get_settings_manager()
	return manager != null and bool(manager.call("set_setting", category, key, value))


## 音频设置相关方法


func get_master_volume() -> float:
	return get_setting(CATEGORY_AUDIO, KEY_MASTER_VOLUME, 1.0)


func get_music_volume() -> float:
	return get_setting(CATEGORY_AUDIO, KEY_MUSIC_VOLUME, 0.8)


func get_sfx_volume() -> float:
	return get_setting(CATEGORY_AUDIO, KEY_SFX_VOLUME, 1.0)


func get_voice_volume() -> float:
	return get_setting(CATEGORY_AUDIO, KEY_VOICE_VOLUME, 1.0)


## 文本播放设置相关方法


func get_text_speed() -> float:
	return get_setting(CATEGORY_TEXT, KEY_TEXT_SPEED, 0.05)


func get_auto_delay() -> float:
	return get_setting(CATEGORY_TEXT, KEY_AUTO_DELAY, 2.0)


func get_auto_mode() -> bool:
	return get_setting(CATEGORY_TEXT, KEY_AUTO_MODE, false)


func get_skip_read() -> bool:
	return get_setting(CATEGORY_TEXT, KEY_SKIP_READ, false)


func get_skip_all() -> bool:
	return get_setting(CATEGORY_TEXT, KEY_SKIP_ALL, false)


## 显示设置相关方法


func get_fullscreen() -> bool:
	return get_setting(CATEGORY_DISPLAY, KEY_FULLSCREEN, false)


func get_language() -> String:
	return TranslationServer.get_locale()


func _ready() -> void:
	_get_settings_manager()


func _exit_tree() -> void:
	if (
		_settings_manager != null
		and is_instance_valid(_settings_manager)
		and _settings_manager.setting_changed.is_connected(_on_setting_changed)
	):
		_settings_manager.setting_changed.disconnect(_on_setting_changed)
	_settings_manager = null


## 设置变更处理
func _on_setting_changed(category: String, key: String, value: Variant) -> void:
	setting_changed.emit(category, key, value)


## 检查设置系统是否可用
## @return: 设置系统是否可用
func is_settings_available() -> bool:
	return _get_settings_manager() != null


## 获取所有分类信息
## @return: 分类数组
func get_categories() -> Array:
	var manager := _get_settings_manager()
	if manager != null:
		return manager.call("get_categories")
	return []


## 重置指定分类的设置
## @param category_id: 分类ID
func reset_category(category_id: String) -> bool:
	var manager := _get_settings_manager()
	return manager != null and bool(manager.call("reset_category", category_id))


## 显示设置面板
func show_settings_panel() -> bool:
	const PANEL_SCENE_PATH := "res://addons/konado_settings/ui/konado_settings_panel.tscn"
	if not ResourceLoader.exists(PANEL_SCENE_PATH):
		push_warning("Konado Settings 插件未安装，无法打开设置面板")
		return false
	var panel_scene := load(PANEL_SCENE_PATH) as PackedScene
	if panel_scene == null:
		push_error("无法加载 Konado Settings 面板：" + PANEL_SCENE_PATH)
		return false
	var settings_panel := panel_scene.instantiate() as Control
	if settings_panel == null:
		push_error("Konado Settings 面板根节点必须继承 Control")
		return false
	add_child(settings_panel)
	settings_panel.show()
	return true
