extends ColorRect
class_name KonadoScreenText

## NVL 屏幕文本组件（Overlay 正文）
## 每行使用独立的 RichTextLabel，逐行淡入，点击后播放下一条

## 信号：屏幕文本整体淡入完成
signal screen_text_shown
## 信号：屏幕文本整体淡出完成
signal screen_text_hidden
## 信号：点击屏幕文本
signal screen_text_clicked
## 信号：所有行播放完成
signal display_finished

enum PresentationState { IDLE, DISPLAYING, HIDING }

## 下一行指示器（三角箭头）
@export var next_line_indicator: TextureRect

## 字体大小
@export var font_size: int = 36
## 文本颜色
@export var text_color: Color = Color.WHITE

## 左间距
@export var left_padding: float = 200
## 上间距
@export var top_padding: float = 200
## 行间距
@export var line_spacing: float = 8.0

@export var fade_duration: float = 0.5
@export var fade_trans_type: Tween.TransitionType = Tween.TRANS_SINE
@export var fade_ease_type: Tween.EaseType = Tween.EASE_IN_OUT

## 每行淡入动画时长
@export var line_fade_duration: float = 0.3
## 指示器闪烁频率（一次完整明灭周期秒数）
@export var blink_cycle: float = 0.8
## 指示器闪烁最低透明度
@export var blink_min_alpha: float = 0.15
## 指示器相对行标签右下角的偏移
@export var indicator_offset: Vector2 = Vector2(0, 0)

var _fade_tween: Tween = null
var _line_tween: Tween = null
var _blink_tween: Tween = null

var _line_labels: Array[RichTextLabel] = []
var _current_lines: Array[String] = []
var _current_align: String = "left"
var _line_index: int = 0
var _total_lines: int = 0
var _is_waiting_input: bool = false
var _display_generation: int = 0
var _auto_hide_on_finish: bool = false
var _presentation_state := PresentationState.IDLE


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	modulate.a = 0.0
	hide()
	if next_line_indicator:
		next_line_indicator.hide()


## 显示 NVL 文本内容
## text_lines: 文本行列表
## align: 对齐方式（"left"/"center"/"right"）
## auto_hide: 全部行播放完成后是否自动隐藏（默认为 false，此时需由调用方显式隐藏）
func display(text_lines: Array[String], align: String = "center", auto_hide: bool = false) -> void:
	_display_generation += 1
	var display_generation := _display_generation
	_cancel_display_activity()
	_auto_hide_on_finish = auto_hide
	_presentation_state = PresentationState.DISPLAYING
	hide()
	_current_align = align
	_line_index = 0
	_build_text(text_lines, align)
	_current_lines = text_lines
	# 等待一帧让标签完成布局，再读取实际高度修正位置
	await get_tree().process_frame
	if display_generation != _display_generation:
		return
	_adjust_layout()
	show_screen_text()


## 显示屏幕文本（带淡入动画），淡入完成后自动开始第一行
func show_screen_text() -> void:
	var display_generation := _display_generation
	if _presentation_state == PresentationState.HIDING:
		_presentation_state = (
			PresentationState.DISPLAYING if _line_index < _total_lines else PresentationState.IDLE
		)
	elif _presentation_state == PresentationState.IDLE and _line_index < _total_lines:
		_presentation_state = PresentationState.DISPLAYING
	show()
	modulate.a = 0.0

	_kill_fade_tween()

	_fade_tween = create_tween()
	_fade_tween.set_trans(fade_trans_type)
	_fade_tween.set_ease(fade_ease_type)
	_fade_tween.tween_property(self, "modulate:a", 1.0, fade_duration)
	_fade_tween.tween_callback(
		func():
			if display_generation != _display_generation:
				return
			screen_text_shown.emit()
			_reveal_current_line(display_generation)
	)


## 隐藏屏幕文本（带淡出动画），完成后发射 screen_text_hidden
func hide_screen_text() -> void:
	if _presentation_state == PresentationState.HIDING:
		return
	_display_generation += 1
	var display_generation := _display_generation
	_presentation_state = PresentationState.HIDING
	_auto_hide_on_finish = false
	_cancel_display_activity()

	_fade_tween = create_tween()
	_fade_tween.set_trans(fade_trans_type)
	_fade_tween.set_ease(fade_ease_type)
	_fade_tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	_fade_tween.tween_callback(
		func():
			if display_generation != _display_generation:
				return
			_presentation_state = PresentationState.IDLE
			hide()
			modulate.a = 1.0
			_clear_text()
			screen_text_hidden.emit()
	)


## 立即取消当前显示流程并清除仅属于当前镜头的屏幕文本。
func reset_screen_text() -> void:
	_display_generation += 1
	_presentation_state = PresentationState.IDLE
	_auto_hide_on_finish = false
	_cancel_display_activity()
	hide()
	modulate.a = 1.0
	_clear_text()


## Cancel callbacks and tweens while preserving the last committed visual state.
func cancel_pending_operations() -> void:
	_display_generation += 1
	_presentation_state = PresentationState.IDLE
	_auto_hide_on_finish = false
	_cancel_display_activity()
	modulate.a = 1.0


func capture_state() -> Dictionary:
	return {
		"lines": _current_lines.duplicate(),
		"align": _current_align,
		"line_index": _line_index,
		"visible": visible,
	}


