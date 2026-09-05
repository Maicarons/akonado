extends KonadoCharacterSceneBase

var ready_completed := false

@onready var status_marker: Label = $StatusMarker


func _ready() -> void:
	ready_completed = status_marker != null


func _has_status(resolved_status_name: String, _original_status_name: String) -> bool:
	return ready_completed and status_marker != null and resolved_status_name == status_marker.text


func _apply_status(resolved_status_name: String, _original_status_name: String) -> void:
	status_marker.tooltip_text = resolved_status_name
