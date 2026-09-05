extends RefCounted
class_name KonadoScriptSourceNormalizer

## Normalizes platform-specific source representation before lexing while
## keeping the public source text and line numbers predictable.


static func normalize(source: String) -> String:
	return _normalize_text(source)


static func normalize_with_map(source: String) -> Dictionary:
	var normalized_to_raw := PackedInt32Array()
	var content_start := 1 if source.begins_with("\ufeff") else 0
	var normalized := _normalize_text(source)

	# Mapping remains linear and allocation-efficient: string construction is
	# delegated to Godot's native replace implementation instead of repeatedly
	# appending immutable String values in GDScript.
	var raw_index := content_start
	while raw_index < source.length():
		normalized_to_raw.append(raw_index)
		if source[raw_index] == "\r":
			raw_index += (
				2 if raw_index + 1 < source.length() and source[raw_index + 1] == "\n" else 1
			)
		else:
			raw_index += 1
	normalized_to_raw.append(source.length())
	return {"text": normalized, "normalized_to_raw": normalized_to_raw}


static func sha256(source: String) -> String:
	return normalize(source).sha256_text()


static func _normalize_text(source: String) -> String:
	var normalized := source.substr(1) if source.begins_with("\ufeff") else source
	if normalized.contains("\r"):
		normalized = normalized.replace("\r\n", "\n").replace("\r", "\n")
	return normalized
