extends Control

## 主菜单脚本
## 点击"开始游戏"跳转到 demo 场景，点击"退出游戏"关闭应用

@export var quit_button: Button


func _ready() -> void:
	if OS.has_feature("web"):
		quit_button.hide()


func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://sample/demo/demo.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()
