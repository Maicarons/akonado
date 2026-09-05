extends RefCounted
class_name KonadoValueOperations

## Strict value semantics shared by the compiler-facing VM and variable stores.
## KonadoScript never performs string-to-number or bool-to-number coercion.

const OP_SET := 0
const OP_ADD := 1
const OP_SUB := 2
const OP_MUL := 3
const OP_DIV := 4


static func is_numeric(value: Variant) -> bool:
	return value is int or value is float


static func apply(current: Variant, operation: int, operand: Variant, exists: bool) -> Dictionary:
	if operation == OP_SET:
		return {"ok": _supported(operand), "value": operand}
	if not exists:
		return {"ok": false, "reason": "variable is undefined"}
	if operation == OP_ADD and current is String and operand is String:
		return {"ok": true, "value": current + operand}
	if not is_numeric(current) or not is_numeric(operand):
		return {"ok": false, "reason": "arithmetic operands must be numeric"}
	if operation == OP_DIV and is_zero_approx(float(operand)):
		return {"ok": false, "reason": "division by zero"}
	var value: Variant
	match operation:
		OP_ADD:
			value = current + operand
		OP_SUB:
			value = current - operand
		OP_MUL:
			value = current * operand
		OP_DIV:
			value = float(current) / float(operand)
		_:
			return {"ok": false, "reason": "unknown variable operation"}
	return {"ok": true, "value": value}


static func compare(left: Variant, right: Variant, operator: int) -> Dictionary:
	if operator in [0, 5]:
		var equal: bool = left == right
		return {"ok": true, "value": equal if operator == 0 else not equal}
	var comparable := (
		(is_numeric(left) and is_numeric(right)) or (left is String and right is String)
	)
	if not comparable:
		return {"ok": false, "reason": "ordered comparison requires compatible values"}
	var value := false
	match operator:
		1:
			value = left > right
		2:
			value = left < right
		3:
			value = left >= right
		4:
			value = left <= right
		_:
			return {"ok": false, "reason": "unknown comparison operator"}
	return {"ok": true, "value": value}


static func _supported(value: Variant) -> bool:
	return value == null or value is bool or value is int or value is float or value is String
