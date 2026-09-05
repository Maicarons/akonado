extends Control
class_name KonadoDialogueBox

## Konado对话框模板
## 可以自定义设置画面显示内容、位置、尺寸

## 点击对话框
signal on_dialogue_click
signal on_button_pressed
signal on_character_name_click

## 打字完成
signal typing_completed

## 对话框显示动画完成
signal on_dialogue_show_completed

## 对话框隐藏动画完成
signal on_dialogue_hide_completed

## 打字机模式枚举
enum TypewriterMode { TRADITIONAL = 0, FADE_IN_TYPEWRITER = 1 }  ## 传统模式  ## 淡入打字机模式
enum VisibilityState { HIDDEN, SHOWING, VISIBLE, HIDING }

const VOICE_PROGRESS_DISPLAY_SCRIPT := preload(
	"res://addons/konado/runtime/ui/dialogue_box/konado_voice_progress_display.gd"
)

## 角色对象
@export_group("名字")
@export var character_name: String = "":
	set(value):
		character_name = value
		_update_character_name()

@export var name_size: int = 32  ## 名字字体大小
@export var name_bg: Texture2D  ## 名字标签背景
@export var name_color: Color = Color.WHITE  ## 名字颜色

## 对话内容
@export_group("对话文本设置")
@export var dialogue_text: String = "":
	set(value):
		dialogue_text = value
		_update_dialogue_content()

@export var dialogue_font_size: int = 24  ## 对话文本字体大小（新增）
## 打字间隔（单字符）
@export var typing_interval: float = 0.4:
	set(value):
		typing_interval = value
		_update_dialogue_content()

@export_group("打字音效配置")
@export var enable_typing_effect_audio: bool = true
@export var typing_effect_audio: AudioStream
@export var audio_trigger_chance: float = 0.8  ## 音效触发概率(0-1)，1=每次必播，0=不播
@export var min_audio_interval: float = 0.02  ## 音效最小播放间隔（秒），适配滴滴声快速节奏
@export var max_audio_interval: float = 0.08  ## 音效最大播放间隔（秒）
@export var audio_volumn: float = 0.6  ## 音效音量(0-1)

@export_group("语音进度显示")
@export var show_voice_progress: bool = true:
	set(value):
		show_voice_progress = value
		if not show_voice_progress:
			clear_voice_progress()

@export_group("对话框设置")
@export var dialogue_margins: int = 100  ## 对话框到底部距离
@export var dialogue_bg: StyleBox  ## 对话框背景
@export var dialogue_color: Color = Color.WHITE  ## 对话文字颜色
@export var dialogue_height: int = 200  ## 对话文本框高度

@export_group("按钮")
@export var button_show: bool = false
@export var button_text: String = ""
@export var button_texture: Texture2D

# 动画相关变量
@export_group("过渡动画设置")
@export var fade_duration: float = 0.5  ## 显示/隐藏过渡动画时长
@export var fade_trans_type: Tween.TransitionType = Tween.TRANS_SINE  ## 过渡动画曲线类型
@export var fade_ease_type: Tween.EaseType = Tween.EASE_IN_OUT  ## 过渡动画缓动类型

@export_group("打字机设置")
@export var typewriter_mode: TypewriterMode = TypewriterMode.TRADITIONAL  ## 打字机模式

# TypewriterText 组件
@export var typewriter_text: KonadoTypewriterText

# 音效状态变量 - 记录上一次播放时间、当前随机间隔
var last_audio_play_time: float = 0.0
var current_random_interval: float = 0.0

# 透明度过渡动画Tween
var fade_tween: Tween = null

var typing_tween: Tween = null
var voice_player: AudioStreamPlayer
var _visibility_state: VisibilityState = VisibilityState.HIDDEN
var _visibility_transition_id: int = 0
var _typing_update_id: int = 0
var _immediate_content_update: bool = false

# 动态音频播放器
@onready var audio_player: AudioStreamPlayer = AudioStreamPlayer.new()

