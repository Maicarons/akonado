extends Control

@export var dialogue_manager: KonadoDialogueManager


func _ready() -> void:
	if dialogue_manager:
		dialogue_manager.custom_signal.connect(_on_konado_dialogue_manager_play_sfx)
		# 可以在脚本中同步外部变量
		var store = KonadoVariableStore.new()
		store.set_value("love", 0)
		dialogue_manager.variable_store = store
	else:
		printerr("未指定demo dialogue_manager")


# 这一部分非插件内容，为demo演示所需
func _on_konado_dialogue_manager_play_sfx(content: Variant) -> void:
	if content == "好感度上升":
		if dialogue_manager.variable_store:
			dialogue_manager.variable_store.apply_operation(
				"love", KonadoVariableStore.Operation.ADD, 1
			)
