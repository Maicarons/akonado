@tool
class_name KND_TypewriterText
extends Control
## 支持 BBCode 富文本的 GPU 加速打字机文本组件。
##
## 使用专用的 CanvasItem 着色器逐字符渲染文本，并实现平滑的方向性淡入效果。
## 基于 TextServer / Font.draw_char() 构建，不依赖 Label / RichTextLabel，也不进行自动换行。

# ── 信号 ──────────────────────────────────────────────────────────────────
signal typewriter_started
signal typewriter_finished
signal typewriter_skipped
signal character_revealed(index: int)

# ── 导出: 文本 ────────────────────────────────────────────────────────────
@export_group("Text")
@export_multiline var bbcode_text: String = "":
	set(v):
		bbcode_text = v
		_mark_dirty()
@export var font: Font:
	set(v):
		font = v
		_mark_dirty()
@export_range(1, 999) var font_size: int = 20:
	set(v):
		font_size = clampi(v, 1, 999)
		_mark_dirty()
@export var font_color: Color = Color.WHITE:
	set(v):
		font_color = v
		_mark_dirty()
@export_range(0.0, 100.0) var line_spacing: float = 4.0:
	set(v):
		line_spacing = v
		_mark_dirty()

# ── 导出: 打字机 ─────────────────────────────────────────────────────
@export_group("Typewriter")
@export_range(0.1, 200.0) var chars_per_second: float = 25.0
@export_range(0.5, 30.0) var fade_width: float = 3.0:
	set(v):
		fade_width = maxf(v, 0.5)
		_sync_shader()
@export_range(-180.0, 180.0) var fade_angle: float = 0.0:
	set(v):
		fade_angle = v
		_sync_shader()
@export_range(0.0, 1.0) var spatial_blend: float = 0.15:
	set(v):
		spatial_blend = v
		_sync_shader()
@export var auto_start: bool = true

# ── 导出: 布局 ─────────────────────────────────────────────────────────
@export_group("Layout")
@export var horizontal_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT:
	set(v):
		horizontal_alignment = v
		_mark_dirty()

# ── 内部状态 ──────────────────────────────────────────────────────────
var _chars: Array = []          # 每个字符的字典
var _total_chars: int = 0
var _progress: float = 0.0     # 当前显示光标（以字符索引为单位）
var _playing: bool = false
var _finished: bool = false
var _dirty: bool = true
var _text_height: float = 0.0
var _last_revealed: int = -1

# 字体变体缓存
var _f_regular: Font
var _f_bold: Font
var _f_italic: Font
var _f_bold_italic: Font
var _sys_font: SystemFont        # 缓存的系统字体，支持 CJK / 多语言

# 着色器材料（只创建一次）
var _shader_mat: ShaderMaterial

# ── 生命周期 ────────────────────────────────────────────────────────────────
func _ready() -> void:
	_init_shader()
	_build_font_variants()
	_rebuild()
	if auto_start and _total_chars > 0 and not Engine.is_editor_hint():
		start()

func _process(delta: float) -> void:
	if not _playing:
		return
	_progress += delta * chars_per_second
	# 发送每个字符的信号
	var idx := int(_progress)
	while _last_revealed < idx and _last_revealed < _total_chars - 1:
		_last_revealed += 1
		character_revealed.emit(_last_revealed)
	# 检查完成状态（允许淡入效果完成）
	if _progress >= float(_total_chars) + fade_width:
		_playing = false
		_finished = true
		_progress = float(_total_chars) + fade_width
		typewriter_finished.emit()
	_sync_shader()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_dirty = true
		queue_redraw()

func _get_minimum_size() -> Vector2:
	return Vector2(0.0, _text_height)

