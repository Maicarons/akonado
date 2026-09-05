extends RefCounted
class_name KonadoSaveCodec

## Strict binary codec for Konado save files.
##
## The payload uses Godot's object-free Variant representation so engine value
## types such as Vector2 round-trip without permitting object construction.

## Stable on-disk signature for Konado save data. The value is a file-format
## identifier rather than a source-code abbreviation.
const FILE_SIGNATURE := "KNDS"
const SIGNATURE_SIZE := 4
const CODEC_VERSION := 1
const DIGEST_SIZE := 32
const HEADER_SIZE := 42
const MAX_PAYLOAD_BYTES := 16 * 1024 * 1024


static func encode(data: Dictionary) -> PackedByteArray:
	var payload := var_to_bytes(data)
	if payload.is_empty() or payload.size() > MAX_PAYLOAD_BYTES:
		return PackedByteArray()
	var result := PackedByteArray()
	result.append_array(FILE_SIGNATURE.to_ascii_buffer())
	_append_u16(result, CODEC_VERSION)
	_append_u32(result, payload.size())
	result.append_array(_sha256(payload))
	result.append_array(payload)
	return result


static func decode(encoded: PackedByteArray) -> Dictionary:
	if encoded.size() < HEADER_SIZE or encoded.size() > HEADER_SIZE + MAX_PAYLOAD_BYTES:
		return {}
	if encoded.slice(0, SIGNATURE_SIZE).get_string_from_ascii() != FILE_SIGNATURE:
		return {}
	var version := _read_u16(encoded, SIGNATURE_SIZE)
	var payload_size := _read_u32(encoded, SIGNATURE_SIZE + 2)
	if version != CODEC_VERSION or payload_size <= 0 or payload_size > MAX_PAYLOAD_BYTES:
		return {}
	if encoded.size() != HEADER_SIZE + payload_size:
		return {}
	var expected_digest := encoded.slice(SIGNATURE_SIZE + 6, HEADER_SIZE)
	var payload := encoded.slice(HEADER_SIZE)
	if _sha256(payload) != expected_digest:
		return {}
	var decoded: Variant = bytes_to_var(payload)
	return decoded if decoded is Dictionary else {}


static func _append_u16(buffer: PackedByteArray, value: int) -> void:
	buffer.append(value & 0xff)
	buffer.append((value >> 8) & 0xff)


static func _sha256(value: PackedByteArray) -> PackedByteArray:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return PackedByteArray()
	if context.update(value) != OK:
		return PackedByteArray()
	return context.finish()


static func _append_u32(buffer: PackedByteArray, value: int) -> void:
	for shift in [0, 8, 16, 24]:
		buffer.append((value >> shift) & 0xff)


static func _read_u16(buffer: PackedByteArray, offset: int) -> int:
	return buffer[offset] | (buffer[offset + 1] << 8)


static func _read_u32(buffer: PackedByteArray, offset: int) -> int:
	return (
		buffer[offset]
		| (buffer[offset + 1] << 8)
		| (buffer[offset + 2] << 16)
		| (buffer[offset + 3] << 24)
	)
