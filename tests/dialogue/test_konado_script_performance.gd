extends SceneTree

## Deterministic complexity guard for the KonadoScript compiler and Program VM.
## Absolute timings are printed for observability; CI assertions use scaling
## ratios so different GitHub runners are not compared as if they were identical.

const SMALL_LINES := 1000
const LARGE_LINES := 4000
const LOOKUP_ITERATIONS := 4000
const MAX_COMPILE_SCALE := 7.0
const MAX_LOOKUP_SCALE := 3.0
const MAX_VM_SCALE := 7.0
const MAX_LARGE_MEMORY_MIB := 256.0
const MANAGER_TIME_SLICE_STATEMENTS := 4200
const DIALOGUE_MANAGER_SCENE := preload(
	"res://addons/konado/templates/default/dialogue_runtime.tscn"
)

var _failures := 0


func _init() -> void:
	# Warm caches and class initialization outside measured samples.
	_compile(32, false)
	_compile(32, true)
	var small := _compile(SMALL_LINES, false)
	var large := _compile(LARGE_LINES, false)
	var mixed_small := _compile(SMALL_LINES, true)
	var mixed_large := _compile(LARGE_LINES, true)
	var small_lookup_ms := _measure_lookup(small.shot, LOOKUP_ITERATIONS)
	var large_lookup_ms := _measure_lookup(large.shot, LOOKUP_ITERATIONS)
	var small_vm := _measure_vm_transactions(small.shot)
	var large_vm := _measure_vm_transactions(large.shot)
	var manager_runtime := await _measure_manager_execution(MANAGER_TIME_SLICE_STATEMENTS)
	var compile_scale := float(large.elapsed_usec) / maxf(float(small.elapsed_usec), 1.0)
	var mixed_compile_scale := (
		float(mixed_large.elapsed_usec) / maxf(float(mixed_small.elapsed_usec), 1.0)
	)
	var lookup_scale := large_lookup_ms / maxf(small_lookup_ms, 0.001)
	var vm_scale := float(large_vm.elapsed_usec) / maxf(float(small_vm.elapsed_usec), 1.0)
	var small_metrics := small.duplicate()
	var large_metrics := large.duplicate()
	var mixed_small_metrics := mixed_small.duplicate()
	var mixed_large_metrics := mixed_large.duplicate()
	small_metrics.erase("shot")
	large_metrics.erase("shot")
	mixed_small_metrics.erase("shot")
	mixed_large_metrics.erase("shot")
	_expect(
		(
			bool(small.valid)
			and bool(large.valid)
			and bool(mixed_small.valid)
			and bool(mixed_large.valid)
		),
		"pure-dialogue and mixed-language performance fixtures compile",
	)
	_expect(
		compile_scale <= MAX_COMPILE_SCALE,
		(
			"pure-dialogue compiler scaling is near-linear (%.2fx, limit %.2fx)"
			% [compile_scale, MAX_COMPILE_SCALE]
		),
	)
	_expect(
		mixed_compile_scale <= MAX_COMPILE_SCALE,
		(
			"mixed-language compiler scaling is near-linear (%.2fx, limit %.2fx)"
			% [mixed_compile_scale, MAX_COMPILE_SCALE]
		),
	)
	_expect(
		lookup_scale <= MAX_LOOKUP_SCALE,
		(
			"Program lookup remains independent of Program size (%.2fx, limit %.2fx)"
			% [lookup_scale, MAX_LOOKUP_SCALE]
		),
	)
	_expect(
		bool(small_vm.valid) and bool(large_vm.valid) and vm_scale <= MAX_VM_SCALE,
		(
			"atomic VM transaction scaling is near-linear (%.2fx, limit %.2fx)"
			% [vm_scale, MAX_VM_SCALE]
		),
	)
	_expect(
		bool(manager_runtime.valid),
		"production dialogue manager completes a script larger than one pump time-slice",
	)
	_expect(
		(
			int(small_vm.history_records) == KonadoVirtualMachine.DEFAULT_HISTORY_LIMIT
			and int(large_vm.history_records) == KonadoVirtualMachine.DEFAULT_HISTORY_LIMIT
		),
		"VM history remains bounded independently of executed Program size",
	)
	_expect(
		(
			float(large.memory_delta_mib) <= MAX_LARGE_MEMORY_MIB
			and float(mixed_large.memory_delta_mib) <= MAX_LARGE_MEMORY_MIB
		),
		(
			"pure and mixed compiles stay inside the memory guard (%.2f / %.2f MiB)"
			% [large.memory_delta_mib, mixed_large.memory_delta_mib]
		),
	)
	print(
		(
			JSON
			. stringify(
				{
					"pure_small": small_metrics,
					"pure_large": large_metrics,
					"pure_compile_scale": compile_scale,
					"mixed_small": mixed_small_metrics,
					"mixed_large": mixed_large_metrics,
					"mixed_compile_scale": mixed_compile_scale,
					"small_lookup_ms": small_lookup_ms,
					"large_lookup_ms": large_lookup_ms,
					"lookup_scale": lookup_scale,
					"vm_small": small_vm,
					"vm_large": large_vm,
					"vm_scale": vm_scale,
					"manager_runtime": manager_runtime,
				}
			)
		)
	)
	if _failures == 0:
		print("PASS: KonadoScript performance complexity guards")
	quit(_failures)


