extends Control

@onready var progress_bar: ProgressBar = %VoiceProgressBar


func _ready() -> void:
	hide_progress()


func set_progress(current: float, total: float) -> void:
	if total <= 0.0:
		hide_progress()
		return
	progress_bar.max_value = total
	progress_bar.value = clampf(current, 0.0, total)
	show()


func hide_progress() -> void:
	if progress_bar:
		progress_bar.value = 0.0
	hide()
