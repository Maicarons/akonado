extends Control

# 这一部分非插件内容，为demo演示所需，使用音效信号修改自定义游戏数据
func _on_konado_dialogue_manager_play_sfx(se_name: Variant) -> void:
	if se_name == "好感度上升":
		$KonadoDialogueManager.dialogue_variables["love"] += 1
