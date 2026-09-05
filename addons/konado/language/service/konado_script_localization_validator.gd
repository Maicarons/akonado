@tool
extends RefCounted
class_name KonadoScriptLocalizationValidator

## Validates structural parity between a default script and one localized variant.

const MAX_ALIGNMENT_CELLS := 1_000_000


static func compare(
	default_source: String,
	localized_source: String,
	default_path: String = "",
	localized_path: String = "",
	locale: String = "",
) -> Dictionary:
	var default_entries := _collect_entries(default_source)
	var localized_entries := _collect_entries(localized_source)
	var rows: Array[Dictionary] = []
	var diagnostics: Array[Dictionary] = []
	var aligned_entries := _align_entries(default_entries, localized_entries)
	for index: int in aligned_entries.size():
		var pair: Dictionary = aligned_entries[index]
		var base: Dictionary = pair["default"]
		var translated: Dictionary = pair["localized"]
		var status := "matched"
		if base.is_empty():
			status = "extra"
		elif translated.is_empty():
			status = "missing"
		elif base.get("signature") != translated.get("signature"):
			status = "structure_changed"
		elif (
			not String(base.get("presentation_signature", "")).is_empty()
			and base.get("presentation_signature") != translated.get("presentation_signature")
		):
			status = "presentation_changed"
		(
			rows
			. append(
				{
					"index": index,
					"status": status,
					"default": base,
					"localized": translated,
				}
			)
		)
		if status in ["missing", "extra", "structure_changed", "presentation_changed"]:
			var line := int(translated.get("line", base.get("line", 1)))
			var line_source := localized_source if not translated.is_empty() else default_source
			(
				diagnostics
				. append(
					{
						"severity": "warning" if status == "presentation_changed" else "error",
						"line": line,
						"column": 1,
						"end_line": line,
						"end_column": _line_end_column(line_source, line),
						"path": localized_path,
						"code": "locale_%s" % status,
						"arguments": [line],
						"actions": [],
						"message": _status_message(status, line, locale),
					}
				)
			)
	return {
		"default_path": default_path,
		"localized_path": localized_path,
		"rows": rows,
		"diagnostics": diagnostics,
		"compatible":
		diagnostics.all(func(item: Dictionary) -> bool: return item["severity"] != "error"),
	}


static func _line_end_column(source: String, line_number: int) -> int:
	var lines := source.split("\n")
	var index := line_number - 1
	if index < 0 or index >= lines.size():
		return 2
	return maxi(2, String(lines[index]).length() + 1)


static func _align_entries(
	default_entries: Array[Dictionary],
	localized_entries: Array[Dictionary],
) -> Array[Dictionary]:
	var default_count := default_entries.size()
	var localized_count := localized_entries.size()
	if (default_count + 1) * (localized_count + 1) > MAX_ALIGNMENT_CELLS:
		return _align_entries_by_position(default_entries, localized_entries)
	var lengths: Array[PackedInt32Array] = []
	for _row: int in default_count + 1:
		lengths.append(PackedInt32Array())
		lengths[-1].resize(localized_count + 1)
	for default_index: int in range(default_count - 1, -1, -1):
		for localized_index: int in range(localized_count - 1, -1, -1):
			if (
				default_entries[default_index].get("signature")
				== localized_entries[localized_index].get("signature")
			):
				lengths[default_index][localized_index] = (
					lengths[default_index + 1][localized_index + 1] + 1
				)
			else:
				lengths[default_index][localized_index] = maxi(
					lengths[default_index + 1][localized_index],
					lengths[default_index][localized_index + 1],
				)
	var aligned: Array[Dictionary] = []
	var default_index := 0
	var localized_index := 0
	while default_index < default_count and localized_index < localized_count:
		var base: Dictionary = default_entries[default_index]
		var translated: Dictionary = localized_entries[localized_index]
		if base.get("signature") == translated.get("signature"):
			aligned.append({"default": base, "localized": translated})
			default_index += 1
			localized_index += 1
		elif (
			lengths[default_index + 1][localized_index]
			>= lengths[default_index][localized_index + 1]
		):
			aligned.append({"default": base, "localized": {}})
			default_index += 1
		else:
			aligned.append({"default": {}, "localized": translated})
			localized_index += 1
	while default_index < default_count:
		aligned.append({"default": default_entries[default_index], "localized": {}})
		default_index += 1
	while localized_index < localized_count:
		aligned.append({"default": {}, "localized": localized_entries[localized_index]})
		localized_index += 1
	return aligned


static func _align_entries_by_position(
	default_entries: Array[Dictionary],
	localized_entries: Array[Dictionary],
) -> Array[Dictionary]:
	var aligned: Array[Dictionary] = []
	for index: int in maxi(default_entries.size(), localized_entries.size()):
		(
			aligned
			. append(
				{
					"default": default_entries[index] if index < default_entries.size() else {},
					"localized":
					localized_entries[index] if index < localized_entries.size() else {},
				}
			)
		)
	return aligned