func _draw() -> void:
	if _dirty:
		_rebuild()
	if _total_chars == 0:
		return
	# 在编辑器中，始终显示所有文本。
	if Engine.is_editor_hint():
		_progress = float(_total_chars) + fade_width
		_sync_shader()
	var total_f := float(_total_chars)
	for i in range(_total_chars):
		var cd: Dictionary = _chars[i]
		var ch_str: String = cd.ch
		if ch_str == "\n":
			continue
		# 将归一化的显示时间编码到着色器的 alpha 通道中。
		var reveal_t: float = float(i) / total_f
		var draw_color := Color(cd.color.r, cd.color.g, cd.color.b, reveal_t)
		var f: Font = cd.font
		var sz: int = cd.size
		var pos: Vector2 = cd.pos
		# 绘制字形
		f.draw_char(get_canvas_item(), pos, ch_str.unicode_at(0), sz, draw_color)
		# 下划线
		if cd.underline:
			var adv: float = cd.advance
			var ul_y: float = pos.y + f.get_descent(sz) * 0.3
			draw_line(Vector2(pos.x, ul_y), Vector2(pos.x + adv, ul_y),
				draw_color, maxf(1.0, float(sz) / 16.0))
		# 删除线
		if cd.strikethrough:
			var adv: float = cd.advance
			var st_y: float = pos.y - f.get_ascent(sz) * 0.3
			draw_line(Vector2(pos.x, st_y), Vector2(pos.x + adv, st_y),
				draw_color, maxf(1.0, float(sz) / 16.0))

# ── 公共 API ───────────────────────────────────────────────────────────────
## 从头开始打字机效果的文本显示。
func start() -> void:
	_progress = 0.0
	_last_revealed = -1
	_playing = true
	_finished = false
	typewriter_started.emit()
	_sync_shader()
	queue_redraw()

## 立即显示所有文本。
func skip() -> void:
	_progress = float(_total_chars) + fade_width
	_playing = false
	if not _finished:
		_finished = true
		typewriter_skipped.emit()
		typewriter_finished.emit()
	_sync_shader()
	queue_redraw()

## 隐藏所有文本并停止。
func reset() -> void:
	_progress = 0.0
	_last_revealed = -1
	_playing = false
	_finished = false
	_sync_shader()
	queue_redraw()

## 在运行时更改显示的文本（BBCode）。
func set_bbcode(new_text: String, autoplay: bool = true) -> void:
	bbcode_text = new_text
	_rebuild()
	reset()
	if autoplay:
		start()

## 当打字机动画运行时返回 true。
func is_playing() -> bool:
	return _playing

## 当所有字符都完全显示后返回 true。
func is_finished() -> bool:
	return _finished

## 当前的显示进度，以字符索引为单位。
func get_progress() -> float:
	return _progress

# ── BBCode 解析器 ────────────────────────────────────────────────────────────
## 将 bbcode_text 解析为每个字符的字典数组 _chars。
func _parse_bbcode() -> void:
	_chars.clear()
	var src := bbcode_text
	var color_stack: Array[Color] = []
	var size_stack: Array[int] = []
	var bold_d: int = 0
	var italic_d: int = 0
	var under_d: int = 0
	var strike_d: int = 0
	var cur_color: Color = font_color
	var cur_size: int = font_size
	var i: int = 0
	var length: int = src.length()
	while i < length:
		# Escaped bracket
		if src[i] == "\\" and i + 1 < length and src[i + 1] == "[":
			_push_char("[", cur_color, bold_d > 0, italic_d > 0, under_d > 0, strike_d > 0, cur_size)
			i += 2
			continue
		# Tag opening
		if src[i] == "[":
			var close := src.find("]", i + 1)
			if close != -1:
				var tag := src.substr(i + 1, close - i - 1).strip_edges()
				var eaten := true
				if tag == "b":
					bold_d += 1
				elif tag == "/b":
					bold_d = maxi(bold_d - 1, 0)
				elif tag == "i":
					italic_d += 1
				elif tag == "/i":
					italic_d = maxi(italic_d - 1, 0)
				elif tag == "u":
					under_d += 1
				elif tag == "/u":
					under_d = maxi(under_d - 1, 0)
				elif tag == "s":
					strike_d += 1
				elif tag == "/s":
					strike_d = maxi(strike_d - 1, 0)
				elif tag.begins_with("color="):
					color_stack.push_back(cur_color)
					cur_color = Color.from_string(tag.substr(6).strip_edges(), font_color)
				elif tag == "/color":
					cur_color = color_stack.pop_back() if color_stack.size() > 0 else font_color
				elif tag.begins_with("font_size=") or tag.begins_with("size="):
					size_stack.push_back(cur_size)
					cur_size = clampi(tag.substr(tag.find("=") + 1).strip_edges().to_int(), 1, 999)
				elif tag == "/font_size" or tag == "/size":
					cur_size = size_stack.pop_back() if size_stack.size() > 0 else font_size
				else:
					eaten = false
				if eaten:
					i = close + 1
					continue
		# Regular character
		_push_char(src[i], cur_color, bold_d > 0, italic_d > 0, under_d > 0, strike_d > 0, cur_size)
		i += 1
	_total_chars = _chars.size()

