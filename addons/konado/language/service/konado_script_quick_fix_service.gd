@tool
extends RefCounted
class_name KonadoScriptQuickFixService

## Produces deterministic, previewable text edits for common authoring errors.

const MAX_CANDIDATES_PER_DIAGNOSTIC := 3

const FIX_DIAGNOSTIC_CODES := {
	"append_if_colon": ["syntax.if_missing_colon"],
	"append_else_colon": ["syntax.else_missing_colon"],
	"remove_unmatched_endif": ["syntax.unexpected_endif"],
	"normalize_endif": ["syntax.unrecognized_endif"],
	"remove_unmatched_screen_close": ["syntax.unrecognized"],
	"append_endif": ["syntax.if_missing_endif"],
	"append_screen_close": ["syntax.screentext_missing_close"],
	"insert_choice_arrow": ["syntax.choice_missing_arrow"],
	"normalize_if_comparison": ["syntax.comparison_operator"],
	"set_flag_true": ["syntax.boolean_value"],
	"set_flag_false": ["syntax.boolean_value"],
	"set_actor_position": ["syntax.actor_position"],
	"create_branch": ["missing_branch", "semantic.missing_branch"],
	"replace_root_keyword": ["syntax.unrecognized"],
	"replace_context_keyword":
	[
		"syntax.actor_action",
		"syntax.audio_type",
		"syntax.camera_action",
		"syntax.achievement_action",
	],
}