static func _collect_entries(source: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var inside_screen_text := false
	var lines := source.split("\n")
	for line_index: int in lines.size():
		var line := String(lines[line_index])
		var tokens := KonadoScriptSymbolIndex.get_line_tokens(line)
		if tokens.is_empty():
			continue
		if inside_screen_text and tokens[0].get("text") == "}":
			inside_screen_text = false
			var stable_id := _named_parameter_value(tokens, "id")
			if not stable_id.is_empty() and not entries.is_empty():
				entries[-1]["signature"] += "|id=%s" % stable_id
			continue
		if inside_screen_text and bool(tokens[0].get("quoted", false)):
			continue
		var command := String(tokens[0]["text"])
		if command == "screentext":
			inside_screen_text = true
			entries.append(_entry(line_index + 1, "screentext {"))
		elif _is_dialogue_tokens(tokens):
			var speaker_signature := _dialogue_speaker_signature(tokens[0])
			var presentation_signature := ""
			if speaker_signature.begins_with("actor:"):
				presentation_signature = speaker_signature
				speaker_signature = "actor"
			var stable_id := _named_parameter_value(tokens, "id")
			if not stable_id.is_empty():
				speaker_signature += "|id=%s" % stable_id
			(
				entries
				. append(
					_entry(
						line_index + 1,
						"dialogue_content|%s" % speaker_signature,
						presentation_signature,
					)
				)
			)
		elif command == "choice":
			var target := ""
			for token_index: int in tokens.size():
				if String(tokens[token_index]["text"]) == "->" and token_index + 1 < tokens.size():
					target = String(tokens[token_index + 1]["text"])
					break
			var stable_id := _named_parameter_value(tokens, "id")
			if not stable_id.is_empty():
				target += "|id=%s" % stable_id
			entries.append(_entry(line_index + 1, "choice|%s" % target))
		elif _is_presentation_command(tokens):
			(
				entries
				. append(
					_entry(
						line_index + 1,
						_presentation_structure_signature(tokens),
						_token_signature(tokens),
					)
				)
			)
		else:
			entries.append(_entry(line_index + 1, _token_signature(tokens)))
	return entries


static func _is_presentation_command(tokens: Array[Dictionary]) -> bool:
	var command := String(tokens[0].get("text", ""))
	return (
		command in ["actor", "background", "play", "cam", "asyncam", "showtextbox", "hidetextbox"]
	)


static func _presentation_structure_signature(tokens: Array[Dictionary]) -> String:
	var parts := PackedStringArray([String(tokens[0].get("text", ""))])
	if parts[0] in ["actor", "play", "cam", "asyncam"] and tokens.size() > 1:
		parts.append(String(tokens[1].get("text", "")))
	var stable_id := _named_parameter_value(tokens, "id")
	if not stable_id.is_empty():
		parts.append("id=%s" % stable_id)
	return "|".join(parts)


static func _named_parameter_value(tokens: Array[Dictionary], parameter: String) -> String:
	for index: int in range(tokens.size() - 3):
		if (
			String(tokens[index].get("text", "")) == "["
			and String(tokens[index + 1].get("text", "")) == parameter
			and String(tokens[index + 2].get("text", "")) == "="
		):
			return String(tokens[index + 3].get("text", ""))
	return ""


static func _token_signature(tokens: Array[Dictionary]) -> String:
	var values := PackedStringArray()
	for token: Dictionary in tokens:
		values.append(String(token["text"]))
	return " ".join(values)


static func _is_dialogue_tokens(tokens: Array[Dictionary]) -> bool:
	if tokens.size() < 2 or not bool(tokens[1].get("quoted", false)):
		return false
	if bool(tokens[0].get("quoted", false)):
		return true
	var first := String(tokens[0].get("text", ""))
	return (
		first.begins_with("%")
		or first.begins_with("$")
		or not KonadoScriptLanguageCatalog.ROOT_KEYWORDS.has(first)
	)


static func _dialogue_speaker_signature(token: Dictionary) -> String:
	if bool(token.get("quoted", false)):
		return "text"
	var value := String(token.get("text", ""))
	if value.begins_with("$"):
		return "temporary:%s" % value.substr(1)
	if value.begins_with("%"):
		return "persistent:%s" % value.substr(1)
	return "actor:%s" % value


static func _entry(line: int, signature: String, presentation_signature: String = "") -> Dictionary:
	return {
		"line": line,
		"signature": signature,
		"presentation_signature": presentation_signature,
	}


static func _status_message(status: String, line: int, locale: String) -> String:
	var messages := {
		"missing":
		(
			KonadoScriptEditorLocale
			. text(
				"Localized script is missing the item corresponding to line %d." % line,
				"本地化剧本缺少与第 %d 行对应的内容。" % line,
				locale,
			)
		),
		"extra":
		(
			KonadoScriptEditorLocale
			. text(
				"Localized script contains an extra structural item on line %d." % line,
				"本地化剧本第 %d 行存在额外结构。" % line,
				locale,
			)
		),
		"structure_changed":
		(
			KonadoScriptEditorLocale
			. text(
				"Localized script structure differs on line %d." % line,
				"本地化剧本第 %d 行的结构与默认剧本不同。" % line,
				locale,
			)
		),
		"presentation_changed":
		(
			KonadoScriptEditorLocale
			. text(
				"Localized script uses different presentation parameters on line %d." % line,
				"本地化剧本第 %d 行使用了不同的演出参数。" % line,
				locale,
			)
		),
	}
	return String(messages.get(status, status))
