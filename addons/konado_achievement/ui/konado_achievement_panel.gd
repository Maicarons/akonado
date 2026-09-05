extends PanelContainer

## 成就概览面板

var _grid: GridContainer
var _close_btn: Button
var _title_label: Label
var _progress_label: Label
var _scroll: ScrollContainer
var _item_container: VBoxContainer
var _reset_btn: Button
var _achievement_manager: Node


func setup(achievement_manager: Node) -> void:
	_achievement_manager = achievement_manager


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _achievement_manager == null:
		_achievement_manager = get_tree().root.get_node_or_null("KonadoAchievements")
	if _achievement_manager == null:
		push_error("KonadoAchievement 成就面板缺少管理器。")
		queue_free()
		return
	anchors_preset = Control.PRESET_FULL_RECT
	anchor_right = 1.0
	anchor_bottom = 1.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.92)
	style.content_margin_left = 50
	style.content_margin_right = 50
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	add_theme_stylebox_override("panel", style)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 16)
	add_child(root_vbox)

	# 标题行
	var header := HBoxContainer.new()
	root_vbox.add_child(header)

	_title_label = Label.new()
	_title_label.text = tr("KONADO_ACHIEVEMENTS")
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(0.85, 0.7, 0.2))
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 16)
	_progress_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	header.add_child(_progress_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(16, 0)
	header.add_child(spacer)

	_close_btn = Button.new()
	_close_btn.text = " X "
	_close_btn.pressed.connect(_on_close)
	header.add_child(_close_btn)

	_reset_btn = Button.new()
	_reset_btn.text = tr("KONADO_ACHIEVEMENTS_RESET")
	_reset_btn.pressed.connect(func(): _achievement_manager.reset_all())
	header.add_child(_reset_btn)

	# 分隔符
	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	# 滚动区域
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_scroll)

	_item_container = VBoxContainer.new()
	_item_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_container.add_theme_constant_override("separation", 8)
	_scroll.add_child(_item_container)

	_achievement_manager.achievement_unlocked.connect(_on_achievement_changed)
	_achievement_manager.achievement_progress_updated.connect(_on_progress_changed)
	_achievement_manager.achievement_reset.connect(_on_achievement_reset)
	_achievement_manager.achievements_reset.connect(refresh)
	_achievement_manager.achievements_loaded.connect(refresh)
	refresh()


func refresh() -> void:
	if not _item_container:
		return
	# 清除现有项目
	for child in _item_container.get_children():
		child.queue_free()

	var all_achs: Array = _achievement_manager.get_all_achievements()
	var unlocked_count := 0

	for ach in all_achs:
		var is_unlocked: bool = ach.get("unlocked", false)
		if is_unlocked:
			unlocked_count += 1
		var is_hidden: bool = ach.get("hidden", false)

		var item := _create_item(ach, is_unlocked, is_hidden)
		_item_container.add_child(item)

	if _progress_label:
		_progress_label.text = (
			"%d / %d (%d%%)"
			% [
				unlocked_count,
				all_achs.size(),
				int(float(unlocked_count) / max(all_achs.size(), 1) * 100)
			]
		)


func _create_item(ach: Dictionary, is_unlocked: bool, is_hidden: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	var bg := StyleBoxFlat.new()
	bg.corner_radius_top_left = 6
	bg.corner_radius_top_right = 6
	bg.corner_radius_bottom_left = 6
	bg.corner_radius_bottom_right = 6
	bg.content_margin_left = 12
	bg.content_margin_right = 12
	bg.content_margin_top = 8
	bg.content_margin_bottom = 8

	if is_unlocked:
		bg.bg_color = Color(0.15, 0.18, 0.12, 0.9)
		bg.border_color = Color(0.5, 0.7, 0.2, 0.8)
	else:
		bg.bg_color = Color(0.14, 0.14, 0.16, 0.7)
		bg.border_color = Color(0.3, 0.3, 0.3, 0.5)
	bg.border_width_bottom = 1
	bg.border_width_top = 1
	bg.border_width_left = 1
	bg.border_width_right = 1
	panel.add_theme_stylebox_override("panel", bg)

	var horizontal_container := HBoxContainer.new()
	horizontal_container.add_theme_constant_override("separation", 12)
	panel.add_child(horizontal_container)

	# 图标
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(40, 40)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	var icon_path: String = ach.get("icon", "")
	if icon_path.is_empty():
		icon_path = "res://addons/konado_achievement/assets/icons/default_icon.svg"
	if ResourceLoader.exists(icon_path):
		icon_rect.texture = load(icon_path)
	if not is_unlocked:
		icon_rect.modulate = Color(0.3, 0.3, 0.3)
	horizontal_container.add_child(icon_rect)

	# 文本信息
	var vertical_container := VBoxContainer.new()
	vertical_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	horizontal_container.add_child(vertical_container)

	var name_label := Label.new()
	if is_hidden and not is_unlocked:
		name_label.text = "???"
	else:
		name_label.text = tr(str(ach.get("name", "KONADO_UNKNOWN")))
	name_label.add_theme_font_size_override("font_size", 15)
	if is_unlocked:
		name_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vertical_container.add_child(name_label)

	var description_label := Label.new()
	if is_hidden and not is_unlocked:
		description_label.text = tr("KONADO_ACHIEVEMENT_HIDDEN")
	else:
		description_label.text = tr(str(ach.get("description", "")))
	description_label.add_theme_font_size_override("font_size", 12)
	description_label.add_theme_color_override(
		"font_color", Color(0.55, 0.55, 0.55) if not is_unlocked else Color(0.75, 0.75, 0.75)
	)
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vertical_container.add_child(description_label)

	# 点数徽章
	var pts := ach.get("points", 0)
	if pts > 0:
		var pts_label := Label.new()
		pts_label.text = tr("KONADO_ACHIEVEMENT_POINTS") % pts
		pts_label.add_theme_font_size_override("font_size", 13)
		pts_label.add_theme_color_override(
			"font_color", Color(0.85, 0.7, 0.2) if is_unlocked else Color(0.4, 0.4, 0.4)
		)
		horizontal_container.add_child(pts_label)

	# 状态指示器
	var status := Label.new()
	status.text = (
		tr("KONADO_ACHIEVEMENT_UNLOCKED") if is_unlocked else tr("KONADO_ACHIEVEMENT_LOCKED")
	)
	status.add_theme_font_size_override("font_size", 11)
	status.add_theme_color_override(
		"font_color", Color(0.4, 0.8, 0.2) if is_unlocked else Color(0.5, 0.5, 0.5)
	)
	horizontal_container.add_child(status)

	return panel


func _on_close() -> void:
	_achievement_manager.hide_panel()


func focus_close_button() -> void:
	_grab_close_button_focus.call_deferred()


func _grab_close_button_focus() -> void:
	if visible and _close_btn and is_instance_valid(_close_btn) and _close_btn.is_visible_in_tree():
		_close_btn.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()


func _on_achievement_changed(_achievement_id: String, _data: Dictionary) -> void:
	refresh()


func _on_progress_changed(_achievement_id: String, _current: float, _target: float) -> void:
	refresh()


func _on_achievement_reset(_achievement_id: String) -> void:
	refresh()


func _notification(what: int) -> void:
	if what != NOTIFICATION_TRANSLATION_CHANGED or not is_node_ready():
		return
	_title_label.text = tr("KONADO_ACHIEVEMENTS")
	_reset_btn.text = tr("KONADO_ACHIEVEMENTS_RESET")
	refresh()
