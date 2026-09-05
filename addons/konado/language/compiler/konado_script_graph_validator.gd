extends RefCounted
class_name KonadoScriptGraphValidator

## Validates the compact executable Program before it can reach runtime.
##
## A compiled KonadoScript must never defer structural errors to the runtime.
## Every non-empty edge is checked here before KonadoShot is returned.

const MAX_NODES := 250_000
const MAX_CHOICES_PER_INSTRUCTION := 256
const MAX_DIAGNOSTICS := 256

var _errors: Array[String] = []
var _warnings: Array[String] = []


func validate_program(program: KonadoProgram) -> bool:
	_errors.clear()
	_warnings.clear()
	if program == null:
		_errors.append("编译器没有生成 Program IR")
		return false
	if program.instruction_count() > MAX_NODES:
		_errors.append("运行时指令超过 250000 条安全上限")
		return false
	if not program.is_valid():
		_errors.append("Program IR 的数组长度、入口或 ABI 无效")
		return false
	for pc in range(program.instruction_count()):
		if _errors.size() >= MAX_DIAGNOSTICS:
			break
		var opcode := program.opcode_at(pc)
		if opcode == KonadoOpcode.Type.CONDITION:
			_validate_required_pc(program, program.true_pcs[pc], pc, "true")
			_validate_required_pc(program, program.false_pcs[pc], pc, "false")
		elif opcode == KonadoOpcode.Type.CHOICE:
			var choices: Array = program.operand_at(pc, 0, [])
			if choices.is_empty() or choices.size() % 2 != 0:
				_errors.append(_program_at(program, pc, "选项指令没有有效选项"))
			elif choices.size() / 2 > MAX_CHOICES_PER_INSTRUCTION:
				_errors.append(_program_at(program, pc, "单组选项超过 256 个安全上限"))
			for index in range(1, choices.size(), 2):
				var target_pc := program.pc_for_key(String(choices[index]))
				_validate_required_pc(program, target_pc, pc, "选项目标")
		elif opcode == KonadoOpcode.Type.JUMP_BRANCH:
			_validate_required_pc(program, program.next_pcs[pc], pc, "jump_branch")
		elif not KonadoOpcode.is_terminal(opcode):
			_validate_required_pc(program, program.next_pcs[pc], pc, "next")
	if _errors.is_empty():
		_validate_reachability_and_exit(program)
	return _errors.is_empty()


func _validate_reachability_and_exit(program: KonadoProgram) -> void:
	var forward: Array[PackedInt32Array] = []
	var reverse: Array[PackedInt32Array] = []
	forward.resize(program.instruction_count())
	reverse.resize(program.instruction_count())
	for pc in range(program.instruction_count()):
		forward[pc] = _targets(program, pc)
		reverse[pc] = PackedInt32Array()
	for pc in range(forward.size()):
		for target: int in forward[pc]:
			reverse[target].append(pc)
	var reachable := _walk_graph(forward, PackedInt32Array([program.entry_pc]))
	_warn_unreachable_regions(program, forward, reverse, reachable)
	var terminals := PackedInt32Array()
	for pc in range(program.instruction_count()):
		if KonadoOpcode.is_terminal(program.opcode_at(pc)):
			terminals.append(pc)
	var reaches_terminal := _walk_graph(reverse, terminals)
	for pc in reachable:
		if _errors.size() >= MAX_DIAGNOSTICS:
			return
		if not reaches_terminal.has(pc):
			_errors.append(_program_at(program, pc, "所在控制流区域无法到达终止指令"))


func _warn_unreachable_regions(
	program: KonadoProgram,
	forward: Array[PackedInt32Array],
	reverse: Array[PackedInt32Array],
	reachable: Dictionary,
) -> void:
	# One diagnostic per disconnected region is actionable; one per instruction
	# turns a single orphan branch into hundreds of duplicate warnings.
	var visited := {}
	for start_pc in range(program.instruction_count()):
		if reachable.has(start_pc) or visited.has(start_pc):
			continue
		var representative := start_pc
		var stack := [start_pc]
		visited[start_pc] = true
		while not stack.is_empty():
			var pc := int(stack.pop_back())
			representative = mini(representative, pc)
			for neighbour: int in Array(forward[pc]) + Array(reverse[pc]):
				if reachable.has(neighbour) or visited.has(neighbour):
					continue
				visited[neighbour] = true
				stack.append(neighbour)
		_warnings.append(_program_at(program, representative, "控制流区域不可从程序入口到达"))


func _targets(program: KonadoProgram, pc: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	for target: int in [program.next_pcs[pc], program.true_pcs[pc], program.false_pcs[pc]]:
		if target != KonadoProgram.INVALID_PC and not result.has(target):
			result.append(target)
	if program.opcode_at(pc) == KonadoOpcode.Type.CHOICE:
		var choices: Array = program.operand_at(pc, 0, [])
		for index in range(1, choices.size(), 2):
			var target := program.pc_for_key(String(choices[index]))
			if target != KonadoProgram.INVALID_PC and not result.has(target):
				result.append(target)
	return result


func _walk_graph(edges: Array[PackedInt32Array], starts: PackedInt32Array) -> Dictionary:
	var visited := {}
	var stack := Array(starts)
	while not stack.is_empty():
		var pc := int(stack.pop_back())
		if pc < 0 or pc >= edges.size() or visited.has(pc):
			continue
		visited[pc] = true
		for target: int in edges[pc]:
			if not visited.has(target):
				stack.append(target)
	return visited


func _validate_pc(
	program: KonadoProgram, target_pc: int, source_pc: int, edge_name: String
) -> void:
	if _errors.size() >= MAX_DIAGNOSTICS:
		return
	if target_pc == KonadoProgram.INVALID_PC:
		return
	if target_pc < 0 or target_pc >= program.instruction_count():
		_errors.append(_program_at(program, source_pc, "%s 指向无效 PC %d" % [edge_name, target_pc]))


func _validate_required_pc(
	program: KonadoProgram, target_pc: int, source_pc: int, edge_name: String
) -> void:
	if _errors.size() >= MAX_DIAGNOSTICS:
		return
	if target_pc == KonadoProgram.INVALID_PC:
		_errors.append(_program_at(program, source_pc, "%s 缺少可执行目标" % edge_name))
		return
	_validate_pc(program, target_pc, source_pc, edge_name)


func _program_at(program: KonadoProgram, pc: int, message: String) -> String:
	return "第 %d 行：%s" % [maxi(1, program.line_for_pc(pc)), message]


func get_errors() -> Array[String]:
	return _errors.duplicate()


func get_warnings() -> Array[String]:
	return _warnings.duplicate()
