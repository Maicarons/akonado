@tool
extends EditorProperty

# 指定音效目录、支持的音频格式
const TYPEWRITER_AUDIO_EFFECT_DIR: String = "res://addons/konado/assets/audio/typewriter/"
const SUPPORTED_FORMATS: Array[String] = ["wav", "ogg", "mp3"]

# 核心变量：下拉控件实例、文件名-资源路径映射、防重复更新标记
var option_button: OptionButton = OptionButton.new()
var name_to_path: Dictionary = {}
var updating: bool = false
var audio_effect_dir: String = ""


func _init(type: String) -> void:
	match type:
		"typewriter":
			audio_effect_dir = TYPEWRITER_AUDIO_EFFECT_DIR
		_:
			audio_effect_dir = ""

	option_button.size_flags_horizontal = SIZE_EXPAND_FILL
	option_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(option_button)
	add_focusable(option_button)
	_load_audio_options()
	option_button.item_selected.connect(_on_item_selected)


func _load_audio_options() -> void:
	option_button.clear()
	name_to_path.clear()
	var dir = DirAccess.open(TYPEWRITER_AUDIO_EFFECT_DIR)

	# 遍历目录下的所有文件
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		var ext: String = file_name.get_extension().to_lower()
		# 过滤仅支持的音频格式
		if SUPPORTED_FORMATS.has(ext):
			var full_path: String = TYPEWRITER_AUDIO_EFFECT_DIR + file_name
			option_button.add_item(file_name)
			name_to_path[file_name] = full_path
		file_name = dir.get_next()
	dir.list_dir_end()

	if option_button.get_item_count() == 0:
		var tip = "无有效音效"
		option_button.add_item(tip)
		name_to_path[tip] = ""


func _update_property() -> void:
	# 防重复更新：内部选择触发时，忽略外部同步
	if updating:
		return
	# 获取当前编辑对象和属性名
	var edited_obj: KonadoDialogueBox = get_edited_object()
	var prop_name: String = get_edited_property()
	if not edited_obj or prop_name != "typing_effect_audio":
		return

	# 获取对象当前的音效资源
	var current_audio: AudioStream = edited_obj.typing_effect_audio
	# 无音效资源 → 选中第一个选项
	if not current_audio:
		option_button.select(0)
		return

	var current_path: String = current_audio.resource_path
	var target_idx: int = 0
	for idx in range(option_button.get_item_count()):
		var item_name: String = option_button.get_item_text(idx)
		if name_to_path.get(item_name, "") == current_path:
			target_idx = idx
			break
	# 更新下拉选中状态
	option_button.select(target_idx)


func _on_item_selected(selected_idx: int) -> void:
	# 防重复更新：外部同步时，忽略内部选择
	if updating:
		return
	# 获取选中项的名称和对应的资源路径
	var selected_name: String = option_button.get_item_text(selected_idx)
	var audio_path: String = name_to_path.get(selected_name, "")

	# 初始化更新标记，避免触发_self._update_property
	updating = true
	# 空路径
	if audio_path.is_empty():
		emit_changed(get_edited_property(), null)
	else:
		var audio_stream: AudioStream = ResourceLoader.load(audio_path)
		emit_changed(get_edited_property(), audio_stream)
	# 解除更新标记
	updating = false
