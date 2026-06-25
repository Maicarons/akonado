@tool
extends Button
class_name SaveComponent

@onready var name_label      : Label = %name_label
@onready var save_time_label : Label = %save_time_label
@onready var game_time_label : Label = %game_time_label
@onready var quicksave_sign   : Label = $quicksave_sign
@export var save_btn: Button
@export var load_btn: Button
@export var del_btn: Button

## 存档ID
@export var save_id: int = -1;

@export var save_name := "存档":  ## 存档名称
	set(value):
		if save_name  != value:
			save_name = value
			if name_label:
				name_label.text=value

@export var save_time := "2025/8/25/12:02":
	set(value):
		if save_time  != value:
			save_time = value
			if save_time_label:
				save_time_label.text=value

@export var game_time := " 3h 2min":
	set(value):
		if game_time  != value:
			game_time = value
			if game_time_label:
				game_time_label.text=value

## 存档系统引用
var save_system: KND_SaveSystem

func _ready() -> void:
	name_label.text = save_name
	save_time_label.text  = save_time
	game_time_label.text = game_time  # 补充原有遗漏的游戏时长标签初始化
	
	# 槽位0始终显示快速保存标识
	var is_quick_save_slot = (save_id == 0)
	quicksave_sign.visible = is_quick_save_slot
	
	# 连接按钮信号
	if save_btn:
		save_btn.pressed.connect(_on_save_pressed)
	if load_btn:
		load_btn.pressed.connect(_on_load_pressed)
	if del_btn:
		del_btn.pressed.connect(_on_delete_pressed)

func init_empty_save_slot() -> void:
	if save_id == 0:
		save_name = "快速保存"
	else:
		save_name = "空存档"
	save_time = "--/--/-- --:--" 
	game_time = "0h 0min"

## 设置存档系统
func set_save_system(system: KND_SaveSystem) -> void:
	save_system = system

## 更新存档信息
func update_save_info(info: Dictionary) -> void:
	if info and info.exists:
		# 格式化存档时间
		var save_time_dict = info.get("save_time", {})
		if save_time_dict:
			var year = save_time_dict.get("year", "--")
			var month = str("%02d" % save_time_dict.get("month", 0))
			var day = str("%02d" % save_time_dict.get("day", 0))
			var hour = str("%02d" % save_time_dict.get("hour", 0))
			var minute = str("%02d" % save_time_dict.get("minute", 0))
			save_time = "%s/%s/%s %s:%s" % [year, month, day, hour, minute]
		else:
			save_time = "未知时间"
		
		# 设置游戏时长（暂时使用固定值，可根据实际情况修改）
		game_time = "0h 0min"
		
		# 设置存档名称
		if save_id == 0:
			save_name = "快速保存"
		else:
			save_name = "存档%02d" % (save_id + 1)
	else:
		# 空存档
		init_empty_save_slot()

## 保存游戏
func _on_save_pressed() -> void:
	if save_system and save_id >= 0:
		print("保存到存档槽 %d" % save_id)
		var success = save_system.save_game(save_id)
		if success:
			# 更新存档信息
			var info = save_system.get_save_info(save_id)
			update_save_info(info)
			print("保存成功")
		else:
			print("保存失败")
	else:
		print("未设置存档管理器")

## 加载游戏
func _on_load_pressed() -> void:
	if save_system and save_id >= 0:
		print("加载存档槽 %d" % save_id)
		var success = save_system.load_game(save_id)
		if success:
			print("加载成功")
		else:
			print("加载失败")

## 删除存档
func _on_delete_pressed() -> void:
	if save_system and save_id >= 0:
		print("删除存档槽 %d" % save_id)
		var success = save_system.delete_save(save_id)
		if success:
			# 重置为空白存档
			init_empty_save_slot()
			print("删除成功")
		else:
			print("删除失败")
	