## 加载节点
@onready var character_name_label: Label = %CharacterNameLabel
@onready var dialogue_label: RichTextLabel = %DialogueLabel
@onready var progress_bar: TextureProgressBar = %RelationshipProgress
@onready var voice_progress_display: VOICE_PROGRESS_DISPLAY_SCRIPT = (
	get_node_or_null("%VoiceProgressDisplay") as VOICE_PROGRESS_DISPLAY_SCRIPT
)
@onready var dialogue_container: MarginContainer = %DialogueContainer
@onready var dialogue_box_bg: Panel = %DialogueBackground


func _ready() -> void:
	self.hide()
	self.modulate.a = 1.0
	_visibility_state = VisibilityState.HIDDEN
	clear_voice_progress()
	_apply_dialogue_text_theme_settings()
	_update_dialogue_box_height()

	# 始终由对话框持有播放器，避免关闭音效时留下未入树的孤立对象。
	add_child(audio_player)
	audio_player.name = "TypingAudioPlayer"
	audio_player.stream = typing_effect_audio
	audio_player.volume_db = linear_to_db(audio_volumn)
	audio_player.autoplay = false
	current_random_interval = randf_range(min_audio_interval, max_audio_interval)

	# 根据打字机模式处理 TypewriterText 组件
	if _uses_fade_typewriter():
		_create_typewriter_text()
	else:
		# 如果 TypewriterText 组件存在，则隐藏它并显示传统的 dialogue_label
		if typewriter_text != null:
			typewriter_text.hide()
		dialogue_label.show()


func _exit_tree() -> void:
	_cancel_visibility_transition()
	_stop_typing_activity()
	if audio_player != null:
		audio_player.stream = null
	if voice_player and voice_player.finished.is_connected(clear_voice_progress):
		voice_player.finished.disconnect(clear_voice_progress)


func bind_voice_player(player: AudioStreamPlayer) -> void:
	if voice_player and voice_player.finished.is_connected(clear_voice_progress):
		voice_player.finished.disconnect(clear_voice_progress)
	voice_player = player
	clear_voice_progress()
	if voice_player and not voice_player.finished.is_connected(clear_voice_progress):
		voice_player.finished.connect(clear_voice_progress)


func clear_voice_progress() -> void:
	if not is_inside_tree():
		return
	if voice_progress_display:
		voice_progress_display.hide_progress()


func _update_voice_progress() -> void:
	if not show_voice_progress:
		clear_voice_progress()
		return
	if not voice_player or not voice_progress_display:
		clear_voice_progress()
		return
	if not voice_player.stream or not voice_player.is_playing():
		clear_voice_progress()
		return
	var voice_length := voice_player.stream.get_length()
	if voice_length <= 0.0:
		clear_voice_progress()
		return
	voice_progress_display.set_progress(voice_player.get_playback_position(), voice_length)


## 应用对话文本的主题设置
func _apply_dialogue_text_theme_settings() -> void:
	if not is_inside_tree():
		return
	dialogue_label.add_theme_font_size_override("normal_font_size", dialogue_font_size)

	# 如果使用 TypewriterText 模式，也应用主题设置
	if typewriter_text != null:
		typewriter_text.font_size = dialogue_font_size
		typewriter_text.font_color = dialogue_color


## 创建 TypewriterText 组件
func _create_typewriter_text() -> void:
	if typewriter_text == null:
		return
	if not typewriter_text.typewriter_finished.is_connected(_on_typewriter_finished):
		typewriter_text.typewriter_finished.connect(_on_typewriter_finished)
	dialogue_label.hide()
	typewriter_text.show()


func _on_typewriter_finished() -> void:
	typing_completed.emit()


func _uses_fade_typewriter() -> bool:
	return typewriter_mode == TypewriterMode.FADE_IN_TYPEWRITER and typewriter_text != null


func _cancel_visibility_transition() -> int:
	_visibility_transition_id += 1
	if fade_tween != null and fade_tween.is_running():
		fade_tween.kill()
	fade_tween = null
	return _visibility_transition_id


