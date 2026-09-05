@tool
extends RefCounted
class_name KonadoScriptCodeEditTransaction

## Applies a whole-document edit as one undo operation while preserving the
## native editor's carets, selections, folds and viewport.


static func replace_text(code_edit: CodeEdit, updated_source: String) -> void:
	if not is_instance_valid(code_edit) or code_edit.text == updated_source:
		return
	var state := capture_state(code_edit)
	code_edit.begin_complex_operation()
	code_edit.deselect()
	code_edit.remove_secondary_carets()
	code_edit.select_all()
	code_edit.insert_text_at_caret(updated_source)
	code_edit.end_complex_operation()
	restore_state(code_edit, state)


static func capture_state(code_edit: CodeEdit) -> Dictionary:
	var carets: Array[Dictionary] = []
	for caret_index: int in code_edit.get_caret_count():
		var caret := {
			"line": code_edit.get_caret_line(caret_index),
			"column": code_edit.get_caret_column(caret_index),
			"has_selection": code_edit.has_selection(caret_index),
		}
		if caret["has_selection"]:
			caret["origin_line"] = code_edit.get_selection_origin_line(caret_index)
			caret["origin_column"] = code_edit.get_selection_origin_column(caret_index)
		carets.append(caret)
	var folded_lines := PackedInt32Array()
	if code_edit.has_method("get_folded_lines"):
		folded_lines = code_edit.get_folded_lines()
	return {
		"carets": carets,
		"folded_lines": folded_lines,
		"h_scroll": code_edit.get_h_scroll_bar().value,
		"v_scroll": code_edit.get_v_scroll_bar().value,
	}


static func restore_state(code_edit: CodeEdit, state: Dictionary) -> void:
	if not is_instance_valid(code_edit):
		return
	code_edit.deselect()
	code_edit.remove_secondary_carets()
	var carets: Array = state.get("carets", [])
	if carets.is_empty():
		carets = [{"line": 0, "column": 0, "has_selection": false}]
	for caret_index: int in carets.size():
		var caret: Dictionary = carets[caret_index]
		var position := _clamp_position(
			code_edit,
			int(caret.get("line", 0)),
			int(caret.get("column", 0)),
		)
		if caret_index == 0:
			code_edit.set_caret_line(position.x)
			code_edit.set_caret_column(position.y)
		elif code_edit.add_caret(position.x, position.y) < 0:
			continue
		if not bool(caret.get("has_selection", false)):
			continue
		var origin_position := _clamp_position(
			code_edit,
			int(caret.get("origin_line", position.x)),
			int(caret.get("origin_column", position.y)),
		)
		(
			code_edit
			. select(
				origin_position.x,
				origin_position.y,
				position.x,
				position.y,
				caret_index,
			)
		)
	for folded_line: int in state.get("folded_lines", PackedInt32Array()):
		if (
			folded_line >= 0
			and folded_line < code_edit.get_line_count()
			and code_edit.can_fold_line(folded_line)
		):
			code_edit.fold_line(folded_line)
	var horizontal := float(state.get("h_scroll", 0.0))
	var vertical := float(state.get("v_scroll", 0.0))
	_restore_scroll(code_edit, horizontal, vertical)
	code_edit.get_h_scroll_bar().set_deferred("value", horizontal)
	code_edit.get_v_scroll_bar().set_deferred("value", vertical)


static func _clamp_position(code_edit: CodeEdit, line: int, column: int) -> Vector2i:
	var clamped_line := clampi(line, 0, maxi(0, code_edit.get_line_count() - 1))
	return Vector2i(
		clamped_line,
		clampi(column, 0, code_edit.get_line(clamped_line).length()),
	)


static func _restore_scroll(code_edit: CodeEdit, horizontal: float, vertical: float) -> void:
	if not is_instance_valid(code_edit):
		return
	code_edit.get_h_scroll_bar().value = horizontal
	code_edit.get_v_scroll_bar().value = vertical
