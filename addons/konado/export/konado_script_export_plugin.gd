@tool
extends EditorExportPlugin

## Encrypts compiled KonadoScript payloads with a preset-scoped key.

const EXPORT_CACHE_ROOT := "user://.konado_export"
const PROTECTED_RESOURCE_ROOT := "res://.konado_script_data"
const EXPORT_PRESETS_PATH := "res://export_presets.cfg"
const EXPORT_CREDENTIALS_PATH := "res://.godot/konado_export_credentials.cfg"
const EXPORT_KEY_OPTION := "konado/script_encryption_key"
const EXPORT_KEY_HEX_LENGTH := KonadoScriptProtection.KEY_SIZE * 2
const PROJECT_LINKER_SCRIPT := preload(
	"res://addons/konado/language/compiler/konado_script_project_linker.gd"
)

var _build_key := PackedByteArray()
var _export_cache_dir := ""
var _key_announced := false
var _key_generated := false
var _protected_shot_count := 0
var _failed_shot_count := 0
var _last_protection_error := ""
var _linked_entries := {}
var _project_linker: RefCounted


func _get_name() -> String:
	return "KonadoScriptProtection"


func _supports_platform(_platform: EditorExportPlatform) -> bool:
	return true


func _get_export_options(_platform: EditorExportPlatform) -> Array[Dictionary]:
	return [
		{
			"option":
			{
				"name": EXPORT_KEY_OPTION,
				"type": TYPE_STRING,
				"hint": PROPERTY_HINT_NONE,
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SECRET,
			},
			"default_value": "",
		}
	]


func _get_export_option_warning(_platform: EditorExportPlatform, option: String) -> String:
	if option != EXPORT_KEY_OPTION:
		return ""
	var configured_key := String(get_option(EXPORT_KEY_OPTION)).strip_edges()
	if configured_key.is_empty() or _is_valid_key_hex(configured_key):
		return ""
	if _is_chinese_editor():
		return "KonadoScript 加密密钥必须是 %d 位十六进制字符；导出时会用随机密钥替换非法值。" % EXPORT_KEY_HEX_LENGTH
	return (
		(
			"KonadoScript encryption key must contain exactly %d hexadecimal characters. "
			+ "An invalid value will be replaced with a random key when exporting."
		)
		% EXPORT_KEY_HEX_LENGTH
	)


func _is_chinese_editor() -> bool:
	return OS.get_locale().to_lower().begins_with("zh")


func _export_begin(_features: PackedStringArray, is_debug: bool, path: String, _flags: int) -> void:
	_start_export_key()
	var export_kind := "调试" if is_debug else "正式"
	if _build_key.size() != KonadoScriptProtection.KEY_SIZE:
		push_error("[Konado] %s导出 %s：剧本密钥初始化失败。" % [export_kind, path])
		return
	var key_action := "生成并保存新" if _key_generated else "复用预设"
	print("[Konado] %s导出 %s：已%s剧本密钥。" % [export_kind, path, key_action])
	_announce_key()


func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if path.get_extension().to_lower() != "ks":
		return
	if not _ensure_export_key():
		_register_export_failure(path)
		skip()
		return
	var protected_bytes := _protect_script(path)
	if protected_bytes.is_empty():
		_register_export_failure(path)
		skip()
		return
	var protected_path := PROTECTED_RESOURCE_ROOT.path_join("%s.res" % path.md5_text())
	add_file(protected_path, protected_bytes, false)
	add_file(path + ".remap", _build_remap(protected_path), false)
	skip()
	_protected_shot_count += 1


