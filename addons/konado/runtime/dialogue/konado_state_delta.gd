extends RefCounted
class_name KonadoStateDelta

## Recursive copy-on-write state delta used by VM history.
##
## Runtime state is split into independent domains, while variable stores and
## other dictionaries can be large. Recursing through dictionaries prevents a
## single variable change from duplicating the whole store. Arrays and packed
## arrays remain atomic values because their element identity is domain-specific.

const MAX_NESTING_DEPTH := 8
const ENTRY_VALUE := &"value"
const ENTRY_PATCH := &"patch"


static func between(before: Dictionary, after: Dictionary) -> Dictionary:
	var reverse := {}
	var forward := {}
	_diff_dictionary(before, after, reverse, forward, 0)
	return {"reverse": reverse, "forward": forward}


static func for_patch(state: Dictionary, patch: Dictionary) -> Dictionary:
	var reverse := {}
	var forward := {}
	_diff_patch(state, patch, reverse, forward)
	return {"reverse": reverse, "forward": forward}


static func apply(state: Dictionary, patch: Dictionary) -> Dictionary:
	return _apply_dictionary(state, patch)


static func merge(state: Dictionary, changed_domains: Dictionary) -> Dictionary:
	var result := state.duplicate(false)
	for key: Variant in changed_domains:
		result[key] = _copy(changed_domains[key])
	return result


static func replacement_patch(values: Dictionary) -> Dictionary:
	var result := {}
	for key: Variant in values:
		result[key] = _value_entry(true, values[key])
	return result


static func path_patch(path: Array, exists: bool, value: Variant) -> Dictionary:
	if path.is_empty():
		return {}
	var entry := _value_entry(exists, value)
	for index in range(path.size() - 1, 0, -1):
		entry = {"mode": ENTRY_PATCH, "changes": {path[index]: entry}}
	return {path[0]: entry}


static func combine_patches(patches: Array[Dictionary]) -> Dictionary:
	var result := {}
	for patch: Dictionary in patches:
		_merge_patch_into(result, patch)
	return result


static func estimate_bytes(value: Variant, depth := 0) -> int:
	if depth > MAX_NESTING_DEPTH:
		return 64
	match typeof(value):
		TYPE_NIL:
			return 4
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT:
			return 8
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			return 24 + String(value).length() * 4
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return 16
		TYPE_RECT2, TYPE_RECT2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_COLOR:
			return 32
		TYPE_TRANSFORM2D, TYPE_PLANE, TYPE_QUATERNION, TYPE_AABB, TYPE_BASIS:
			return 64
		TYPE_TRANSFORM3D, TYPE_PROJECTION:
			return 128
		TYPE_DICTIONARY:
			var total := 64
			for key: Variant in value:
				total += estimate_bytes(key, depth + 1)
				total += estimate_bytes(value[key], depth + 1)
			return total
		TYPE_ARRAY:
			var total := 32
			for item: Variant in value:
				total += estimate_bytes(item, depth + 1)
			return total
		TYPE_PACKED_BYTE_ARRAY:
			return 24 + value.size()
		TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			return 24 + value.size() * 4
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			return 24 + value.size() * 8
		TYPE_PACKED_VECTOR2_ARRAY:
			return 24 + value.size() * 8
		TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			return 24 + value.size() * 16
		TYPE_PACKED_STRING_ARRAY:
			var total := 24
			for item: String in value:
				total += 24 + item.length() * 4
			return total
		_:
			return 64


static func _diff_dictionary(
	before: Dictionary,
	after: Dictionary,
	reverse: Dictionary,
	forward: Dictionary,
	depth: int,
) -> void:
	var keys := {}
	for key: Variant in before:
		keys[key] = true
	for key: Variant in after:
		keys[key] = true
	for key: Variant in keys:
		var before_exists := before.has(key)
		var after_exists := after.has(key)
		if before_exists and after_exists and before[key] == after[key]:
			continue
		if (
			before_exists
			and after_exists
			and before[key] is Dictionary
			and after[key] is Dictionary
			and depth < MAX_NESTING_DEPTH
		):
			var nested_reverse := {}
			var nested_forward := {}
			_diff_dictionary(before[key], after[key], nested_reverse, nested_forward, depth + 1)
			if not nested_reverse.is_empty():
				reverse[key] = {"mode": ENTRY_PATCH, "changes": nested_reverse}
				forward[key] = {"mode": ENTRY_PATCH, "changes": nested_forward}
			continue
		reverse[key] = _value_entry(before_exists, before.get(key))
		forward[key] = _value_entry(after_exists, after.get(key))


static func _diff_patch(
	state: Dictionary,
	patch: Dictionary,
	reverse: Dictionary,
	forward: Dictionary,
) -> void:
	for key: Variant in patch:
		var incoming: Dictionary = patch[key]
		if incoming.get("mode") == ENTRY_PATCH:
			var before_exists := state.has(key)
			var before_value: Variant = state.get(key)
			if not before_exists or not before_value is Dictionary:
				var replacement := _apply_dictionary({}, incoming.get("changes", {}))
				if before_exists and before_value == replacement:
					continue
				reverse[key] = _value_entry(before_exists, before_value)
				forward[key] = _value_entry(true, replacement)
				continue
			var current: Dictionary = before_value
			var nested_reverse := {}
			var nested_forward := {}
			_diff_patch(
				current,
				incoming.get("changes", {}),
				nested_reverse,
				nested_forward,
			)
			if not nested_forward.is_empty():
				reverse[key] = {"mode": ENTRY_PATCH, "changes": nested_reverse}
				forward[key] = {"mode": ENTRY_PATCH, "changes": nested_forward}
			continue
		var before_exists := state.has(key)
		var after_exists := bool(incoming.get("exists", false))
		var before_value: Variant = state.get(key)
		var after_value: Variant = incoming.get("value")
		if before_exists == after_exists and (not before_exists or before_value == after_value):
			continue
		reverse[key] = _value_entry(before_exists, before_value)
		forward[key] = _value_entry(after_exists, after_value)


static func _apply_dictionary(state: Dictionary, patch: Dictionary) -> Dictionary:
	var result := state.duplicate(false)
	for key: Variant in patch:
		var entry: Dictionary = patch[key]
		if entry.get("mode") == ENTRY_PATCH:
			var current: Dictionary = (
				result.get(key, {}) if result.get(key, {}) is Dictionary else {}
			)
			result[key] = _apply_dictionary(current, entry.get("changes", {}))
		elif bool(entry.get("exists", false)):
			result[key] = _copy(entry.get("value"))
		else:
			result.erase(key)
	return result


static func _value_entry(exists: bool, value: Variant) -> Dictionary:
	return {
		"mode": ENTRY_VALUE,
		"exists": exists,
		"value": _copy(value) if exists else null,
	}


static func _merge_patch_into(target: Dictionary, source: Dictionary) -> void:
	for key: Variant in source:
		var incoming: Dictionary = source[key]
		if (
			target.has(key)
			and target[key].get("mode") == ENTRY_PATCH
			and incoming.get("mode") == ENTRY_PATCH
		):
			_merge_patch_into(target[key]["changes"], incoming.get("changes", {}))
		else:
			target[key] = incoming.duplicate(true)


static func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Array or value is Dictionary else value
