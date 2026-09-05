extends SceneTree

const SCRIPT_PATH := "res://sample/demo/demo_01.ks"
const PROTECTED_RESOURCE_ROOT := "res://.konado_script_data"
const PLAINTEXT_MARKER := "你好！欢迎来到我们的咖啡馆。"

var _failures := 0


func _init() -> void:
	var script_paths := _get_expected_script_paths()
	_expect(not script_paths.is_empty(), "expected sample script paths are available")
	for script_path in script_paths:
		_expect_script_loads(script_path)

	var protected_path := PROTECTED_RESOURCE_ROOT.path_join("%s.res" % SCRIPT_PATH.md5_text())
	var exported_bytes := FileAccess.get_file_as_bytes(protected_path)
	_expect(
		not _contains_bytes(exported_bytes, PLAINTEXT_MARKER.to_utf8_buffer()),
		"exported KS resource does not contain plaintext dialogue"
	)

	var shot := ResourceLoader.load(SCRIPT_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as KonadoShot
	_expect(shot != null, "exported KS resource loads as KonadoShot")
	if shot != null:
		_expect(shot.is_script_protected(), "exported KonadoShot contains a protected payload")
		_expect(shot.ensure_script_ready(), "exported KonadoShot decrypts at runtime")
		_expect(shot.program != null, "exported KonadoShot restores its Program")
		_expect(
			_has_dialogue_content(shot.program, PLAINTEXT_MARKER),
			"decrypted KonadoShot restores dialogue content"
		)
		_expect(
			not shot.is_script_protected(), "decrypted KonadoShot releases its encrypted buffers"
		)

	if _failures == 0:
		print("PASS: exported script protection")
	quit(_failures)


func _get_expected_script_paths() -> Array[String]:
	var result: Array[String] = []
	for path in OS.get_environment("KONADO_EXPECTED_KS_PATHS").split(";", false):
		var resource_path := String(path)
		if not resource_path.begins_with("res://"):
			resource_path = "res://" + resource_path
		result.append(resource_path)
	return result


func _expect_script_loads(path: String) -> void:
	_expect(
		FileAccess.get_file_as_bytes(path).is_empty(),
		"source KS file is absent from the export: %s" % path
	)
	var protected_path := PROTECTED_RESOURCE_ROOT.path_join("%s.res" % path.md5_text())
	_expect(
		not FileAccess.get_file_as_bytes(protected_path).is_empty(),
		"protected KS resource is present: %s" % path
	)
	var shot := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as KonadoShot
	_expect(shot != null, "exported KS resource loads: %s" % path)
	if shot != null:
		_expect(shot.is_script_protected(), "exported KS resource is protected: %s" % path)
		_expect(shot.program == null, "exported KS resource stores no plaintext Program: %s" % path)
		_expect(shot.ensure_script_ready(), "exported KS resource decrypts: %s" % path)
		_expect(shot.instruction_count() > 0, "exported KS resource restores Program: %s" % path)
		_expect(
			not shot.is_script_protected(),
			"exported KS resource clears protected buffers: %s" % path
		)


func _has_dialogue_content(program: KonadoProgram, expected: String) -> bool:
	if program == null:
		return false
	for pc in range(program.instruction_count()):
		var instruction := program.instruction_at(pc)
		if (
			instruction.opcode() == KonadoOpcode.Type.DIALOGUE
			and instruction.value(&"content") == expected
		):
			return true
	return false


func _contains_bytes(haystack: PackedByteArray, needle: PackedByteArray) -> bool:
	if needle.is_empty():
		return true
	if needle.size() > haystack.size():
		return false
	for start in range(haystack.size() - needle.size() + 1):
		var matches := true
		for offset in range(needle.size()):
			if haystack[start + offset] == needle[offset]:
				continue
			matches = false
			break
		if matches:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("FAIL: " + message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		return
	_failures += 1
	printerr("FAIL: %s\n  expected: %s\n  actual:   %s" % [message, expected, actual])
