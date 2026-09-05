@tool
extends RefCounted
class_name KonadoScriptProtection

## Runtime codec used by the export pipeline to protect compiled KonadoScript dialogue data.
##
## This is transparent export-time protection, not DRM. The build key must remain
## recoverable by the client so the goal is to prevent direct PCK resource
## extraction, rather than to resist targeted runtime reverse engineering.

const FORMAT_VERSION := 3
const KEY_SIZE := 32
const IV_SIZE := 16
const BLOCK_SIZE := 16
const MAC_SIZE := 32
const AUTH_HEADER_SIZE := 16
const MAX_SERIALIZED_MIB := 64
const MAX_SERIALIZED_SIZE := MAX_SERIALIZED_MIB * 1024 * 1024
const MAX_CIPHERTEXT_SIZE := MAX_SERIALIZED_SIZE + 1024 * 1024
const WRAP_SALT := "Konado.ScriptProtection.v3"
const ENCRYPTION_KEY_CONTEXT := "Konado.ScriptProtection.Encryption.v3"
const AUTHENTICATION_KEY_CONTEXT := "Konado.ScriptProtection.Authentication.v3"


static func protect_program(
	program: KonadoProgram, build_key: PackedByteArray, source_path: String
) -> Dictionary:
	if build_key.size() != KEY_SIZE:
		return _failure("剧本加密密钥必须为 %d 字节" % KEY_SIZE)
	if program == null or not program.is_valid():
		return _failure("剧本 Program 无效")

	var serialized := var_to_bytes(program.to_payload())
	if serialized.is_empty():
		return _failure("剧本序列化失败")
	if serialized.size() > MAX_SERIALIZED_SIZE:
		return _failure("剧本序列化数据超过 %d MiB 上限" % MAX_SERIALIZED_MIB)
	var compressed := serialized.compress(FileAccess.COMPRESSION_ZSTD)
	if compressed.is_empty():
		return _failure("剧本压缩失败")
	var padded := _add_pkcs7_padding(compressed)
	var crypto := Crypto.new()
	var iv := crypto.generate_random_bytes(IV_SIZE)
	if iv.size() != IV_SIZE:
		return _failure("无法生成剧本加密随机向量")
	var encryption_key := _derive_subkey(build_key, ENCRYPTION_KEY_CONTEXT, iv, source_path)
	var authentication_key := _derive_subkey(build_key, AUTHENTICATION_KEY_CONTEXT, iv, source_path)
	if encryption_key.size() != KEY_SIZE or authentication_key.size() != KEY_SIZE:
		return _failure("无法派生剧本保护密钥")
	var aes := AESContext.new()
	var start_error := aes.start(AESContext.MODE_CBC_ENCRYPT, encryption_key, iv)
	if start_error != OK:
		return _failure("无法初始化 AES-256 加密器：%s" % error_string(start_error))
	var ciphertext := aes.update(padded)
	aes.finish()
	if ciphertext.is_empty() or ciphertext.size() > MAX_CIPHERTEXT_SIZE:
		return _failure("剧本加密失败")

	var wrapped_key := _xor_bytes(build_key, _derive_key_mask(iv, source_path))
	var authenticated_data := _build_authenticated_data(
		FORMAT_VERSION, serialized.size(), iv, wrapped_key, ciphertext, source_path
	)
	var mac := crypto.hmac_digest(
		HashingContext.HASH_SHA256, authentication_key, authenticated_data
	)
	if mac.size() != MAC_SIZE:
		return _failure("无法生成剧本完整性校验值")
	return {
		"ok": true,
		"version": FORMAT_VERSION,
		"serialized_size": serialized.size(),
		"iv": iv,
		"wrapped_key": wrapped_key,
		"ciphertext": ciphertext,
		"mac": mac,
	}


