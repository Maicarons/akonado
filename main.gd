extends Control

## Main scene script for Akonado visual novel (Konado 2.8+)

@export var dialogue_manager: KonadoDialogueManager


func _ready() -> void:
	if dialogue_manager == null:
		push_error("dialogue_manager not assigned")
		return

	# Connect signals
	dialogue_manager.shot_end.connect(_on_shot_end)
	dialogue_manager.custom_signal.connect(_on_custom_signal)

	# Load the first .ks script using the Konado 2.8 compiler
	var compiler := KonadoScriptCompiler.new()
	var ks_path := "res://story/chapter01/chapter01_01.ks"

	if not FileAccess.file_exists(ks_path):
		push_error("Script file not found: " + ks_path)
		return

	var shot := compiler.compile_file(ks_path)
	if shot == null:
		push_error("Failed to compile script: " + ks_path)
		return

	# Set the compiled shot as the start dialogue
	dialogue_manager.start_dialogue_shot = shot

	# Initialize and start the dialogue
	dialogue_manager.init_dialogue()
	dialogue_manager.start_dialogue()


func _on_shot_end() -> void:
	print("Shot ended")
	# Optionally load next shot or return to menu


func _on_custom_signal(content: Variant) -> void:
	# Handle custom signals from .ks scripts
	print("Custom signal: ", content)