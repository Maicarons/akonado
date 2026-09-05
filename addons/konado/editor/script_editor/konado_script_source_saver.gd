@tool
extends ResourceFormatSaver
class_name KonadoScriptSourceSaver

## Saves the source text held by a loaded KonadoShot back to its .ks file.
##
## The format loader owns compilation and export remapping. Restricting this saver
## to the .ks extension keeps normal KonadoShot serialization untouched.

const ATOMIC_FILE_SCRIPT := preload(
	"res://addons/konado/language/service/konado_script_atomic_file.gd"
)


func _recognize(resource: Resource) -> bool:
	return resource is KonadoShot


func _get_recognized_extensions(resource: Resource) -> PackedStringArray:
	if resource is KonadoShot:
		return PackedStringArray(["ks"])
	return PackedStringArray()


func _save(resource: Resource, path: String, _flags: int) -> Error:
	if not resource is KonadoShot or path.get_extension().to_lower() != "ks":
		return ERR_UNAVAILABLE
	var save_error := ATOMIC_FILE_SCRIPT.replace_text(
		path, (resource as KonadoShot).get_source_code()
	)
	if save_error != OK:
		return save_error
	_refresh_compiled_data(resource as KonadoShot, path)
	return OK


func _refresh_compiled_data(shot: KonadoShot, path: String) -> void:
	var compiler := KonadoScriptCompiler.new()
	compiler.set_console_output_enabled(false)
	var compiled := compiler.compile_string(shot.get_source_code(), path)
	if compiled == null:
		# The source file is authoritative. Keeping the previous Program would make
		# the editor show invalid new text while test runs execute stale old code.
		shot.source_path = path
		shot.dependent_characters.clear()
		shot.dependencies.clear()
		shot.install_program(null)
		shot.emit_changed()
		return
	shot.source_path = path
	shot.shot_id = compiled.shot_id
	shot.dependent_characters = compiled.dependent_characters
	shot.dependencies = compiled.dependencies
	shot.install_program(compiled.program)
	shot.emit_changed()
