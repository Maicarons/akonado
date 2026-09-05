extends Node

## 全局成就管理器单例

signal achievement_unlocked(achievement_id: String, data: Dictionary)
signal achievement_progress_updated(achievement_id: String, current: float, target: float)
signal achievement_reset(achievement_id: String)
signal achievements_reset
signal achievements_loaded

const DEFAULT_PANEL_LAYER := 100
const DEFAULT_POPUP_LAYER := 110

@export var config_path: String = "res://addons/konado_achievement/data/default_achievements.json"
@export var save_path: String = "user://achievements_save.json"
@export_range(0.1, 60.0, 0.1, "or_greater") var popup_duration: float = 3.0
@export var popup_position: String = "top_left"  # top_left, top_right, bottom_left, bottom_right
@export_range(-128, 127, 1) var panel_layer: int = DEFAULT_PANEL_LAYER:
	set(value):
		panel_layer = clampi(value, -128, 127)
		if _panel_canvas_layer:
			_panel_canvas_layer.layer = panel_layer
@export_range(-128, 127, 1) var popup_layer: int = DEFAULT_POPUP_LAYER:
	set(value):
		popup_layer = clampi(value, -128, 127)
		if _popup_canvas_layer:
			_popup_canvas_layer.layer = popup_layer

## 覆盖此回调以将解锁同步到外部后端。
## func(achievement_id: String, data: Dictionary) -> void
var on_external_unlock: Callable = Callable()

## 覆盖此以提供自定义保存/加载后端。
var custom_save_handler: Callable = Callable()  # func(data: Dictionary) -> void
var custom_load_handler: Callable = Callable()  # func() -> Dictionary

var _achievements: Dictionary = {}  # id -> 成就数据字典
var _unlocked: Dictionary = {}  # id -> bool
var _progress: Dictionary = {}  # key -> float (计数器值)
var _popup_scene: PackedScene = null
var _panel_scene: PackedScene = null
var _active_popup: Control = null
var _active_panel: Control = null
var _popup_timer: Timer = null
var _panel_canvas_layer: CanvasLayer = null
var _popup_canvas_layer: CanvasLayer = null
var _previous_focus_owner: Control = null
var _focus_change_generation: int = 0
var _last_storage_error := ""


func _ready() -> void:
	_panel_canvas_layer = _create_canvas_layer("AchievementPanelLayer", panel_layer)
	_popup_canvas_layer = _create_canvas_layer("AchievementPopupLayer", popup_layer)
	_popup_scene = load("res://addons/konado_achievement/ui/konado_achievement_popup.tscn")
	_panel_scene = load("res://addons/konado_achievement/ui/konado_achievement_panel.tscn")
	_load_config()
	_load_save_data()
	achievements_loaded.emit()


func _load_config() -> void:
	var file := FileAccess.open(config_path, FileAccess.READ)
	if not file:
		push_warning("KonadoAchievement 无法打开配置：%s" % config_path)
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_error("KonadoAchievement JSON 解析错误：%s" % json.get_error_message())
		return
	var data: Variant = json.data
	if not data is Dictionary or not data.get("achievements") is Array:
		push_error("KonadoAchievement 配置根节点必须包含 achievements 数组。")
		return
	var loaded_achievements: Dictionary = {}
	for index in data["achievements"].size():
		var entry: Variant = data["achievements"][index]
		if not _is_valid_achievement(entry, index):
			continue
		var achievement_id: String = entry["id"]
		if loaded_achievements.has(achievement_id):
			push_warning("KonadoAchievement 忽略重复成就 ID：%s" % achievement_id)
			continue
		loaded_achievements[achievement_id] = entry.duplicate(true)
	_achievements = loaded_achievements
	print("KonadoAchievement 加载了 %d 个成就。" % _achievements.size())


