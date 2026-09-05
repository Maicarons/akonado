extends SceneTree

const SCRIPT_PATH := "res://tests/editor/fixtures/native_editor.ks"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if Engine.is_editor_hint():
		var filesystem := EditorInterface.get_resource_filesystem()
		while filesystem.is_scanning() or filesystem.is_importing():
			await process_frame
		await process_frame
	var shot := ResourceLoader.load(SCRIPT_PATH) as KonadoShot
	if shot == null:
		push_error("KonadoScript runtime loader could not load %s" % SCRIPT_PATH)
		quit(1)
		return
	if shot.source_path != SCRIPT_PATH or shot.program == null or not shot.program.is_valid():
		push_error("KonadoScript runtime loader returned incomplete compiled data")
		quit(1)
		return
	print("PASS: KonadoScript runtime loader test")
	await process_frame
	quit()