func _push_char(ch: String, col: Color, bold: bool, italic: bool,
				underline: bool, strike: bool, sz: int) -> void:
	var f: Font
	if bold and italic:
		f = _f_bold_italic
	elif bold:
		f = _f_bold
	elif italic:
		f = _f_italic
	else:
		f = _f_regular
	_chars.push_back({
		"ch": ch,
		"color": col,
		"font": f,
		"size": sz,
		"underline": underline,
		"strikethrough": strike,
		"pos": Vector2.ZERO,
		"advance": 0.0,
	})

# ── 字体变体 ────────────────────────────────────────────────────────────
## 返回（并懒加载创建）一个覆盖 CJK / 多语言字形的 SystemFont。
func _ensure_sys_font() -> SystemFont:
	if _sys_font == null:
		_sys_font = SystemFont.new()
		_sys_font.font_names = PackedStringArray([
			"Noto Sans CJK SC", "Noto Sans CJK",
			"Source Han Sans SC", "Source Han Sans",
			"Microsoft YaHei", "PingFang SC", "Hiragino Sans GB",
			"WenQuanYi Micro Hei", "Droid Sans Fallback",
			"Noto Sans", "sans-serif",
		])
	return _sys_font

func _build_font_variants() -> void:
	var sys := _ensure_sys_font()
	var base: Font = font if font else sys
	# 回退字体列表确保即使用户提供仅支持拉丁文字的字体，也能覆盖 CJK 字符。
	#var fb: Array[Font] = [] if (base == sys) else [sys]

	var fb: Array[Font]
	if base == sys:
		fb = []  # 空的 Font 数组
	else:
		fb = [sys]
	# 常规字体 - 包装在 FontVariation 中，以便我们可以统一附加回退字体。
	var rv := FontVariation.new()
	rv.base_font = base
	rv.fallbacks = fb
	_f_regular = rv

	var bv := FontVariation.new()
	bv.base_font = base
	bv.variation_embolden = 0.5
	bv.fallbacks = fb
	_f_bold = bv

	var iv := FontVariation.new()
	iv.base_font = base
	iv.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.22, 1.0), Vector2.ZERO)
	iv.fallbacks = fb
	_f_italic = iv

	var biv := FontVariation.new()
	biv.base_font = base
	biv.variation_embolden = 0.5
	biv.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.22, 1.0), Vector2.ZERO)
	biv.fallbacks = fb
	_f_bold_italic = biv