static func get_fixes(document: KonadoScriptDocument, locale: String = "") -> Array[Dictionary]:
	var fixes: Array[Dictionary] = []
	var lines := document.source.split("\n")
	var if_stack := PackedInt32Array()
	var screen_stack := PackedInt32Array()
	for line_index: int in lines.size():
		var line := String(lines[line_index])
		var parts := _split_code_comment(line)
		var code := String(parts["code"])
		var comment := String(parts["comment"])
		var content := code.strip_edges()
		var tokens := KonadoScriptSymbolIndex.get_line_tokens(code)
		fixes.append_array(_get_keyword_fixes(tokens, line_index, line, code, comment, locale))
		if content.begins_with("if ") and content.ends_with(":"):
			if_stack.append(line_index)
		elif content.begins_with("if ") and not content.ends_with(":"):
			(
				fixes
				. append(
					_make_line_fix(
						"append_if_colon",
						KonadoScriptEditorLocale.text("Add missing ':'", "补充缺失的“:”", locale),
						line_index,
						line,
						code.rstrip(" \t") + ":" + _comment_suffix(comment),
					)
				)
			)
			if_stack.append(line_index)
		elif content == "else":
			(
				fixes
				. append(
					_make_line_fix(
						"append_else_colon",
						KonadoScriptEditorLocale.text("Replace with 'else:'", "替换为“else:”", locale),
						line_index,
						line,
						code.rstrip(" \t") + ":" + _comment_suffix(comment),
					)
				)
			)
		elif content == "endif" and not if_stack.is_empty():
			if_stack.remove_at(if_stack.size() - 1)
		elif content == "endif" and if_stack.is_empty():
			(
				fixes
				. append(
					_make_line_fix(
						"remove_unmatched_endif",
						(
							KonadoScriptEditorLocale
							. text(
								"Remove unmatched 'endif'",
								"移除不匹配的“endif”",
								locale,
							)
						),
						line_index,
						line,
						"",
					)
				)
			)
		elif content.begins_with("endif") and content != "endif":
			if not if_stack.is_empty():
				if_stack.remove_at(if_stack.size() - 1)
			(
				fixes
				. append(
					_make_line_fix(
						"normalize_endif",
						KonadoScriptEditorLocale.text("Replace with 'endif'", "替换为“endif”", locale),
						line_index,
						line,
						(
							code.left(code.length() - code.strip_edges(true, false).length())
							+ "endif"
							+ _comment_suffix(comment)
						),
					)
				)
			)
		if content.begins_with("if ") and " = " in content:
			(
				fixes
				. append(
					_make_line_fix(
						"normalize_if_comparison",
						(
							KonadoScriptEditorLocale
							. text(
								"Replace '=' with '=='",
								"将“=”替换为“==”",
								locale,
							)
						),
						line_index,
						line,
						code.replace(" = ", " == ") + _comment_suffix(comment),
					)
				)
			)
		if content.begins_with("screentext") and content.ends_with("{"):
			screen_stack.append(line_index)
		elif content == "}" and not screen_stack.is_empty():
			screen_stack.remove_at(screen_stack.size() - 1)
		elif content == "}":
			(
				fixes
				. append(
					_make_line_fix(
						"remove_unmatched_screen_close",
						(
							KonadoScriptEditorLocale
							. text(
								"Remove unmatched screen-text brace",
								"移除不匹配的全屏文本结束括号",
								locale,
							)
						),
						line_index,
						line,
						"",
					)
				)
			)
		if (
			tokens.size() == 3
			and tokens[0].get("text") == "choice"
			and bool(tokens[1].get("quoted", false))
			and not tokens.any(func(token: Dictionary) -> bool: return token.get("text") == "->")
		):
			var target_start := int(tokens[2].get("start", code.length()))
			(
				fixes
				. append(
					_make_line_fix(
						"insert_choice_arrow",
						(
							KonadoScriptEditorLocale
							. text(
								"Insert missing '->'",
								"补充缺失的“->”",
								locale,
							)
						),
						line_index,
						line,
						(
							code.left(target_start)
							+ "-> "
							+ code.substr(target_start)
							+ _comment_suffix(comment)
						),
					)
				)
			)
		if (
			tokens.size() == 4
			and tokens[0].get("text") == "achievement"
			and tokens[1].get("text") == "set_flag"
			and tokens[3].get("text") not in ["true", "false"]
		):
			var value_start := int(tokens[3].get("start", code.length()))
			var value_end := int(tokens[3].get("end", value_start))
			for value: String in ["true", "false"]:
				(
					fixes
					. append(
						_make_line_fix(
							"set_flag_%s" % value,
							(
								KonadoScriptEditorLocale
								. text(
									"Replace with '%s'" % value,
									"替换为“%s”" % value,
									locale,
								)
							),
							line_index,
							line,
							(
								code.left(value_start)
								+ value
								+ code.substr(value_end)
								+ _comment_suffix(comment)
							),
							false,
						)
					)
				)
		if (
			tokens.size() == 4
			and tokens[0].get("text") == "actor"
			and tokens[1].get("text") == "show"
		):
			for position_index: int in KonadoScriptLanguageCatalog.LIKELY_POSITION_VALUES.size():
				var position := KonadoScriptLanguageCatalog.LIKELY_POSITION_VALUES[position_index]
				(
					fixes
					. append(
						_make_line_fix(
							"set_actor_position",
							(
								KonadoScriptEditorLocale
								. text(
									"Use position %s" % position,
									"使用位置 %s" % position,
									locale,
								)
							),
							line_index,
							line,
							code.rstrip(" \t") + " at " + position + _comment_suffix(comment),
							false,
							1.0 - position_index * 0.1,
						)
					)
				)

	if not if_stack.is_empty():
		var closing_lines := PackedStringArray()
		for stack_index: int in range(if_stack.size() - 1, -1, -1):
			var opening_line := String(lines[if_stack[stack_index]])
			var indentation := opening_line.left(
				opening_line.length() - opening_line.strip_edges(true, false).length()
			)
			closing_lines.append(indentation + "endif")
		(
			fixes
			. append(
				_make_append_fix(
					"append_endif",
					(
						KonadoScriptEditorLocale
						. text(
							"Add %d missing 'endif'" % if_stack.size(),
							"补充 %d 个缺失的“endif”" % if_stack.size(),
							locale,
						)
					),
					document.source,
					"\n".join(closing_lines),
					if_stack[0] + 1,
				)
			)
		)
	if not screen_stack.is_empty():
		var closing_lines := PackedStringArray()
		for stack_index: int in range(screen_stack.size() - 1, -1, -1):
			var opening_line := String(lines[screen_stack[stack_index]])
			var indentation := opening_line.left(
				opening_line.length() - opening_line.strip_edges(true, false).length()
			)
			closing_lines.append(indentation + "}")
		(
			fixes
			. append(
				_make_append_fix(
					"append_screen_close",
					(
						KonadoScriptEditorLocale
						. text(
							"Close %d screen-text blocks" % screen_stack.size(),
							"补充 %d 个全屏文本结束括号" % screen_stack.size(),
							locale,
						)
					),
					document.source,
					"\n".join(closing_lines),
					screen_stack[0] + 1,
				)
			)
		)
	for diagnostic: Dictionary in KonadoScriptControlFlowAnalyzer.analyze(document, locale):
		if diagnostic.get("code") != "missing_branch":
			continue
		var missing_name := String(diagnostic.get("symbol", ""))
		if missing_name.is_empty():
			missing_name = _extract_quoted_name(String(diagnostic["message"]))
		if missing_name.is_empty():
			continue
		(
			fixes
			. append(
				_make_append_fix(
					"create_branch",
					(
						KonadoScriptEditorLocale
						. text(
							"Create branch '%s'" % missing_name,
							"创建分支“%s”" % missing_name,
							locale,
						)
					),
					document.source,
					"branch %s\n\tend" % missing_name,
					int(diagnostic.get("line", 1)),
				)
			)
		)
	return _deduplicate(fixes)