func _protect_script(path: String) -> PackedByteArray:
	_last_protection_error = ""
	if not _linked_entries.has(path):
		if _project_linker == null:
			_project_linker = PROJECT_LINKER_SCRIPT.new()
		if not _project_linker.call("link_additional", path):
			var messages := PackedStringArray()
			for diagnostic: Dictionary in _project_linker.call("get_errors"):
				messages.append(String(diagnostic.get("raw_message", "链接失败")))
			return _protection_failure("跨剧本依赖校验失败：%s" % "; ".join(messages))
		_linked_entries[path] = _project_linker.call("dependency_fingerprint")
	var source_shot := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as KonadoShot
	if source_shot == null:
		return _protection_failure("无法加载待加密的剧本资源")
	var protected_shot := source_shot.duplicate(true) as KonadoShot
	if protected_shot == null:
		return _protection_failure("无法复制待加密的剧本资源")
	if not protected_shot.protect_script_for_export(_build_key):
		return _protection_failure("无法加密剧本资源")
	if protected_shot.program != null:
		return _protection_failure("加密后仍残留明文 Program")
	return _serialize_protected_shot(protected_shot, path)


func _serialize_protected_shot(shot: KonadoShot, source_path: String) -> PackedByteArray:
	if _export_cache_dir.is_empty():
		return _protection_failure("剧本导出缓存目录尚未初始化")
	var cache_path := _export_cache_dir.path_join("%s.res" % source_path.md5_text())
	var absolute_cache_dir := ProjectSettings.globalize_path(cache_path.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(absolute_cache_dir) != OK:
		return _protection_failure("无法创建剧本导出缓存目录：%s" % absolute_cache_dir)
	var save_error := ResourceSaver.save(shot, cache_path)
	if save_error != OK:
		return _protection_failure("无法序列化加密剧本：%s" % error_string(save_error))
	var protected_bytes := FileAccess.get_file_as_bytes(cache_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cache_path))
	if protected_bytes.is_empty():
		return _protection_failure("加密剧本导出数据为空")
	return protected_bytes


func _build_remap(protected_path: String) -> PackedByteArray:
	return ('[remap]\n\npath="%s"\n' % protected_path).to_utf8_buffer()


func _export_end() -> void:
	if _failed_shot_count == 0:
		print("[Konado] 剧本加密完成，共保护 %d 个 KonadoShot 资源。" % _protected_shot_count)
	else:
		push_error("[Konado] 剧本加密失败，共有 %d 个资源未能保护。" % _failed_shot_count)
	_cleanup_export_cache()
	_build_key.clear()
	_export_cache_dir = ""
	_key_announced = false
	_key_generated = false
	_protected_shot_count = 0
	_failed_shot_count = 0
	_last_protection_error = ""
	_linked_entries.clear()
	_project_linker = null


func _start_export_key() -> void:
	_cleanup_export_cache()
	_linked_entries.clear()
	_project_linker = PROJECT_LINKER_SCRIPT.new()
	_build_key.clear()
	_export_cache_dir = EXPORT_CACHE_ROOT.path_join(
		Crypto.new().generate_random_bytes(8).hex_encode()
	)
	_key_announced = false
	_key_generated = false
	_protected_shot_count = 0
	_failed_shot_count = 0
	_last_protection_error = ""

	var configured_key := String(get_option(EXPORT_KEY_OPTION)).strip_edges()
	if configured_key.is_empty():
		configured_key = _load_persisted_key()
		if _is_valid_key_hex(configured_key):
			var preset := get_export_preset()
			if preset != null:
				preset.set(EXPORT_KEY_OPTION, configured_key)
	if _is_valid_key_hex(configured_key):
		_build_key = configured_key.to_lower().hex_decode()
		# 同步手动配置的有效密钥，确保移除 Godot 通用凭据文件后仍可继续复用。
		if not _persist_key(configured_key):
			push_warning("[Konado] 无法同步剧本密钥到 Konado 独立凭据文件。")
		return

	_key_generated = true
	_build_key = Crypto.new().generate_random_bytes(KonadoScriptProtection.KEY_SIZE)
	if not _persist_key(_build_key.hex_encode()):
		_build_key.clear()
		_last_protection_error = "无法将自动生成的密钥保存到当前导出预设"