func _load_save_data() -> void:
	if custom_load_handler.is_valid():
		_apply_save_data(custom_load_handler.call(), "自定义加载器")
		return
	var load_path := save_path
	if not FileAccess.file_exists(load_path) and FileAccess.file_exists(save_path + ".bak"):
		load_path = save_path + ".bak"
	var file := FileAccess.open(load_path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("KonadoAchievement 存档解析失败：%s" % load_path)
		if load_path == save_path and FileAccess.file_exists(save_path + ".bak"):
			_load_backup_save()
		return
	if not _apply_save_data(json.data, load_path) and load_path == save_path:
		_load_backup_save()


func _save_data(report_errors := true) -> bool:
	_last_storage_error = ""
	var data := {"unlocked": _unlocked.duplicate(true), "progress": _progress.duplicate(true)}
	if custom_save_handler.is_valid():
		custom_save_handler.call(data)
		return true
	var temporary_path := save_path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if not file:
		_record_storage_error("无法写入临时存档：%s" % temporary_path, report_errors)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		_record_storage_error("写入存档失败：%s" % error_string(write_error), report_errors)
		return false
	return _replace_save_file(temporary_path, report_errors)


## 通过 ID 直接解锁成就。如果是新解锁则返回 true。
func unlock_achievement(achievement_id: String) -> bool:
	var result := try_unlock_achievement(achievement_id)
	_report_operation_failure(result)
	return bool(result.get("ok", false)) and bool(result.get("changed", false))


## 执行解锁并返回机器可读结果，不自行打印错误。供原子化运行时使用。
func try_unlock_achievement(achievement_id: String) -> Dictionary:
	if not _achievements.has(achievement_id):
		return _operation_failure(
			&"achievement.not_found",
			"未知成就 '%s'" % achievement_id,
			achievement_id,
			"achievement.unlock",
		)
	if _unlocked.get(achievement_id, false):
		return {"ok": true, "changed": false}
	_unlocked[achievement_id] = true
	if not _save_data(false):
		_unlocked.erase(achievement_id)
		return _storage_failure("achievement.unlock", achievement_id)
	_notify_unlocked(achievement_id)
	return {"ok": true, "changed": true}


## 增加计数器键值并自动检查相关成就。
func increment_progress(key: String, amount: float = 1.0) -> void:
	_report_operation_failure(try_increment_progress(key, amount))


## 执行进度变更并返回机器可读结果，不自行打印错误。
func try_increment_progress(key: String, amount: float = 1.0) -> Dictionary:
	if key.is_empty() or not is_finite(amount):
		return _operation_failure(
			&"achievement.progress_invalid",
			"无效计数进度 '%s'" % key,
			key,
			"achievement.progress",
			"progress_key",
		)
	var current_value: Variant = _progress.get(key, 0.0)
	if typeof(current_value) not in [TYPE_INT, TYPE_FLOAT]:
		return _operation_failure(
			&"achievement.progress_type_conflict",
			"计数键与现有标志键冲突：%s" % key,
			key,
			"achievement.progress",
			"progress_key",
		)
	var previous_progress: Dictionary = _progress.duplicate(true)
	var previous_unlocked: Dictionary = _unlocked.duplicate(true)
	_progress[key] = float(current_value) + amount
	var updated_achievements: Array[String] = []
	var newly_unlocked: Array[String] = []
	# 检查所有依赖于此键的成就
	for ach_id: String in _achievements:
		if _unlocked.get(ach_id, false):
			continue
		var ach: Dictionary = _achievements[ach_id]
		var cond: Dictionary = ach.get("conditions", {})
		if cond.get("target_key", "") == key:
			updated_achievements.append(ach_id)
			if _check_conditions(cond):
				_unlocked[ach_id] = true
				newly_unlocked.append(ach_id)
	if not _save_data(false):
		_progress = previous_progress
		_unlocked = previous_unlocked
		return _storage_failure("achievement.progress", key)
	for ach_id: String in updated_achievements:
		var cond: Dictionary = _achievements[ach_id].get("conditions", {})
		achievement_progress_updated.emit(
			ach_id, float(_progress[key]), float(cond.get("target_value", 0))
		)
	for ach_id: String in newly_unlocked:
		_notify_unlocked(ach_id)
	return {"ok": true, "changed": true}


## 设置标志键值并自动检查相关成就。
func set_flag(key: String, value: bool = true) -> void:
	_report_operation_failure(try_set_flag(key, value))


## 执行标志变更并返回机器可读结果，不自行打印错误。
func try_set_flag(key: String, value: bool = true) -> Dictionary:
	if key.is_empty():
		return _operation_failure(
			&"achievement.flag_invalid", "标志键不能为空", key, "achievement.flag", "flag_key"
		)
	var current_value: Variant = _progress.get(key)
	if current_value != null and not current_value is bool:
		return _operation_failure(
			&"achievement.flag_type_conflict",
			"标志键与现有计数键冲突：%s" % key,
			key,
			"achievement.flag",
			"flag_key",
		)
	var previous_progress: Dictionary = _progress.duplicate(true)
	var previous_unlocked: Dictionary = _unlocked.duplicate(true)
	_progress[key] = value
	var newly_unlocked: Array[String] = []
	for ach_id: String in _achievements:
		if _unlocked.get(ach_id, false):
			continue
		var ach: Dictionary = _achievements[ach_id]
		var cond: Dictionary = ach.get("conditions", {})
		if cond.get("target_key", "") == key:
			if _check_conditions(cond):
				_unlocked[ach_id] = true
				newly_unlocked.append(ach_id)
	if not _save_data(false):
		_progress = previous_progress
		_unlocked = previous_unlocked
		return _storage_failure("achievement.flag", key)
	for ach_id: String in newly_unlocked:
		_notify_unlocked(ach_id)
	return {"ok": true, "changed": true}


## 检查成就是否已解锁。
func is_unlocked(achievement_id: String) -> bool:
	return _unlocked.get(achievement_id, false)


## 获取单个成就的完整数据字典。
func get_achievement(achievement_id: String) -> Dictionary:
	var achievement: Dictionary = _achievements.get(achievement_id, {})
	return achievement.duplicate(true)


## 获取所有成就作为字典数组。
func get_all_achievements() -> Array:
	var result: Array = []
	for ach_id in _achievements:
		var d: Dictionary = _achievements[ach_id].duplicate(true)
		d["unlocked"] = _unlocked.get(ach_id, false)
		result.append(d)
	return result


## 仅获取已解锁的成就。
func get_unlocked_achievements() -> Array:
	return get_all_achievements().filter(func(a): return a["unlocked"])


## 仅获取未解锁的成就。
func get_locked_achievements() -> Array:
	return get_all_achievements().filter(func(a): return not a["unlocked"])


## 获取键的当前进度值。
func get_progress(key: String) -> float:
	return float(_progress.get(key, 0.0))


## 获取解锁百分比（0.0 到 1.0）。
func get_unlock_percentage() -> float:
	if _achievements.is_empty():
		return 0.0
	var unlocked_count := 0
	for ach_id in _achievements:
		if _unlocked.get(ach_id, false):
			unlocked_count += 1
	return float(unlocked_count) / float(_achievements.size())


## 重置所有成就和进度
func reset_all() -> void:
	print("重置所有成就")
	var previous_unlocked: Dictionary = _unlocked.duplicate(true)
	var previous_progress: Dictionary = _progress.duplicate(true)
	_unlocked.clear()
	_progress.clear()
	if not _save_data():
		_unlocked = previous_unlocked
		_progress = previous_progress
		return
	achievements_reset.emit()


## 重置单个成就
func reset_achievement(achievement_id: String) -> void:
	if not _achievements.has(achievement_id):
		push_warning("KonadoAchievement 未知成就：%s" % achievement_id)
		return
	var was_unlocked: bool = _unlocked.get(achievement_id, false)
	if not was_unlocked:
		return
	_unlocked.erase(achievement_id)
	if not _save_data():
		_unlocked[achievement_id] = true
		return
	achievement_reset.emit(achievement_id)


## 从 JSON 重新加载配置
func reload_config() -> void:
	_load_config()
	_load_save_data()
	achievements_loaded.emit()


# 弹出成就
func _show_popup(ach_data: Dictionary) -> void:
	if not _popup_scene:
		return
	# 关闭现有弹出
	_dismiss_popup()
	_active_popup = _popup_scene.instantiate()
	_popup_canvas_layer.add_child(_active_popup)
	# 设置弹出内容
	if _active_popup.has_method("setup"):
		var icon_path: String = ach_data.get("icon", "")
		if icon_path.is_empty():
			icon_path = "res://addons/konado_achievement/assets/icons/default_icon.svg"
		_active_popup.setup(
			ach_data.get("name", ""),
			ach_data.get("description", ""),
			icon_path,
			_valid_popup_position()
		)
	# 自动关闭计时器
	if _popup_timer:
		_popup_timer.queue_free()
	_popup_timer = Timer.new()
	_popup_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_popup_timer.wait_time = maxf(popup_duration, 0.1)
	_popup_timer.one_shot = true
	_popup_timer.timeout.connect(_dismiss_popup)
	add_child(_popup_timer)
	_popup_timer.start()


func _dismiss_popup() -> void:
	if _popup_timer and is_instance_valid(_popup_timer):
		_popup_timer.stop()
		_popup_timer.queue_free()
		_popup_timer = null
	if _active_popup and is_instance_valid(_active_popup):
		_active_popup.queue_free()
		_active_popup = null


# 弹出成就列表
func show_panel() -> void:
	_focus_change_generation += 1
	if _active_panel and is_instance_valid(_active_panel):
		_remember_focus_owner()
		_active_panel.visible = true
		if _active_panel.has_method("refresh"):
			_active_panel.refresh()
		if _active_panel.has_method("focus_close_button"):
			_active_panel.focus_close_button()
		return
	if not _panel_scene:
		push_error("KonadoAchievement 无法显示成就面板：面板场景未加载。")
		return
	_active_panel = _panel_scene.instantiate()
	if _active_panel.has_method("setup"):
		_active_panel.setup(self)
	_remember_focus_owner()
	_panel_canvas_layer.add_child(_active_panel)
	if _active_panel.has_method("refresh"):
		_active_panel.refresh()
	if _active_panel.has_method("focus_close_button"):
		_active_panel.focus_close_button()


func hide_panel() -> void:
	if _active_panel and is_instance_valid(_active_panel):
		_active_panel.visible = false
		_focus_change_generation += 1
		_restore_focus_owner(_focus_change_generation)


func toggle_panel() -> void:
	if is_panel_visible():
		hide_panel()
	else:
		show_panel()


func is_panel_visible() -> bool:
	return _active_panel != null and is_instance_valid(_active_panel) and _active_panel.visible


func _create_canvas_layer(layer_name: String, layer_index: int) -> CanvasLayer:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = layer_name
	canvas_layer.layer = layer_index
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas_layer)
	return canvas_layer