static func apply_fix(source: String, fix: Dictionary) -> String:
	var start := clampi(int(fix.get("start", source.length())), 0, source.length())
	var end := clampi(int(fix.get("end", start)), start, source.length())
	return source.left(start) + String(fix.get("replacement", "")) + source.substr(end)


static func matches_diagnostic(fix: Dictionary, diagnostic: Dictionary) -> bool:
	if int(fix.get("line", 1)) != int(diagnostic.get("line", 1)):
		return false
	var diagnostic_codes: Array = fix.get("diagnostic_codes", [])
	return diagnostic_codes.is_empty() or String(diagnostic.get("code", "")) in diagnostic_codes


static func rank_fixes_for_diagnostic(
	fixes: Array[Dictionary],
	diagnostic: Dictionary,
) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = []
	for fix: Dictionary in fixes:
		if matches_diagnostic(fix, diagnostic):
			ranked.append(fix)
	ranked.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			var left_safe := bool(left.get("safe", true))
			var right_safe := bool(right.get("safe", true))
			if left_safe != right_safe:
				return left_safe
			return float(left.get("confidence", 0.5)) > float(right.get("confidence", 0.5))
	)
	if ranked.size() > MAX_CANDIDATES_PER_DIAGNOSTIC:
		ranked.resize(MAX_CANDIDATES_PER_DIAGNOSTIC)
	return ranked


static func apply_all_fixes(source: String, path: String = "") -> String:
	var updated := source
	# Re-analyze after each edit so later offsets and structural fixes always
	# belong to the exact revision being changed.
	for _iteration: int in 256:
		var document := KonadoScriptDocument.new()
		document.update(updated, path)
		var fixes := get_fixes(document).filter(
			func(candidate: Dictionary) -> bool: return bool(candidate.get("safe", true))
		)
		if fixes.is_empty():
			break
		var fix := materialize_line_fix(updated, fixes[0])
		if fix.is_empty():
			break
		var next_source := apply_fix(updated, fix)
		if next_source == updated:
			break
		updated = next_source
	return updated


static func _make_line_fix(
	code: String,
	title: String,
	line_index: int,
	old_line: String,
	replacement: String,
	safe: bool = true,
	confidence: float = 1.0,
) -> Dictionary:
	return {
		"code": code,
		"title": title,
		"line": line_index + 1,
		"old_line": old_line,
		"replacement_line": replacement,
		"line_edit": true,
		"safe": safe,
		"confidence": confidence,
		"diagnostic_codes": FIX_DIAGNOSTIC_CODES.get(code, []),
	}


static func materialize_line_fix(source: String, fix: Dictionary) -> Dictionary:
	if not bool(fix.get("line_edit", false)):
		return fix
	var lines := source.split("\n")
	var line_index := int(fix.get("line", 1)) - 1
	if line_index < 0 or line_index >= lines.size():
		return {}
	var offset := 0
	for index: int in line_index:
		offset += String(lines[index]).length() + 1
	var materialized := fix.duplicate(true)
	materialized["start"] = offset
	materialized["end"] = offset + String(lines[line_index]).length()
	materialized["replacement"] = fix["replacement_line"]
	return materialized


static func _make_append_fix(
	code: String,
	title: String,
	source: String,
	addition: String,
	diagnostic_line: int = -1,
) -> Dictionary:
	return {
		"code": code,
		"title": title,
		"line": diagnostic_line if diagnostic_line > 0 else source.split("\n").size(),
		"start": source.length(),
		"end": source.length(),
		"safe": true,
		"diagnostic_codes": FIX_DIAGNOSTIC_CODES.get(code, []),
		"replacement":
		("" if source.is_empty() or source.ends_with("\n") else "\n") + addition + "\n",
	}


