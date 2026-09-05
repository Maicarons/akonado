extends Node

## 对话选项UI接口

## 完成创建选项的信号
signal finish_display_options

## 对话选项按钮容器
@export var _choice_container: Container

var _display_generation: int = 0


## 初始化对话框
func init_dialog_box() -> void:
	distroy_options()


func distroy_options() -> void:
	_display_generation += 1
	# 隐藏选项容器
	_choice_container.hide()
	# 删除原有选项
	if _choice_container.get_child_count() != 0:
		for child in _choice_container.get_children():
			child.hide()
			if child is BaseButton:
				child.disabled = true
			child.queue_free()


## 显示对话选项的方法
func display_options(
	choices: Array[Dictionary],
	manager: KonadoDialogueManager,
	choices_font_size: int = 32,
	playback_generation: int = -1
) -> void:
	distroy_options()
	var display_generation := _display_generation

	var tmp_list: Array[Button] = []

	# 生成新选项
	for choice in choices:
		var choice_button: Button = Button.new()
		# 选项文本内容
		choice_button.set_text(String(choice.get("text", "")))
		choice_button.add_theme_font_size_override("font_size", int(choices_font_size))
		# 选项触发
		choice_button.pressed.connect(
			func():
				if choice_button.disabled or display_generation != _display_generation:
					return
				# Claim this presentation synchronously. This invalidates every
				# other button from the same presentation before the deferred
				# callback runs.
				_display_generation += 1
				var claimed_generation := _display_generation
				choice_button.disabled = true
				await get_tree().process_frame
				if not is_instance_valid(manager) or claimed_generation != _display_generation:
					return
				manager._on_option_triggered(choice, playback_generation)
				print_rich("[color=green]选项被触发: [/color]" + str(choice))
		)
		choice_button.gui_input.connect(
			func(event: InputEvent):
				if event.is_action_pressed("ui_accept") || event.is_action_pressed("ui_select"):
					choice_button.pressed.emit()
		)
		# 添加到选项容器
		_choice_container.add_child(choice_button)
		print_rich("[color=cyan]生成选项按钮: [/color]" + str(choice_button))

		tmp_list.append(choice_button)

	# 显示选项容器
	_choice_container.show()

	var list_size = tmp_list.size()

	for index in range(list_size):
		var c = tmp_list[index]
		var tc = tmp_list[index - 1]
		c.set_focus_neighbor(SIDE_TOP, tc.get_path())
		if index < list_size - 1:
			var bc = tmp_list[index + 1]
			c.set_focus_neighbor(SIDE_BOTTOM, bc.get_path())
		if index == list_size - 1:
			var bc = tmp_list[0]
			c.set_focus_neighbor(SIDE_BOTTOM, bc.get_path())

	# 自动焦点
	if tmp_list.size() > 0:
		tmp_list[0].grab_focus.call_deferred()