static func unprotect(
	version: int,
	serialized_size: int,
	iv: PackedByteArray,
	wrapped_key: PackedByteArray,
	ciphertext: PackedByteArray,
	mac: PackedByteArray,
	source_path: String
) -> Dictionary:
	if version != FORMAT_VERSION:
		return _failure("不支持的加密剧本格式版本：%d" % version)
	if serialized_size <= 0 or serialized_size > MAX_SERIALIZED_SIZE:
		return _failure("加密剧本缺少有效的原始数据长度")
	if (
		iv.size() != IV_SIZE
		or wrapped_key.size() != KEY_SIZE
		or ciphertext.is_empty()
		or ciphertext.size() > MAX_CIPHERTEXT_SIZE
		or mac.size() != MAC_SIZE
	):
		return _failure("加密剧本数据不完整")
	if ciphertext.size() % BLOCK_SIZE != 0:
		return _failure("加密剧本块长度无效")

	var build_key := _xor_bytes(wrapped_key, _derive_key_mask(iv, source_path))
	var encryption_key := _derive_subkey(build_key, ENCRYPTION_KEY_CONTEXT, iv, source_path)
	var authentication_key := _derive_subkey(build_key, AUTHENTICATION_KEY_CONTEXT, iv, source_path)
	if encryption_key.size() != KEY_SIZE or authentication_key.size() != KEY_SIZE:
		return _failure("无法派生剧本保护密钥")
	var authenticated_data := _build_authenticated_data(
		version, serialized_size, iv, wrapped_key, ciphertext, source_path
	)
	var crypto := Crypto.new()
	var expected_mac := crypto.hmac_digest(
		HashingContext.HASH_SHA256, authentication_key, authenticated_data
	)
	if expected_mac.size() != MAC_SIZE:
		return _failure("无法计算剧本完整性校验值")
	if not crypto.constant_time_compare(expected_mac, mac):
		return _failure("加密剧本完整性校验失败")

	var aes := AESContext.new()
	var start_error := aes.start(AESContext.MODE_CBC_DECRYPT, encryption_key, iv)
	if start_error != OK:
		return _failure("无法初始化 AES-256 解密器：%s" % error_string(start_error))
	var padded := aes.update(ciphertext)
	aes.finish()
	var compressed := _remove_pkcs7_padding(padded)
	if compressed.is_empty():
		return _failure("加密剧本填充无效")
	var serialized := compressed.decompress(serialized_size, FileAccess.COMPRESSION_ZSTD)
	if serialized.is_empty() or serialized.size() != serialized_size:
		return _failure("加密剧本解压失败")

	var decoded: Variant = bytes_to_var(serialized)
	if typeof(decoded) != TYPE_DICTIONARY:
		return _failure("加密剧本反序列化结果不是 Program 载荷")
	var program := KonadoProgram.from_payload(decoded)
	if program == null:
		return _failure("加密剧本 Program 的 ABI 或结构无效")
	return {"ok": true, "program": program}


static func _build_authenticated_data(
	version: int,
	serialized_size: int,
	iv: PackedByteArray,
	wrapped_key: PackedByteArray,
	ciphertext: PackedByteArray,
	source_path: String
) -> PackedByteArray:
	var path_bytes := source_path.to_utf8_buffer()
	var result := PackedByteArray()
	result.resize(AUTH_HEADER_SIZE)
	result.encode_u32(0, version)
	result.encode_u64(4, serialized_size)
	result.encode_u32(12, path_bytes.size())
	result.append_array(path_bytes)
	result.append_array(iv)
	result.append_array(wrapped_key)
	result.append_array(ciphertext)
	return result


static func _add_pkcs7_padding(data: PackedByteArray) -> PackedByteArray:
	var result := data.duplicate()
	var padding_size := BLOCK_SIZE - result.size() % BLOCK_SIZE
	result.resize(result.size() + padding_size)
	for index in range(result.size() - padding_size, result.size()):
		result[index] = padding_size
	return result


static func _remove_pkcs7_padding(data: PackedByteArray) -> PackedByteArray:
	if data.is_empty() or data.size() % BLOCK_SIZE != 0:
		return PackedByteArray()
	var padding_size := int(data[data.size() - 1])
	if padding_size <= 0 or padding_size > BLOCK_SIZE or padding_size > data.size():
		return PackedByteArray()
	for index in range(data.size() - padding_size, data.size()):
		if int(data[index]) != padding_size:
			return PackedByteArray()
	return data.slice(0, data.size() - padding_size)


static func _derive_key_mask(iv: PackedByteArray, source_path: String) -> PackedByteArray:
	var material := iv.duplicate()
	material.append_array(source_path.to_utf8_buffer())
	material.append_array(WRAP_SALT.to_utf8_buffer())
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(material)
	return context.finish()


static func _derive_subkey(
	build_key: PackedByteArray, domain: String, iv: PackedByteArray, source_path: String
) -> PackedByteArray:
	var material := domain.to_utf8_buffer()
	material.append(0)
	material.append_array(source_path.to_utf8_buffer())
	material.append(0)
	material.append_array(iv)
	return Crypto.new().hmac_digest(HashingContext.HASH_SHA256, build_key, material)


static func _xor_bytes(left: PackedByteArray, right: PackedByteArray) -> PackedByteArray:
	if left.size() != right.size():
		return PackedByteArray()
	var result := PackedByteArray()
	result.resize(left.size())
	for index in range(left.size()):
		result[index] = left[index] ^ right[index]
	return result


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}