# ── 布局引擎 ────────────────────────────────────────────────────────────
## 计算字符位置，支持单词感知的自动换行。
func _compute_layout() -> void:
	if _total_chars == 0:
		_text_height = 0.0
		return
	var avail_w: float = size.x
	# ── 测量字符宽度 ────────────────────────────────────────────────────
	for idx in range(_total_chars):
		var cd: Dictionary = _chars[idx]
		if cd.ch == "\n":
			cd.advance = 0.0
		else:
			cd.advance = cd.font.get_char_size(cd.ch.unicode_at(0), cd.size).x
	# ── 构建行（单词级换行）──────────────────────────────────────────────
	# 每行: {start: int, end: int, width: float, ascent: float, descent: float}
	var lines: Array = []
	var ln_start: int = 0
	var ln_w: float = 0.0
	var ln_asc: float = 0.0
	var ln_desc: float = 0.0
	var last_space: int = -1
	for idx in range(_total_chars):
		var cd: Dictionary = _chars[idx]
		var f: Font = cd.font
		var sz: int = cd.size
		var asc: float = f.get_ascent(sz)
		var desc: float = f.get_descent(sz)
		# 显式换行
		if cd.ch == "\n":
			if ln_asc == 0.0:
				ln_asc = _f_regular.get_ascent(font_size)
				ln_desc = _f_regular.get_descent(font_size)
			lines.append({"start": ln_start, "end": idx, "width": ln_w,
					  "ascent": ln_asc, "descent": ln_desc})
			ln_start = idx + 1
			ln_w = 0.0
			ln_asc = 0.0
			ln_desc = 0.0
			last_space = -1
			continue
		# 跟踪空格以进行单词换行
		if cd.ch == " ":
			last_space = idx
		# 单词换行
		if ln_w + cd.advance > avail_w and idx > ln_start:
			if last_space >= ln_start:
				# 在最后一个空格处换行
				var wrap_w: float = 0.0
				var wrap_asc: float = 0.0
				var wrap_desc: float = 0.0
				for j in range(ln_start, last_space):
					wrap_w += _chars[j].advance
					wrap_asc = maxf(wrap_asc, _chars[j].font.get_ascent(_chars[j].size))
					wrap_desc = maxf(wrap_desc, _chars[j].font.get_descent(_chars[j].size))
				if wrap_asc == 0.0:
					wrap_asc = _f_regular.get_ascent(font_size)
					wrap_desc = _f_regular.get_descent(font_size)
				lines.append({"start": ln_start, "end": last_space, "width": wrap_w,
						  "ascent": wrap_asc, "descent": wrap_desc})
				ln_start = last_space + 1
				# 重新计算剩余部分的累计值
				ln_w = 0.0
				ln_asc = 0.0
				ln_desc = 0.0
				for j in range(ln_start, idx + 1):
					ln_w += _chars[j].advance
					ln_asc = maxf(ln_asc, _chars[j].font.get_ascent(_chars[j].size))
					ln_desc = maxf(ln_desc, _chars[j].font.get_descent(_chars[j].size))
				last_space = -1
				continue
			else:
				# 无空格 - 在当前字符前硬换行
				if ln_asc == 0.0:
					ln_asc = _f_regular.get_ascent(font_size)
					ln_desc = _f_regular.get_descent(font_size)
				lines.append({"start": ln_start, "end": idx, "width": ln_w,
						  "ascent": ln_asc, "descent": ln_desc})
				ln_start = idx
				ln_w = 0.0
				ln_asc = 0.0
				ln_desc = 0.0
				last_space = -1
		ln_w += cd.advance
		ln_asc = maxf(ln_asc, asc)
		ln_desc = maxf(ln_desc, desc)
	# 剩余行
	if ln_start < _total_chars:
		if ln_asc == 0.0:
			ln_asc = _f_regular.get_ascent(font_size)
			ln_desc = _f_regular.get_descent(font_size)
		lines.append({"start": ln_start, "end": _total_chars, "width": ln_w,
				  "ascent": ln_asc, "descent": ln_desc})
	# ── 分配位置 ────────────────────────────────────────────────────
	var y: float = 0.0
	for ln in lines:
		y += ln.ascent
		var x: float = _line_x_offset(ln.width)
		for idx in range(ln.start, ln.end):
			var cd: Dictionary = _chars[idx]
			if cd.ch == "\n":
				continue
			cd.pos = Vector2(x, y)
			x += cd.advance
		y += ln.descent + line_spacing
	_text_height = y
	update_minimum_size()

func _line_x_offset(line_width: float) -> float:
	match horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			return (size.x - line_width) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			return size.x - line_width
		_:
			return 0.0

# ── 着色器助手 ───────────────────────────────────────────────────────────
func _init_shader() -> void:
	var shader := preload("res://addons/konado/typewriter/typewriter_fade.gdshader")
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = shader
	material = _shader_mat
	_sync_shader()

func _sync_shader() -> void:
	if _shader_mat == null:
		return
	var total_f := maxf(float(_total_chars), 1.0)
	_shader_mat.set_shader_parameter("progress", _progress / total_f)
	_shader_mat.set_shader_parameter("softness", fade_width / total_f)
	_shader_mat.set_shader_parameter("angle_rad", deg_to_rad(fade_angle))
	_shader_mat.set_shader_parameter("spatial_blend", spatial_blend)
	_shader_mat.set_shader_parameter("rect_size", size)

# ── 内部函数 ────────────────────────────────────────────────────────────────
func _mark_dirty() -> void:
	_dirty = true
	if is_inside_tree():
		queue_redraw()

func _rebuild() -> void:
	_dirty = false
	_build_font_variants()
	_parse_bbcode()
	_compute_layout()
	_sync_shader()

## 编辑器预览：在编辑器中显示所有文本。
func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if bbcode_text.is_empty():
		warnings.append("bbcode_text is empty – nothing to display.")
	return warnings
