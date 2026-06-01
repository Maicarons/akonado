extends Control

## Main scene script for Akonado visual novel

@onready var dialogue_manager = $KonadoDialogueManager

func _ready():
	# Connect to shot end signal
	dialogue_manager.shot_end.connect(_on_shot_end)

	# Load the first .ks script using the interpreter
	var interpreter = KonadoScriptsInterpreter.new()
	var ks_path = "res://story/chapter01/chapter01_01.ks"

	# Check if the .ks file exists
	if not FileAccess.file_exists(ks_path):
		push_error("Script file not found: " + ks_path)
		return

	# Parse the .ks file into a KND_Shot
	var shot = interpreter.process_scripts_to_data(ks_path)
	if shot == null:
		push_error("Failed to parse script: " + ks_path)
		return

	# Set the parsed shot as the start dialogue
	dialogue_manager.start_dialogue_shot = shot

	# Initialize and start the dialogue
	dialogue_manager.init_dialogue()
	dialogue_manager.start_dialogue()

func _on_shot_end():
	# When shot ends, restart the scene after a delay
	print("Shot ended - restarting in 2 seconds")
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()