func _compile(line_count: int, mixed: bool) -> Dictionary:
	var source := _make_mixed_source(line_count) if mixed else _make_source(line_count)
	var memory_before := OS.get_static_memory_usage()
	var started := Time.get_ticks_usec()
	var compiler := KonadoScriptCompiler.new()
	compiler.set_console_output_enabled(false)
	var shot := compiler.compile_string(source, "res://tests/performance.ks")
	var elapsed_usec := Time.get_ticks_usec() - started
	return {
		"lines": line_count + 1,
		"workload": "mixed" if mixed else "pure_dialogue",
		"bytes": source.to_utf8_buffer().size(),
		"instructions": shot.program.instruction_count() if shot != null else 0,
		"valid": shot != null,
		"elapsed_usec": elapsed_usec,
		"elapsed_ms": elapsed_usec / 1000.0,
		"memory_delta_mib": maxi(0, OS.get_static_memory_usage() - memory_before) / 1048576.0,
		"shot": shot,
	}


func _measure_lookup(shot: KonadoShot, iterations: int) -> float:
	if shot == null:
		return INF
	var count := shot.instruction_count()
	var checksum := 0
	var started := Time.get_ticks_usec()
	for index in range(iterations):
		var instruction := shot.instruction_at((index * 7919) % count)
		checksum += instruction.opcode()
	var elapsed_ms := (Time.get_ticks_usec() - started) / 1000.0
	if checksum < 0:
		printerr("unreachable lookup checksum")
	return elapsed_ms


func _measure_vm_transactions(shot: KonadoShot) -> Dictionary:
	if shot == null:
		return {"valid": false, "elapsed_usec": 0, "history_records": 0}
	var vm := KonadoVirtualMachine.new()
	if not vm.install(shot.program):
		return {"valid": false, "elapsed_usec": 0, "history_records": 0}
	var value := 0
	vm.synchronize_state({"variables": {"counter": value}})
	var started := Time.get_ticks_usec()
	while vm.pc != KonadoProgram.INVALID_PC:
		var instruction := vm.current()
		if instruction == null:
			return {"valid": false, "elapsed_usec": 0, "history_records": vm.history_size()}
		var before_patch := KonadoStateDelta.path_patch(["variables", "counter"], true, value)
		var token := vm.begin_patch(before_patch)
		value += 1
		var after_patch := KonadoStateDelta.path_patch(["variables", "counter"], true, value)
		if token.is_empty() or not vm.commit_patch(token, instruction.next_pc(), after_patch):
			return {"valid": false, "elapsed_usec": 0, "history_records": vm.history_size()}
	return {
		"valid": true,
		"elapsed_usec": Time.get_ticks_usec() - started,
		"instructions": shot.instruction_count(),
		"history_records": vm.history_size(),
	}


func _measure_manager_execution(statement_count: int) -> Dictionary:
	var compiler := KonadoScriptCompiler.new()
	compiler.set_console_output_enabled(false)
	var shot := compiler.compile_string(_make_variable_source(statement_count), "")
	if shot == null:
		return {"valid": false, "reason": "fixture did not compile"}
	var manager := DIALOGUE_MANAGER_SCENE.instantiate() as KonadoDialogueManager
	manager.initialize_on_ready = false
	manager.require_visible_in_tree = false
	manager.enable_overlay_log = false
	manager.auto_show_dialogue_box = false
	manager.dialogue_box.enable_typing_effect_audio = false
	root.add_child(manager)
	await process_frame
	var completed := [false]
	var failure := [""]
	manager.shot_end.connect(func() -> void: completed[0] = true, CONNECT_ONE_SHOT)
	manager.runtime_failed.connect(
		func(message: String, _key: String, _line: int) -> void: failure[0] = message,
		CONNECT_ONE_SHOT,
	)
	var started := Time.get_ticks_usec()
	manager.set_shot(shot)
	manager.start_dialogue()
	for _frame in range(120):
		if bool(completed[0]) or not String(failure[0]).is_empty():
			break
		await process_frame
	var elapsed_usec := Time.get_ticks_usec() - started
	var expected_counter := statement_count - 1
	var actual_counter := int(manager._temp_variables.get("counter", -1))
	var result := {
		"valid":
		bool(completed[0]) and String(failure[0]).is_empty() and actual_counter == expected_counter,
		"statements": statement_count,
		"elapsed_usec": elapsed_usec,
		"expected_counter": expected_counter,
		"actual_counter": actual_counter,
		"failure": failure[0],
	}
	manager.queue_free()
	await process_frame
	return result


func _make_source(line_count: int) -> String:
	var lines := PackedStringArray()
	lines.resize(line_count + 1)
	for index in range(line_count):
		lines[index] = '"Kona" "performance line %d"' % index
	lines[line_count] = "end"
	return "\n".join(lines)


func _make_mixed_source(line_count: int) -> String:
	var lines := PackedStringArray()
	var block_index := 0
	while lines.size() + 7 <= line_count:
		lines.append("set $score %d" % block_index)
		lines.append("if $score >= 0:")
		lines.append('    "Kona" "mixed line %d" [speed=1.25]' % block_index)
		lines.append("else:")
		lines.append('    "Kona" "fallback %d" [interval=0.01]' % block_index)
		lines.append("endif")
		lines.append("background bg_end fade [duration=0.2]")
		block_index += 1
	while lines.size() < line_count:
		lines.append('"Kona" "mixed filler %d" [speed=1.1]' % lines.size())
	lines.append("end")
	return "\n".join(lines)


func _make_variable_source(statement_count: int) -> String:
	var lines := PackedStringArray()
	lines.resize(statement_count + 1)
	lines[0] = "set $counter 0"
	for index in range(1, statement_count):
		lines[index] = "add $counter 1"
	lines[statement_count] = "end"
	return "\n".join(lines)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("FAIL: " + message)
