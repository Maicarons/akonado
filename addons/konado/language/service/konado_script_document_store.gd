@tool
extends RefCounted
class_name KonadoScriptDocumentStore

## Shared revision cache for disk files and unsaved Script Editor buffers.

const MAX_CACHED_DOCUMENTS := 128
const MAX_CACHE_BYTES := 64 * 1024 * 1024

static var _shared_instance: KonadoScriptDocumentStore

var _documents := {}
var _cache_costs := {}
var _last_access := {}
var _disk_metadata := {}
var _access_serial := 0
var _cache_bytes := 0


static func shared() -> KonadoScriptDocumentStore:
	if _shared_instance == null:
		_shared_instance = KonadoScriptDocumentStore.new()
	return _shared_instance


func get_document(path: String) -> KonadoScriptDocument:
	var document := _get_or_create(path)
	var open_buffer := _find_open_buffer(path)
	if bool(open_buffer.get("found", false)):
		document.update(String(open_buffer.get("source", "")), path)
	elif FileAccess.file_exists(path):
		var metadata := {
			"modified_time": FileAccess.get_modified_time(path),
			"file_size": FileAccess.get_size(path),
		}
		if _disk_metadata.get(path, {}) == metadata:
			_update_cache_cost(path, document)
			_evict_if_needed(path)
			return document
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			document.update(file.get_as_text(), path)
			_disk_metadata[path] = metadata
	else:
		document.update("", path)
		_disk_metadata.erase(path)
	_update_cache_cost(path, document)
	_evict_if_needed(path)
	return document


func update_buffer(path: String, source: String) -> KonadoScriptDocument:
	var document := _get_or_create(path)
	document.update(source, path)
	# The cached revision now represents an editor buffer rather than the last
	# observed disk file. Force one disk read after that buffer closes.
	_disk_metadata.erase(path)
	_update_cache_cost(path, document)
	_evict_if_needed(path)
	return document


func get_open_source(path: String) -> String:
	return String(_find_open_buffer(path).get("source", ""))


func _find_open_buffer(path: String) -> Dictionary:
	if not Engine.is_editor_hint():
		return {"found": false}
	var script_editor := EditorInterface.get_script_editor()
	if script_editor == null:
		return {"found": false}
	for script: Script in script_editor.get_open_scripts():
		if script != null and script.resource_path == path:
			return {"found": true, "source": script.source_code}
	return {"found": false}


func _get_or_create(path: String) -> KonadoScriptDocument:
	_access_serial += 1
	_last_access[path] = _access_serial
	var document: KonadoScriptDocument = _documents.get(path)
	if document == null:
		document = KonadoScriptDocument.new()
		_documents[path] = document
	return document


func invalidate(path: String = "") -> void:
	if path.is_empty():
		_documents.clear()
		_cache_costs.clear()
		_last_access.clear()
		_disk_metadata.clear()
		_cache_bytes = 0
	else:
		_remove(path)


func get_cached_paths() -> PackedStringArray:
	var paths := PackedStringArray(_documents.keys())
	paths.sort()
	return paths


func _update_cache_cost(path: String, document: KonadoScriptDocument) -> void:
	var previous := int(_cache_costs.get(path, 0))
	var estimated := (
		document.source.length() * 4
		+ int(document.tokens.call("estimated_size_bytes"))
		+ document.references.size() * 160
		+ 512
	)
	_cache_costs[path] = estimated
	_cache_bytes += estimated - previous


func _evict_if_needed(protected_path: String) -> void:
	while _documents.size() > MAX_CACHED_DOCUMENTS or _cache_bytes > MAX_CACHE_BYTES:
		var oldest_path := ""
		var oldest_access := _access_serial + 1
		for cached_path: String in _documents:
			if cached_path == protected_path:
				continue
			var access := int(_last_access.get(cached_path, 0))
			if access < oldest_access:
				oldest_access = access
				oldest_path = cached_path
		if oldest_path.is_empty():
			break
		_remove(oldest_path)


func _remove(path: String) -> void:
	_cache_bytes -= int(_cache_costs.get(path, 0))
	_cache_bytes = maxi(0, _cache_bytes)
	_documents.erase(path)
	_cache_costs.erase(path)
	_last_access.erase(path)
	_disk_metadata.erase(path)
