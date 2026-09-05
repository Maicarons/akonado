extends KonadoCharacterSceneBase

var size_during_initial_status := Vector2.ZERO


func _has_status(resolved_status_name: String, _original_status_name: String) -> bool:
	return resolved_status_name == "layout_ready"


func _apply_status(_resolved_status_name: String, _original_status_name: String) -> void:
	# 基类刻意继承 Node，以允许 Sprite2D、Control 和第三方渲染节点作为场景根节点。
	# 本夹具的根节点明确是 Control，但脚本静态类型仍是 Node，因此通过属性协议读取。
	var current_size: Variant = get("size")
	if current_size is Vector2:
		size_during_initial_status = current_size