func _stop_typing_activity() -> void:
	_typing_update_id += 1
	if typing_tween != null and typing_tween.is_running():
		typing_tween.kill()
	typing_tween = null
	if typewriter_text != null and typewriter_text.is_playing():
		typewriter_text.stop()
	if audio_player.is_inside_tree() and audio_player.is_playing():
		audio_player.stop()
	last_audio_play_time = 0.0


func _restore_content_visibility() -> void:
	character_name_label.show()
	character_name_label.modulate.a = 1.0
	if _uses_fade_typewriter():
		dialogue_label.hide()
		dialogue_label.modulate.a = 1.0
		typewriter_text.show()
		typewriter_text.modulate.a = 1.0
	else:
		dialogue_label.show()
		dialogue_label.modulate.a = 1.0
		if typewriter_text != null:
			typewriter_text.hide()
			typewriter_text.modulate.a = 1.0


func _complete_show(transition_id: int, callback: Callable) -> void:
	if transition_id != _visibility_transition_id:
		return
	fade_tween = null
	self.modulate.a = 1.0
	_visibility_state = VisibilityState.VISIBLE
	on_dialogue_show_completed.emit()
	if callback.is_valid():
		callback.call()


func _complete_hide(transition_id: int, clear_content: bool) -> void:
	if transition_id != _visibility_transition_id:
		return
	fade_tween = null
	self.hide()
	self.modulate.a = 1.0
	_visibility_state = VisibilityState.HIDDEN
	if clear_content:
		clear_dialogue_content()
	on_dialogue_hide_completed.emit()


func _show_dialogue_box(duration: float, callback: Callable = Callable()) -> void:
	var was_visible := _visibility_state == VisibilityState.VISIBLE and self.visible
	var transition_id := _cancel_visibility_transition()
	_restore_content_visibility()
	self.show()

	if was_visible:
		_complete_show(transition_id, callback)
		return

	_visibility_state = VisibilityState.SHOWING
	if duration <= 0.0:
		_complete_show(transition_id, callback)
		return

	self.modulate.a = 0.0
	fade_tween = get_tree().create_tween()
	fade_tween.set_trans(fade_trans_type)
	fade_tween.set_ease(fade_ease_type)
	fade_tween.tween_property(self, "modulate:a", 1.0, duration)
	fade_tween.finished.connect(_complete_show.bind(transition_id, callback), CONNECT_ONE_SHOT)


func _hide_dialogue_box(duration: float, clear_content: bool) -> void:
	var was_hidden := _visibility_state == VisibilityState.HIDDEN and not self.visible
	var transition_id := _cancel_visibility_transition()
	clear_voice_progress()
	_stop_typing_activity()

	if was_hidden:
		_complete_hide(transition_id, clear_content)
		return

	_visibility_state = VisibilityState.HIDING
	if duration <= 0.0:
		_complete_hide(transition_id, clear_content)
		return

	fade_tween = get_tree().create_tween()
	fade_tween.set_trans(fade_trans_type)
	fade_tween.set_ease(fade_ease_type)
	fade_tween.tween_property(self, "modulate:a", 0.0, duration)
	fade_tween.finished.connect(_complete_hide.bind(transition_id, clear_content), CONNECT_ONE_SHOT)


## 暂时隐藏对话框并保留当前角色名和文本。
func hide_dialogue_box() -> void:
	_hide_dialogue_box(fade_duration, false)


## 隐藏对话框，并在动画完成后清除当前角色名和文本。
func dismiss_dialogue_box() -> void:
	_hide_dialogue_box(fade_duration, true)


## 检查对话框是否显示
func is_dialogue_box_visible() -> bool:
	return self.visible and _visibility_state != VisibilityState.HIDING and self.modulate.a > 0.0


## 使用指定时长暂时隐藏对话框，并保留当前角色名和文本。
func hide_dialogue_box_with_duration(duration: float) -> void:
	_hide_dialogue_box(duration, false)