static func _get_keyword_fixes(
	tokens: Array[Dictionary],
	line_index: int,
	line: String,
	code: String,
	comment: String,
	locale: String,
) -> Array[Dictionary]:
	var fixes: Array[Dictionary] = []
	if tokens.is_empty() or bool(tokens[0].get("quoted", false)):
		return fixes
	var root := String(tokens[0].get("text", ""))
	if root not in KonadoScriptLanguageCatalog.ROOT_KEYWORDS:
		for candidate: Dictionary in _rank_keyword_candidates(
			root,
			Array(KonadoScriptLanguageCatalog.ROOT_KEYWORDS),
		):
			(
				fixes
				. append(
					_make_keyword_fix(
						"replace_root_keyword",
						candidate,
						tokens[0],
						line_index,
						line,
						code,
						comment,
						locale,
					)
				)
			)
		return fixes
	if tokens.size() < 2 or not KonadoScriptLanguageCatalog.CONTEXT_COMPLETIONS.has(root):
		return fixes
	if bool(tokens[1].get("quoted", false)):
		return fixes
	var action := String(tokens[1].get("text", ""))
	var valid_actions: Array = KonadoScriptLanguageCatalog.CONTEXT_COMPLETIONS[root]
	if action in valid_actions:
		return fixes
	for candidate: Dictionary in _rank_keyword_candidates(action, valid_actions):
		(
			fixes
			. append(
				_make_keyword_fix(
					"replace_context_keyword",
					candidate,
					tokens[1],
					line_index,
					line,
					code,
					comment,
					locale,
				)
			)
		)
	return fixes


static func _make_keyword_fix(
	fix_code: String,
	candidate: Dictionary,
	token: Dictionary,
	line_index: int,
	line: String,
	code: String,
	comment: String,
	locale: String,
) -> Dictionary:
	var replacement := String(candidate["value"])
	var token_start := int(token.get("start", 0))
	var token_end := int(token.get("end", token_start))
	return _make_line_fix(
		fix_code,
		(
			KonadoScriptEditorLocale
			. text(
				"Replace with '%s'" % replacement,
				"替换为“%s”" % replacement,
				locale,
			)
		),
		line_index,
		line,
		code.left(token_start) + replacement + code.substr(token_end) + _comment_suffix(comment),
		false,
		float(candidate["confidence"]),
	)


static func _rank_keyword_candidates(value: String, candidates: Array) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = []
	var normalized := value.to_lower()
	if normalized.is_empty():
		return ranked
	for candidate_value: Variant in candidates:
		var candidate := String(candidate_value).to_lower()
		var distance := _edit_distance(normalized, candidate)
		var longest := maxi(normalized.length(), candidate.length())
		var confidence := 1.0 - float(distance) / float(maxi(1, longest))
		if normalized.begins_with(candidate) or candidate.begins_with(normalized):
			confidence = maxf(
				confidence, 0.9 - 0.05 * absf(normalized.length() - candidate.length())
			)
		if distance > 2 or confidence < 0.55:
			continue
		ranked.append({"value": candidate_value, "confidence": confidence})
	ranked.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return float(left["confidence"]) > float(right["confidence"])
	)
	if ranked.size() > MAX_CANDIDATES_PER_DIAGNOSTIC:
		ranked.resize(MAX_CANDIDATES_PER_DIAGNOSTIC)
	return ranked


static func _edit_distance(left: String, right: String) -> int:
	var previous := PackedInt32Array()
	previous.resize(right.length() + 1)
	for column: int in previous.size():
		previous[column] = column
	for left_index: int in left.length():
		var current := PackedInt32Array()
		current.resize(right.length() + 1)
		current[0] = left_index + 1
		for right_index: int in right.length():
			var substitution_cost := (
				0 if left.substr(left_index, 1) == right.substr(right_index, 1) else 1
			)
			current[right_index + 1] = mini(
				mini(
					current[right_index] + 1,
					previous[right_index + 1] + 1,
				),
				previous[right_index] + substitution_cost,
			)
		previous = current
	return previous[right.length()]


static func _extract_quoted_name(message: String) -> String:
	for quote_pair: PackedStringArray in [
		PackedStringArray(["'", "'"]),
		PackedStringArray(["“", "”"]),
	]:
		var start := message.find(quote_pair[0])
		var end := message.find(quote_pair[1], start + quote_pair[0].length())
		if start >= 0 and end > start:
			return message.substr(start + quote_pair[0].length(), end - start - 1)
	return ""


static func _split_code_comment(line: String) -> Dictionary:
	var inside_string := false
	var escaped := false
	for column: int in line.length():
		var character := line.substr(column, 1)
		if escaped:
			escaped = false
		elif character == "\\" and inside_string:
			escaped = true
		elif character == '"':
			inside_string = not inside_string
		elif character == "#" and not inside_string:
			return {"code": line.left(column), "comment": line.substr(column)}
	return {"code": line, "comment": ""}


static func _comment_suffix(comment: String) -> String:
	return "" if comment.is_empty() else " " + comment


static func _deduplicate(fixes: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen := {}
	for fix: Dictionary in fixes:
		var key := (
			"%s:%s:%s:%s:%s"
			% [
				fix.get("code"),
				fix.get("start"),
				fix.get("line"),
				fix.get("replacement"),
				fix.get("replacement_line"),
			]
		)
		if seen.has(key):
			continue
		seen[key] = true
		result.append(fix)
	return result