func _load_persisted_key() -> String:
	var preset := get_export_preset()
	if preset == null:
		return ""
	var preset_section := _find_current_preset_section(preset.get_preset_name())
	if preset_section.is_empty() or not FileAccess.file_exists(EXPORT_CREDENTIALS_PATH):
		return ""
	var credentials := ConfigFile.new()
	if credentials.load(EXPORT_CREDENTIALS_PATH) != OK:
		push_warning("[Konado] 无法读取 Konado 剧本导出凭据文件。")
		return ""
	return (
		String(credentials.get_value(preset_section + ".options", EXPORT_KEY_OPTION, ""))
		. strip_edges()
	)


func _persist_key(key_hex: String) -> bool:
	var preset := get_export_preset()
	if preset == null:
		push_error("[Konado] 无法写回剧本密钥：当前导出预设不可用。")
		return false
	preset.set(EXPORT_KEY_OPTION, key_hex)
	if String(preset.get(EXPORT_KEY_OPTION)) != key_hex:
		push_error("[Konado] 无法写回剧本密钥：导出预设拒绝了 Konado 选项。")
		return false
	preset.notify_property_list_changed()
	var preset_section := _find_current_preset_section(preset.get_preset_name())
	if preset_section.is_empty():
		push_error("[Konado] 无法写回剧本密钥：找不到当前导出预设。")
		return false
	var credentials := ConfigFile.new()
	if (
		FileAccess.file_exists(EXPORT_CREDENTIALS_PATH)
		and credentials.load(EXPORT_CREDENTIALS_PATH) != OK
	):
		push_error("[Konado] 无法读取 Konado 剧本导出凭据文件。")
		return false
	credentials.set_value(preset_section + ".options", EXPORT_KEY_OPTION, key_hex)
	var save_error := credentials.save(EXPORT_CREDENTIALS_PATH)
	if save_error != OK:
		push_error("[Konado] 无法保存 Konado 剧本导出凭据：%s" % error_string(save_error))
		return false
	return true


func _find_current_preset_section(preset_name: String) -> String:
	var presets := ConfigFile.new()
	if presets.load(EXPORT_PRESETS_PATH) != OK:
		return ""
	for section: String in presets.get_sections():
		if not section.begins_with("preset.") or section.ends_with(".options"):
			continue
		if presets.get_value(section, "name", "") == preset_name:
			return section
	return ""


func _is_valid_key_hex(key_hex: String) -> bool:
	var normalized := key_hex.strip_edges()
	return normalized.length() == EXPORT_KEY_HEX_LENGTH and normalized.is_valid_hex_number(false)


func _ensure_export_key() -> bool:
	return _build_key.size() == KonadoScriptProtection.KEY_SIZE


func _announce_key() -> void:
	if _key_announced:
		return
	_key_announced = true
	var key_hex := _build_key.hex_encode()
	if OS.has_environment("GITHUB_ACTIONS"):
		print("::add-mask::%s" % key_hex)
		print("[Konado] 本次导出剧本密钥：***（GitHub Actions 日志已自动隐藏）")
		return
	print("[Konado] 本次导出剧本密钥：%s" % key_hex)


func _protection_failure(message: String) -> PackedByteArray:
	_last_protection_error = message
	return PackedByteArray()


func _register_export_failure(path: String) -> void:
	_failed_shot_count += 1
	var reason := _last_protection_error
	if reason.is_empty():
		reason = "未知剧本保护错误"
	var message := "%s：%s" % [path, reason]
	push_error("[Konado] " + message)
	var export_platform := get_export_platform()
	if export_platform:
		export_platform.add_message(
			EditorExportPlatform.EXPORT_MESSAGE_ERROR, "KonadoScript Protection", message
		)


func _cleanup_export_cache() -> void:
	if _export_cache_dir.is_empty():
		return
	var directory := DirAccess.open(_export_cache_dir)
	if directory:
		directory.list_dir_begin()
		var entry := directory.get_next()
		while not entry.is_empty():
			if not directory.current_is_dir():
				DirAccess.remove_absolute(
					ProjectSettings.globalize_path(_export_cache_dir.path_join(entry))
				)
			entry = directory.get_next()
		directory.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_export_cache_dir))