## 使用指定时长隐藏对话框，并在动画完成后清除当前角色名和文本。
func dismiss_dialogue_box_with_duration(duration: float) -> void:
	_hide_dialogue_box(duration, true)


## 清除仅属于当前镜头的文本、角色名、语音进度和打字状态。
func clear_dialogue_content() -> void:
	_stop_typing_activity()
	clear_voice_progress()
	character_name = ""
	dialogue_text = ""


## 立即恢复为可安全开始新镜头的隐藏状态。
func reset_dialogue_box() -> void:
	_cancel_visibility_transition()
	clear_dialogue_content()
	self.hide()
	self.modulate.a = 1.0
	_visibility_state = VisibilityState.HIDDEN


## Cancel in-flight transitions and typewriter work without clearing committed content.
## The VM uses this as an atomic-instruction cancellation boundary.
func cancel_pending_operations() -> void:
	_cancel_visibility_transition()
	_stop_typing_activity()
	modulate.a = 1.0
	_visibility_state = VisibilityState.VISIBLE if visible else VisibilityState.HIDDEN


func capture_state() -> Dictionary:
	return {
		"character": character_name,
		"text": dialogue_text,
		"visible": is_dialogue_box_visible(),
		"typing_interval": typing_interval,
	}


func restore_state(state: Dictionary) -> bool:
	reset_dialogue_box()
	if state.is_empty():
		return true
	typing_interval = float(state.get("typing_interval", typing_interval))
	character_name = String(state.get("character", ""))
	set_dialogue_content_immediately(String(state.get("text", "")))
	if bool(state.get("visible", false)):
		show()
		modulate.a = 1.0
		_visibility_state = VisibilityState.VISIBLE
	return true


## 显示对话框（带透明度过渡动画）
func show_dialogue_box(callback: Callable = Callable()) -> void:
	_show_dialogue_box(fade_duration, callback)


## 显示对话框（自定义动画时长）
func show_dialogue_box_with_duration(duration: float) -> void:
	_show_dialogue_box(duration)


func _update_dialogue():
	if not is_inside_tree():
		return
	_update_character_name()
	_update_dialogue_content()


func _update_character_name() -> void:
	if not is_inside_tree():
		return
	character_name_label.text = character_name
	character_name_label.label_settings.font_size = name_size
	character_name_label.label_settings.font_color = name_color


func _update_dialogue_box_height() -> void:
	# 更改边距
	dialogue_container.add_theme_constant_override("margin_left", dialogue_margins)
	dialogue_container.add_theme_constant_override("margin_right", dialogue_margins)
	dialogue_container.add_theme_constant_override("margin_bottom", dialogue_margins)
	# 如果用户选择了背景
	if dialogue_bg:
		dialogue_box_bg.add_theme_stylebox_override("panel", dialogue_bg)
	# 更改文本高度
	dialogue_label.custom_minimum_size.y = dialogue_height

	# 如果使用 TypewriterText 模式，也设置其高度
	if typewriter_text != null:
		typewriter_text.size = Vector2(dialogue_container.size.x, dialogue_height)


func _update_dialogue_content() -> void:
	if not is_inside_tree():
		return

	_stop_typing_activity()
	var typing_update_id := _typing_update_id
	var show_immediately := _immediate_content_update

	if dialogue_text.is_empty():
		dialogue_label.text = ""
		dialogue_label.visible_ratio = 1.0
		if typewriter_text != null:
			typewriter_text.set_bbcode("", false)
		return

	# 每次更新对话内容时，重新应用主题设置（确保字体大小/颜色生效）
	_apply_dialogue_text_theme_settings()

	_update_dialogue_box_height()

	# 重置音效状态 - 重新打字时从头计算间隔
	last_audio_play_time = 0.0
	current_random_interval = randf_range(min_audio_interval, max_audio_interval)

	# 根据打字机模式选择不同的更新方式
	if _uses_fade_typewriter():
		# 淡入打字机模式
		typewriter_text.set_bbcode(dialogue_text, not show_immediately)
	else:
		# 传统模式
		dialogue_label.text = dialogue_text  # 恢复原生text赋值，无需BBCode
		if show_immediately:
			dialogue_label.visible_ratio = 1.0
			return
		dialogue_label.visible_ratio = 0
		await get_tree().process_frame
		if not is_inside_tree() or typing_update_id != _typing_update_id:
			return

		# 创建新的打字动画
		typing_tween = get_tree().create_tween()
		typing_tween.finished.connect(func(): typing_completed.emit())
		# 优化：按**字符数**计算总时长
		var total_typing_time = dialogue_text.length() * typing_interval
		(
			typing_tween
			. tween_property(dialogue_label, "visible_ratio", 1.0, total_typing_time)
			. set_trans(Tween.TRANS_LINEAR)
		)


