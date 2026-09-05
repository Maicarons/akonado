extends RefCounted

var _warned_fallbacks := {}


func get_script_candidates(script_path: String, locale: String) -> PackedStringArray:
	var base_path := get_base_script_path(script_path)
	var extension := base_path.get_extension()
	var stem := base_path.trim_suffix("." + extension) if not extension.is_empty() else base_path
	var candidates := PackedStringArray()

	for candidate_locale: String in _get_locale_fallbacks(locale):
		_append_localized_candidate(candidates, stem, candidate_locale, extension)
	_append_unique(candidates, base_path)
	return candidates


func resolve_script_path(
	script_path: String, locale: String, warn_on_fallback: bool = true
) -> String:
	if script_path.strip_edges().is_empty():
		push_error("KonadoStoryLocalization: script path is empty")
		return ""

	var candidates := get_script_candidates(script_path, locale)
	for index in range(candidates.size()):
		var candidate := candidates[index]
		if not _resource_exists(candidate):
			continue
		if index > 0 and warn_on_fallback:
			_warn_fallback_once(script_path, locale, candidate)
		return candidate
	push_error("KonadoStoryLocalization: no script found for %s" % script_path)
	return ""


func load_localized_script(
	script_path: String, locale: String, warn_on_fallback: bool = true
) -> KonadoShot:
	var base_path := get_base_script_path(script_path)
	var base_shot := _load_shot(base_path)
	if base_shot == null or base_shot.program == null:
		push_error("KonadoStoryLocalization: failed to load default script %s" % base_path)
		return null
	var resolved_path := resolve_script_path(script_path, locale, warn_on_fallback)
	if resolved_path.is_empty():
		return null
	var runtime_shot := base_shot.duplicate() as KonadoShot
	runtime_shot.source_path = resolved_path
	if resolved_path == base_path:
		runtime_shot.install_locale_overlay(null)
		return runtime_shot
	return _apply_locale_overlay(runtime_shot, base_shot, resolved_path, locale)


func _apply_locale_overlay(
	runtime_shot: KonadoShot, base_shot: KonadoShot, resolved_path: String, locale: String
) -> KonadoShot:
	var localized_shot := _load_shot(resolved_path)
	if localized_shot == null or localized_shot.program == null:
		push_error("KonadoStoryLocalization: failed to load localized script %s" % resolved_path)
		return null
	var result := KonadoLocaleOverlay.build(base_shot.program, localized_shot.program, locale)
	if not bool(result.get("ok", false)):
		for error: String in result.get("errors", []):
			push_error("KonadoStoryLocalization: %s: %s" % [resolved_path, error])
		return null
	if not runtime_shot.install_locale_overlay(result["overlay"]):
		push_error(
			"KonadoStoryLocalization: localized overlay does not match %s" % base_shot.source_path
		)
		return null
	return runtime_shot


func _load_shot(path: String) -> KonadoShot:
	var shot: KonadoShot
	if ResourceLoader.exists(path):
		shot = ResourceLoader.load(path) as KonadoShot
	if shot == null and FileAccess.file_exists(path):
		shot = KonadoScriptCompiler.new().compile_file(path)
	return shot


func get_base_script_path(script_path: String) -> String:
	var extension := script_path.get_extension()
	if extension.is_empty():
		return script_path
	var without_extension := script_path.trim_suffix("." + extension)
	var suffix := without_extension.get_file().get_extension()
	if not _looks_like_locale_suffix(suffix):
		return script_path
	return without_extension.trim_suffix("." + suffix) + "." + extension


func get_script_locale(script_path: String) -> String:
	var base_path := get_base_script_path(script_path)
	if base_path == script_path:
		return ""
	var extension := script_path.get_extension()
	var without_extension := script_path.trim_suffix("." + extension)
	var suffix := without_extension.get_file().get_extension()
	return TranslationServer.standardize_locale(suffix)


func _get_locale_fallbacks(locale: String) -> PackedStringArray:
	var requested := locale.strip_edges()
	if requested.is_empty():
		requested = TranslationServer.get_locale()
	var exact := TranslationServer.standardize_locale(requested)
	var expanded := TranslationServer.standardize_locale(requested, true)
	var fallbacks := PackedStringArray()
	_append_unique(fallbacks, exact)
	_append_unique(fallbacks, expanded)

	# Godot can expand a regional locale such as zh_CN to zh_Hans_CN. Localized
	# scripts commonly use the language + script form (zh_Hans), so include it
	# before falling back to the base language.
	var expanded_parts := expanded.split("_", false)
	if expanded_parts.size() >= 2 and expanded_parts[1].length() == 4:
		_append_unique(fallbacks, "%s_%s" % [expanded_parts[0], expanded_parts[1]])
	var exact_parts := exact.split("_", false)
	if exact_parts.size() >= 2 and exact_parts[1].length() == 4:
		_append_unique(fallbacks, "%s_%s" % [exact_parts[0], exact_parts[1]])
	if not exact_parts.is_empty():
		_append_unique(fallbacks, exact_parts[0])
	return fallbacks


func _looks_like_locale_suffix(suffix: String) -> bool:
	if suffix.is_empty():
		return false
	var parts := suffix.replace("-", "_").split("_", false)
	if parts.size() == 1:
		return parts[0].length() == 2 and _is_ascii_alpha(parts[0])
	if parts.size() > 3 or parts[0].length() not in [2, 3] or not _is_ascii_alpha(parts[0]):
		return false
	for index in range(1, parts.size()):
		var part: String = parts[index]
		if part.length() == 2 and _is_ascii_alpha(part):
			continue
		if part.length() == 4 and _is_ascii_alpha(part):
			continue
		if part.length() == 3 and _is_ascii_numeric(part):
			continue
		return false
	return true


func _is_ascii_alpha(value: String) -> bool:
	for index in range(value.length()):
		var codepoint := value.unicode_at(index)
		if not (
			(codepoint >= "A".unicode_at(0) and codepoint <= "Z".unicode_at(0))
			or (codepoint >= "a".unicode_at(0) and codepoint <= "z".unicode_at(0))
		):
			return false
	return not value.is_empty()


func _is_ascii_numeric(value: String) -> bool:
	for index in range(value.length()):
		var codepoint := value.unicode_at(index)
		if codepoint < "0".unicode_at(0) or codepoint > "9".unicode_at(0):
			return false
	return not value.is_empty()


func _append_localized_candidate(
	candidates: PackedStringArray, stem: String, locale: String, extension: String
) -> void:
	var candidate := "%s.%s" % [stem, locale]
	if not extension.is_empty():
		candidate += "." + extension
	_append_unique(candidates, candidate)


func _append_unique(values: PackedStringArray, value: String) -> void:
	if value not in values:
		values.append(value)


func _resource_exists(path: String) -> bool:
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


func _warn_fallback_once(
	script_path: String, requested_locale: String, resolved_path: String
) -> void:
	var effective_locale := (
		requested_locale
		if not requested_locale.strip_edges().is_empty()
		else TranslationServer.get_locale()
	)
	var normalized := TranslationServer.standardize_locale(effective_locale)
	var warning_key := "%s|%s|%s" % [script_path, normalized, resolved_path]
	if _warned_fallbacks.has(warning_key):
		return
	_warned_fallbacks[warning_key] = true
	push_warning(
		(
			"KonadoStoryLocalization: %s is unavailable for %s; using %s"
			% [script_path, normalized, resolved_path]
		)
	)