func _remember_focus_owner() -> void:
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner == null:
		return
	if focus_owner != _active_panel and not _active_panel.is_ancestor_of(focus_owner):
		_previous_focus_owner = focus_owner


func _restore_focus_owner(generation: int) -> void:
	await get_tree().process_frame
	if generation != _focus_change_generation or is_panel_visible():
		return
	var current_focus_owner := get_viewport().gui_get_focus_owner()
	if (
		current_focus_owner != null
		and current_focus_owner != _active_panel
		and not _active_panel.is_ancestor_of(current_focus_owner)
	):
		_previous_focus_owner = null
		return
	if _previous_focus_owner and is_instance_valid(_previous_focus_owner):
		_previous_focus_owner.grab_focus()
	_previous_focus_owner = null


## 判断成就条件
func _check_conditions(cond: Dictionary) -> bool:
	var cond_type: String = cond.get("type", "flag")
	var key: String = cond.get("target_key", "")
	var target = cond.get("target_value", 0)
	match cond_type:
		"counter":
			return _progress.get(key, 0.0) >= float(target)
		"flag":
			return _progress.get(key, false) == target
		_:
			return false


func _is_valid_achievement(entry: Variant, index: int) -> bool:
	var problem: String = ""
	if not entry is Dictionary:
		problem = "非对象配置项，索引：%d" % index
	else:
		var achievement_id: Variant = entry.get("id")
		var conditions: Variant = entry.get("conditions")
		if not achievement_id is String or achievement_id.is_empty():
			problem = "缺少有效 ID 的配置项，索引：%d" % index
		elif not conditions is Dictionary:
			problem = "缺少 conditions 的成就：%s" % achievement_id
		else:
			var condition_type: Variant = conditions.get("type")
			var target_key: Variant = conditions.get("target_key")
			var target_value: Variant = conditions.get("target_value")
			if condition_type not in ["counter", "flag"]:
				problem = "条件类型无效的成就：%s" % achievement_id
			elif not target_key is String or target_key.is_empty():
				problem = "target_key 无效的成就：%s" % achievement_id
			elif condition_type == "counter" and typeof(target_value) not in [TYPE_INT, TYPE_FLOAT]:
				problem = "计数目标无效的成就：%s" % achievement_id
			elif condition_type == "flag" and not target_value is bool:
				problem = "标志目标无效的成就：%s" % achievement_id
			else:
				problem = _get_achievement_metadata_problem(entry, achievement_id)
	if not problem.is_empty():
		push_warning("KonadoAchievement 忽略%s" % problem)
		return false
	return true


