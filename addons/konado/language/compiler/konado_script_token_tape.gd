extends RefCounted
class_name KonadoScriptTokenTape

## Canonical compact token storage shared by compilation and editor services.
##
## Token types and source ranges are stored in packed columns. Consumers ask
## for short-lived token views only when they need object-style access, avoiding
## one permanently retained RefCounted object per token without creating a
## second lexer path or weakening any parser or semantic validation stage.

var types := PackedInt32Array()
var values: Array = []
var lines := PackedInt32Array()
var columns := PackedInt32Array()
var lengths := PackedInt32Array()
var start_offsets := PackedInt32Array()
var end_offsets := PackedInt32Array()
var _estimated_value_bytes := 0


func append(token: KonadoScriptToken) -> void:
	types.append(token.type)
	values.append(token.value)
	_estimated_value_bytes += _estimate_value_bytes(token.value)
	lines.append(token.line)
	columns.append(token.column)
	lengths.append(token.length)
	start_offsets.append(token.start_offset)
	end_offsets.append(token.end_offset)


func size() -> int:
	return types.size()


func is_empty() -> bool:
	return types.is_empty()


func estimated_size_bytes() -> int:
	# Six packed integer columns plus the Variant slot and retained token value.
	return size() * 40 + _estimated_value_bytes


func type_at(index: int) -> int:
	return types[index] if index >= 0 and index < types.size() else KonadoScriptToken.Type.EOF


func token_at(index: int) -> KonadoScriptToken:
	if index < 0 or index >= types.size():
		return KonadoScriptToken.new(KonadoScriptToken.Type.EOF, "", 0, 0)
	var token := KonadoScriptToken.new(
		types[index], values[index], lines[index], columns[index], lengths[index]
	)
	token.start_offset = start_offsets[index]
	token.end_offset = end_offsets[index]
	return token


func clear() -> void:
	types.clear()
	values.clear()
	lines.clear()
	columns.clear()
	lengths.clear()
	start_offsets.clear()
	end_offsets.clear()
	_estimated_value_bytes = 0


func _estimate_value_bytes(value: Variant) -> int:
	if value is String:
		return 16 + String(value).length() * 4
	if value is Dictionary:
		return 128
	return 16
