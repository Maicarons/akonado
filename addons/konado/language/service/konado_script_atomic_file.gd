@tool
extends RefCounted
class_name KonadoScriptAtomicFile

## Crash-resistant text replacement shared by source saving and project refactors.
##
## The temporary file is written beside the destination so the final rename stays
## on the same filesystem. An existing destination is retained as a backup until
## the replacement succeeds.


static func replace_text(path: String, source: String) -> Error:
	if path.is_empty():
		return ERR_INVALID_PARAMETER
	var absolute_path := ProjectSettings.globalize_path(path)
	var nonce := "%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var temporary_path := "%s.konado-tmp-%s" % [absolute_path, nonce]
	var backup_path := "%s.konado-backup-%s" % [absolute_path, nonce]
	var temporary := FileAccess.open(temporary_path, FileAccess.WRITE)
	if temporary == null:
		return FileAccess.get_open_error()
	temporary.store_string(source)
	temporary.flush()
	var write_error := temporary.get_error()
	temporary = null
	if write_error != OK:
		DirAccess.remove_absolute(temporary_path)
		return write_error

	var had_original := FileAccess.file_exists(absolute_path)
	if had_original:
		var backup_error := DirAccess.rename_absolute(absolute_path, backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(temporary_path)
			return backup_error
	var replace_error := DirAccess.rename_absolute(temporary_path, absolute_path)
	if replace_error != OK:
		if had_original:
			var restore_error := DirAccess.rename_absolute(backup_path, absolute_path)
			if restore_error != OK:
				push_error(
					(
						"Konado could not restore '%s' after an atomic write failure: %s"
						% [path, error_string(restore_error)]
					)
				)
		return replace_error
	if had_original:
		DirAccess.remove_absolute(backup_path)
	return OK