func _get_achievement_metadata_problem(entry: Dictionary, achievement_id: String) -> String:
	for field: String in ["name", "description", "icon", "category"]:
		if entry.has(field) and not entry[field] is String:
			return "%s 字段无效的成就：%s" % [field, achievement_id]
	if entry.has("hidden") and not entry["hidden"] is bool:
		return "hidden 字段无效的成就：%s" % achievement_id
	if entry.has("points") and typeof(entry["points"]) not in [TYPE_INT, TYPE_FLOAT]:
		return "points 字段无效的成就：%s" % achievement_id
	return ""


func _apply_save_data(data: Variant, source: String) -> bool:
	if not data is Dictionary:
		push_warning("KonadoAchievement 存档根节点无效：%s" % source)
		return false
	var unlocked: Variant = data.get("unlocked", {})
	var progress: Variant = data.get("progress", {})
	if not unlocked is Dictionary or not progress is Dictionary:
		push_warning("KonadoAchievement 存档结构无效：%s" % source)
		return false
	var valid_unlocked: Dictionary = {}
	for achievement_id: Variant in unlocked:
		if (
			achievement_id is String
			and _achievements.has(achievement_id)
			and unlocked[achievement_id] is bool
		):
			valid_unlocked[achievement_id] = unlocked[achievement_id]
	var valid_progress: Dictionary = {}
	for key: Variant in progress:
		var value: Variant = progress[key]
		if key is String and typeof(value) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT]:
			valid_progress[key] = value
	_unlocked = valid_unlocked
	_progress = valid_progress
	return true


