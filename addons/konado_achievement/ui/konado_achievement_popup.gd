extends PanelContainer

## 成就解锁弹出通知。

var _title_label: Label
var _desc_label: Label
var _icon_rect: TextureRect
var _header_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(320, 80)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.16, 0.95)
	style.border_color = Color(0.85, 0.7, 0.2, 1.0)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

	var horizontal_container := HBoxContainer.new()
	horizontal_container.add_theme_constant_override("separation", 12)
	add_child(horizontal_container)

	_icon_rect = TextureRect.new()
	_icon_rect.custom_minimum_size = Vector2(48, 48)
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	horizontal_container.add_child(_icon_rect)

	var vertical_container := VBoxContainer.new()
	vertical_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	horizontal_container.add_child(vertical_container)

	_header_label = Label.new()
	_header_label.text = tr("KONADO_ACHIEVEMENT_UNLOCKED_TITLE")
	_header_label.add_theme_font_size_override("font_size", 11)
	_header_label.add_theme_color_override("font_color", Color(0.85, 0.7, 0.2))
	vertical_container.add_child(_header_label)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	vertical_container.add_child(_title_label)

	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 12)
	_desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vertical_container.add_child(_desc_label)


func setup(
	title: String, description: String, icon_path: String, pos: String = "top_right"
) -> void:
	if _title_label:
		_title_label.text = tr(title)
	if _desc_label:
		_desc_label.text = tr(description)
	if _icon_rect and ResourceLoader.exists(icon_path):
		_icon_rect.texture = load(icon_path)
	if get_tree() == null:
		printerr("过早调用")
		return
	# 在屏幕上定位
	await get_tree().process_frame
	_apply_position(pos)
	# 动画进入
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_header_label.text = tr("KONADO_ACHIEVEMENT_UNLOCKED_TITLE")


func _apply_position(pos: String) -> void:
	var vp_size := get_viewport_rect().size
	var margin := 20.0
	match pos:
		"top_left":
			position = Vector2(margin, margin)
		"top_right":
			position = Vector2(vp_size.x - size.x - margin, margin)
		"bottom_left":
			position = Vector2(margin, vp_size.y - size.y - margin)
		"bottom_right":
			position = Vector2(vp_size.x - size.x - margin, vp_size.y - size.y - margin)
		_:
			position = Vector2(vp_size.x - size.x - margin, margin)
