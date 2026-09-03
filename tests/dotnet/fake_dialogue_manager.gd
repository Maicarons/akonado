extends Node

signal shot_start
signal shot_end
signal dialogue_line_start(instruction_id: String)
signal dialogue_line_end(instruction_id: String)
signal custom_signal(content: String)
signal runtime_failed(message: String, instruction_id: String, source_line: int)
signal runtime_failure_reported(failure: Dictionary)
signal runtime_failure_resolved(failure: Dictionary, resolution: StringName)

var last_shot: Resource
var character_list: Resource
var background_list: Resource
var background_music_list: Resource
var voice_list: Resource
var sound_effect_list: Resource
var variable_store: Resource
var rollback_calls := 0
var history_cleared := false
var restored_checkpoint := ""
var recovery_action := &""
var pending_runtime_failure := {
	"code": "test.failure",
	"recoverable": true,
	"recovery_actions":
	PackedStringArray(["retry", "skip", "continue_true", "continue_false", "stop"]),
}


func init_dialogue(_callback: Callable = Callable()) -> void:
	pass


func set_shot(shot: Resource) -> void:
	last_shot = shot


func start_dialogue() -> void:
	pass


func stop_dialogue() -> void:
	pass


func start_autoplay(_enabled: bool) -> void:
	pass


func get_dialogue_variable(_name: String) -> Variant:
	return null


func save_game(_save_id: int) -> bool:
	return true


func load_game(_save_id: int) -> bool:
	return true


func delete_save(_save_id: int) -> bool:
	return true


func get_save_info(_save_id: int) -> Dictionary:
	return {}


func get_all_save_info() -> Array[Dictionary]:
	return []


func reload_localized_script(_locale: String = "") -> bool:
	return true


func emit_wait_signal(_signal_name: String) -> bool:
	return true


func resolve_runtime_failure(action: StringName) -> bool:
	if action not in pending_runtime_failure.recovery_actions:
		return false
	recovery_action = action
	return true


func can_rollback(steps := 1) -> bool:
	return steps == 1


func rollback(steps := 1) -> bool:
	rollback_calls += steps
	return steps == 1


func get_execution_history(limit := 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"instruction_id": "test"}]
	return result if limit == 0 else result.slice(0, limit)


func clear_execution_history() -> void:
	history_cleared = true


func create_checkpoint(label := "") -> String:
	return "checkpoint:" + label


func restore_checkpoint(checkpoint_id: String) -> bool:
	restored_checkpoint = checkpoint_id
	return not checkpoint_id.is_empty()