func _load_backup_save() -> void:
	var backup_path := save_path + ".bak"
	var file := FileAccess.open(backup_path, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err == OK and _apply_save_data(json.data, backup_path):
		push_warning("KonadoAchievement 已从备份存档恢复。")


func _replace_save_file(temporary_path: String, report_errors := true) -> bool:
	var backup_path := save_path + ".bak"
	var absolute_save := ProjectSettings.globalize_path(save_path)
	var absolute_temporary := ProjectSettings.globalize_path(temporary_path)
	var absolute_backup := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup)
	if FileAccess.file_exists(save_path):
		var backup_error := DirAccess.rename_absolute(absolute_save, absolute_backup)
		if backup_error != OK:
			_record_storage_error("无法创建存档备份：%s" % error_string(backup_error), report_errors)
			DirAccess.remove_absolute(absolute_temporary)
			return false
	var replace_error := DirAccess.rename_absolute(absolute_temporary, absolute_save)
	if replace_error != OK:
		_record_storage_error("无法替换存档：%s" % error_string(replace_error), report_errors)
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup, absolute_save)
		return false
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup)
	return true


func _record_storage_error(message: String, report_errors: bool) -> void:
	_last_storage_error = message
	if report_errors:
		push_error("KonadoAchievement %s" % message)


func _storage_failure(operation: String, resource_id: String) -> Dictionary:
	var resource_kind := "achievement"
	if operation == "achievement.progress":
		resource_kind = "progress_key"
	elif operation == "achievement.flag":
		resource_kind = "flag_key"
	return _operation_failure(
		&"achievement.storage_failed",
		_last_storage_error if not _last_storage_error.is_empty() else "成就存档写入失败",
		resource_id,
		operation,
		resource_kind,
	)


func _operation_failure(
	code: StringName,
	message: String,
	resource_id: String,
	operation: String,
	resource_kind := "achievement",
) -> Dictionary:
	return {
		"ok": false,
		"code": String(code),
		"message": message,
		"subsystem": "achievement",
		"operation": operation,
		"resource_kind": resource_kind,
		"resource_id": resource_id,
	}


func _report_operation_failure(result: Dictionary) -> void:
	if bool(result.get("ok", false)):
		return
	var message := "KonadoAchievement %s" % String(result.get("message", "操作失败"))
	if String(result.get("code", "")) == "achievement.storage_failed":
		push_error(message)
	else:
		push_warning(message)


func _notify_unlocked(achievement_id: String) -> void:
	var achievement_data: Dictionary = get_achievement(achievement_id)
	achievement_unlocked.emit(achievement_id, achievement_data)
	_show_popup(achievement_data)
	if on_external_unlock.is_valid():
		on_external_unlock.call(achievement_id, achievement_data.duplicate(true))


func _valid_popup_position() -> String:
	if popup_position in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		return popup_position
	push_warning("KonadoAchievement 弹窗位置无效，已回退到 top_left：%s" % popup_position)
	return "top_left"
