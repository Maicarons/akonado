extends RefCounted
class_name KonadoStageUtilities

## Stateless helpers shared by the stage controller's layout and persistence
## boundaries. Runtime scene nodes and active tweens never enter snapshots.


static func set_full_rect(control: Control) -> void:
	if control == null:
		return
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
	control.position = Vector2.ZERO
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL


static func capture_state(
	background_id: String,
	actor_states: Dictionary[String, Dictionary],
	highlighted_actor_id: String,
) -> Dictionary:
	var actors: Array[Dictionary] = []
	for actor_id in actor_states:
		var actor_data: Dictionary = actor_states[actor_id]
		(
			actors
			. append(
				{
					"id": String(actor_id),
					"horizontal_division": int(actor_data.get("horizontal_division", 5)),
					"position": int(actor_data.get("horizontal_position", 0)),
					"state": String(actor_data.get("state", "")),
				}
			)
		)
	actors.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return left.id < right.id)
	return {
		"background": background_id,
		"actors": actors,
		"highlighted_actor": highlighted_actor_id,
	}