## 不播放打字动画，立即替换完整文本，也不发射 typing_completed。
func set_dialogue_content_immediately(content: String) -> void:
	_immediate_content_update = true
	dialogue_text = content
	_immediate_content_update = false


## 跳过打字机动画
func skip_typing_anim() -> void:
	# 根据打字机模式选择不同的跳过方式
	if _uses_fade_typewriter():
		# 淡入打字机模式
		if typewriter_text.is_playing():
			typewriter_text.skip()

			if enable_typing_effect_audio and audio_player.is_playing():
				audio_player.stop()
			# 重置音效状态
			last_audio_play_time = 0.0
			current_random_interval = randf_range(min_audio_interval, max_audio_interval)
	else:
		# 传统模式
		# 如果打字动画正在运行，则中断并跳过
		if typing_tween != null and typing_tween.is_running():
			# 停止打字动画
			typing_tween.kill()
			# 直接显示完整文本
			dialogue_label.visible_ratio = 1.0

			if enable_typing_effect_audio and audio_player.is_playing():
				audio_player.stop()
			# 重置音效状态
			last_audio_play_time = 0.0
			current_random_interval = randf_range(min_audio_interval, max_audio_interval)
			typing_completed.emit()


func _process(_delta: float) -> void:
	_update_voice_progress()

	# 仅当打字动画运行、文本非空时，处理音效逻辑
	var is_typing = false
	if _uses_fade_typewriter():
		# 淡入打字机模式
		is_typing = (
			typewriter_text != null
			and typewriter_text.is_playing()
			and not dialogue_text.is_empty()
		)
	else:
		# 传统模式
		is_typing = typing_tween and typing_tween.is_running() and not dialogue_text.is_empty()

	if not is_typing:
		return

	# 获取当前运行时间（秒），用于计算时间间隔
	var current_time = Time.get_unix_time_from_system()
	# 距离上一次播放音效的时间差
	var time_since_last_play = current_time - last_audio_play_time

	if enable_typing_effect_audio:
		var should_play = false
		if typewriter_mode == TypewriterMode.FADE_IN_TYPEWRITER:
			# 淡入打字机模式：检查进度
			var progress = typewriter_text.get_progress()
			var total_chars = dialogue_text.length()
			should_play = progress < float(total_chars)
		else:
			# 传统模式：检查 visible_ratio
			should_play = dialogue_label.visible_ratio < 0.98

		if (
			time_since_last_play > current_random_interval
			and randf() < audio_trigger_chance
			and should_play
		):
			# 防重叠
			audio_player.stop()
			audio_player.play()
			# 更新上一次播放时间
			last_audio_play_time = current_time
			# 重新生成随机间隔（每次播放后更新，保证间隔不重复）
			current_random_interval = randf_range(min_audio_interval, max_audio_interval)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		on_dialogue_click.emit()


func _input(event: InputEvent) -> void:
	# 可以根据需要绑定其他
	if event.is_action_pressed("ui_accept") || event.is_action_pressed("ui_select"):
		on_dialogue_click.emit()


func _on_button_pressed() -> void:
	on_button_pressed.emit()


func _on_character_name_label_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		on_character_name_click.emit()
