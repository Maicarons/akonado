@tool
extends EditorResourceTooltipPlugin


func _handles(type: String) -> bool:
	return type in ["Resource", "Script", "KonadoShot"]


func _make_tooltip_for_path(path: String, _metadata: Dictionary, base: Control) -> Control:
	if path.get_extension().to_lower() != "ks":
		return base
	var type_label := Label.new()
	type_label.text = "KonadoScript"
	base.add_child(type_label)
	return base
