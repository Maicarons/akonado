@tool
extends EditorInspectorPlugin

# 预加载自定义的EditorProperty下拉控件
var AudioDropdownEditor = preload(
	"res://addons/konado/editor/inspectors/audio_effect/typewriter_audio_dropdown_editor.gd"
)


# 仅处理KonadoDialogueBox类
func _can_handle(object: Object) -> bool:
	return object is KonadoDialogueBox


func _parse_property(
	_object: Object,
	_type: Variant.Type,
	name: String,
	_hint_type: PropertyHint,
	_hint_string: String,
	_usage_flags,
	_wide: bool
) -> bool:
	# 仅处理typing_effect_audio属性
	if name == "typing_effect_audio":
		# 创建自定义EditorProperty控件实例，添加到检查器
		add_property_editor(name, AudioDropdownEditor.new("typewriter"))
		# 返回true移除Godot内置的资源选择器，仅显示自定义下拉
		return true
	# 其他属性使用官方默认编辑器
	return false