func restore_state(state: Dictionary) -> bool:
	reset_screen_text()
	if state.is_empty() or not bool(state.get("visible", false)):
		return true
	var lines: Array[String] = []
	lines.assign(state.get("lines", []))
	_current_align = String(state.get("align", "center"))
	_line_index = clampi(int(state.get("line_index", 0)), 0, lines.size())
	_build_text(lines, _current_align)
	_current_lines = lines
	_presentation_state = PresentationState.IDLE
	show()
	modulate.a = 1.0
	for index in range(_line_labels.size()):
		_line_labels[index].modulate.a = 1.0 if index < _line_index else 0.0
	return true


## 跳过逐行淡入动画，直接显示所有文本并发射完成信号
func skip_display() -> void:
	if _presentation_state != PresentationState.DISPLAYING:
		return
	_kill_line_tween()
	_kill_blink_tween()
	_is_waiting_input = false
	if next_line_indicator:
		next_line_indicator.hide()
	for label in _line_labels:
		label.show()
		label.modulate.a = 1.0
	_line_index = _total_lines
	_finish_display(_display_generation)


## 播放完成统一出口：发射 display_finished，并按需自动隐藏
func _finish_display(display_generation: int) -> void:
	if (
		display_generation != _display_generation
		or _presentation_state != PresentationState.DISPLAYING
	):
		return
	_presentation_state = PresentationState.IDLE
	var auto_hide := _auto_hide_on_finish
	_auto_hide_on_finish = false
	display_finished.emit()
	if display_generation != _display_generation:
		return
	if auto_hide:
		hide_screen_text()


## 淡入当前行
func _reveal_current_line(display_generation: int = _display_generation) -> void:
	if display_generation != _display_generation:
		return
	if _line_index >= _total_lines:
		_finish_display(display_generation)
		return

	var label := _line_labels[_line_index]
	label.modulate.a = 0.0
	label.show()

	_kill_line_tween()

	_line_tween = create_tween()
	_line_tween.set_trans(Tween.TRANS_LINEAR)
	_line_tween.set_ease(Tween.EASE_IN)
	_line_tween.tween_property(label, "modulate:a", 1.0, line_fade_duration)
	_line_tween.tween_callback(
		func():
			if display_generation != _display_generation:
				return
			_line_index += 1
			_show_indicator(display_generation)
	)


## 显示闪烁指示器，等待用户点击
func _show_indicator(display_generation: int = _display_generation) -> void:
	if (
		display_generation != _display_generation
		or _line_index <= 0
		or _line_index > _line_labels.size()
	):
		return
	_is_waiting_input = true
	if next_line_indicator == null:
		return

	var last_label := _line_labels[_line_index - 1]

	next_line_indicator.position = Vector2(
		last_label.position.x + last_label.size.x + indicator_offset.x,
		last_label.position.y + last_label.size.y + indicator_offset.y
	)

	next_line_indicator.show()
	next_line_indicator.modulate.a = 1.0

	_kill_blink_tween()
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(
		next_line_indicator, "modulate:a", blink_min_alpha, blink_cycle * 0.5
	)
	_blink_tween.tween_property(next_line_indicator, "modulate:a", 1.0, blink_cycle * 0.5)


## 隐藏指示器
func _hide_indicator() -> void:
	_kill_blink_tween()
	if next_line_indicator:
		next_line_indicator.hide()


## 用户点击响应
func _on_click_advance() -> void:
	if not _is_waiting_input:
		return

	_is_waiting_input = false
	_hide_indicator()

	if _line_index >= _total_lines:
		_finish_display(_display_generation)
	else:
		_reveal_current_line(_display_generation)


func _build_text(text_lines: Array[String], align: String) -> void:
	_clear_text()

	_total_lines = text_lines.size()
	if _total_lines == 0:
		return

	for i in range(_total_lines):
		var label := RichTextLabel.new()
		label.name = "Line_%d" % i
		label.text = text_lines[i]

		# 样式
		label.add_theme_font_size_override("normal_font_size", font_size)
		label.add_theme_color_override("default_color", text_color)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		# 对齐
		match align:
			"center":
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			"right":
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_:
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

		label.position = Vector2(left_padding, 0)
		label.fit_content = true
		label.custom_maximum_size.x = size.x - left_padding
		label.mouse_filter = MOUSE_FILTER_IGNORE

		# 初始隐藏
		label.modulate.a = 0.0
		label.hide()

		add_child(label)
		_line_labels.append(label)


## 在标签完成布局后修正每行的实际高度和 Y 位置
func _adjust_layout() -> void:
	var y := top_padding
	for label in _line_labels:
		label.position.y = y
		label.size.y = label.get_content_height()
		y += label.size.y + line_spacing


func _clear_text() -> void:
	_current_lines = []
	_line_index = 0
	_total_lines = 0
	for label in _line_labels:
		label.queue_free()
	_line_labels.clear()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		_on_click_advance()
		screen_text_clicked.emit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		_on_click_advance()
		screen_text_clicked.emit()


func _kill_fade_tween() -> void:
	if _fade_tween != null and _fade_tween.is_running():
		_fade_tween.kill()
	_fade_tween = null


func _kill_line_tween() -> void:
	if _line_tween != null and _line_tween.is_running():
		_line_tween.kill()
	_line_tween = null


func _kill_blink_tween() -> void:
	if _blink_tween != null and _blink_tween.is_running():
		_blink_tween.kill()
	_blink_tween = null


func _cancel_display_activity() -> void:
	_kill_line_tween()
	_kill_fade_tween()
	_kill_blink_tween()
	_is_waiting_input = false
	if next_line_indicator:
		next_line_indicator.hide()
