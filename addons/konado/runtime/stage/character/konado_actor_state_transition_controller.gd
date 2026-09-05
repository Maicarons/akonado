@tool
extends RefCounted
class_name KonadoActorStateTransitionController

## 角色状态转场控制器。
## 支持状态帧时使用预乘 Alpha shader 做真正交融；否则只淡变稳定挂载层。
## 两条路径都不会复制角色场景，避免脚本、音频、视频和第三方渲染节点重复运行。

signal transition_started(status_name: String)
signal status_applied(status_name: String)
signal transition_cancelled(status_name: String)
signal transition_finished(status_name: String, succeeded: bool)

const BLEND_SHADER := preload("res://addons/konado/assets/shaders/character_state_blend.gdshader")
const TRANSITION_FRAME_SCRIPT_DIRECTORY := "res://addons/konado/runtime/stage/character/"
const TRANSITION_FRAME_SCRIPT_NAME := "konado_character_transition_frame.gd"

var _host: Node
var _visual_provider: Callable
var _status_applier: Callable
var _frame_provider: Callable
var _status_validator: Callable
var _active_tween: Tween
var _active_visual: CanvasItem
var _blend_overlay: Control
var _blend_material: ShaderMaterial
var _blend_bounds := Rect2()
var _blend_visibility_layer := 1
var _blend_light_mask := 1
var _hidden_frame_visuals: Array[CanvasItem] = []
var _active_status_name := ""
var _active_completion: Callable
var _active_target_alpha := 1.0
var _restore_active_alpha := false
var _request_serial := 0
var _active_request_id := 0
var _apply_succeeded := false
var _has_active_request := false


func _init(
	host: Node,
	visual_provider: Callable,
	status_applier: Callable,
	frame_provider: Callable = Callable(),
	status_validator: Callable = Callable()
) -> void:
	_host = host
	_visual_provider = visual_provider
	_status_applier = status_applier
	_frame_provider = frame_provider
	_status_validator = status_validator


## 请求切换状态。支持安全状态帧时 duration 是交融总时长；
## 否则使用串行淡出/淡入，两个阶段各占一半。
## 新的有效请求会先取消旧请求；无效请求不会扰动当前转场。
## 每个请求的 completion 都保证只调用一次。
func request(
	status_name: String,
	duration: float,
	completion: Callable = Callable(),
	status_prevalidated: bool = false
) -> bool:
	var observed_request_serial := _request_serial
	# 无效请求不是状态切换，也不应打断正在进行的有效转场。校验钩子属于扩展点，
	# 若它重入发起有效请求，外层请求必须让出控制权；无效的重入请求不取得所有权。
	if not status_prevalidated and not _can_apply_status(status_name):
		_call_completion(completion, false)
		return false
	if observed_request_serial != _request_serial:
		_call_completion(completion, false)
		return false
	_request_serial += 1
	_active_request_id += 1
	var request_id := _active_request_id
	if _has_active_request:
		_cancel_active_request()
		# 取消通知及完成回调都是公开扩展点，可能同步发起更新的请求。
		# 后发请求应拥有控制权，当前请求不得覆盖它创建的 Tween 与清理状态。
		if request_id != _active_request_id:
			_call_completion(completion, false)
			return false
	_active_status_name = status_name
	_active_completion = completion
	_apply_succeeded = false
	_has_active_request = true
	transition_started.emit(status_name)
	if not _is_current_request(request_id):
		return false
	_begin_request(request_id, duration)
	return true


func _begin_request(request_id: int, duration: float) -> void:
	if not _is_current_request(request_id):
		return

	var visual := _get_visual()
	if not _is_current_request(request_id):
		return
	if duration <= 0.0 or visual == null or not _can_animate():
		_apply_and_finish(request_id)
		return

	_active_visual = visual
	_active_target_alpha = visual.modulate.a
	var blend_started := _try_start_frame_blend(request_id, maxf(duration, 0.0))
	if not _is_current_request(request_id):
		return
	if not blend_started:
		_start_fade_out(request_id, maxf(duration, 0.0) * 0.5)


## 取消当前请求并恢复实时视觉。取消请求会以失败状态完成。
func cancel() -> void:
	if not _has_active_request:
		return
	_active_request_id += 1
	_cancel_active_request()


func _cancel_active_request() -> void:
	if not _has_active_request:
		return
	var status_name := _active_status_name
	var completion := _active_completion
	_stop_tween()
	var cleanup_state := _take_cleanup_state()
	_clear_active_state()
	_restore_cleanup_state(cleanup_state)
	transition_cancelled.emit(status_name)
	transition_finished.emit(status_name, false)
	_call_completion(completion, false)


func is_transitioning() -> bool:
	return _has_active_request


func _try_start_frame_blend(request_id: int, duration: float) -> bool:
	var old_frame := _get_transition_frame("")
	if not _is_current_request(request_id):
		return false
	var new_frame := _get_transition_frame(_active_status_name)
	if (
		not _is_current_request(request_id)
		or not _can_blend_frames(old_frame, new_frame)
		or not _create_blend_overlay(request_id, old_frame, new_frame)
	):
		return false

	# shader 从旧状态帧交融到目标状态帧；实时状态保持不变直到转场结束。
	# 因此取消请求不会留下“画面已切换但状态回滚”的半完成状态。
	_hide_blend_visual()
	var blend_started := _is_current_request(request_id)
	if not blend_started:
		return blend_started
	if duration <= 0.0:
		_on_blend_finished(request_id)
	else:
		_active_tween = _host.create_tween()
		_active_tween.set_parallel(true)
		_active_tween.set_trans(Tween.TRANS_SINE)
		_active_tween.set_ease(Tween.EASE_IN_OUT)
		_active_tween.tween_property(_blend_material, "shader_parameter/progress", 1.0, duration)
		_active_tween.tween_method(_sync_blend_overlay.bind(request_id), 0.0, 1.0, duration)
		_active_tween.finished.connect(
			_on_blend_finished.bind(request_id), ConnectFlags.CONNECT_ONE_SHOT
		)
	return blend_started


func _on_blend_finished(request_id: int) -> void:
	if not _is_current_request(request_id):
		return
	_active_tween = null
	var previous_visual := _active_visual
	var previous_target_alpha := _active_target_alpha
	var apply_succeeded := _apply_status(_active_status_name)
	if not _is_current_request(request_id):
		return
	_apply_succeeded = apply_succeeded
	if _apply_succeeded:
		status_applied.emit(_active_status_name)
		if not _is_current_request(request_id):
			return
	var next_visual := _get_visual()
	if not _is_current_request(request_id):
		return
	if next_visual != null:
		_active_visual = next_visual
		_active_target_alpha = (
			previous_target_alpha if next_visual == previous_visual else next_visual.modulate.a
		)
	# 帧交融从未修改实时节点的 alpha。即使状态应用后视觉提供器暂时返回 null，
	# 也不能用转场开始时的快照覆盖同时运行的舞台透明度动画。
	_finish(request_id)


func _start_fade_out(request_id: int, duration: float) -> void:
	_restore_active_alpha = true
	if duration <= 0.0:
		_on_fade_out_finished(request_id, duration)
		return
	_active_tween = _host.create_tween()
	_active_tween.set_trans(Tween.TRANS_SINE)
	_active_tween.set_ease(Tween.EASE_IN)
	_active_tween.tween_property(_active_visual, "modulate:a", 0.0, duration)
	_active_tween.finished.connect(
		_on_fade_out_finished.bind(request_id, duration), ConnectFlags.CONNECT_ONE_SHOT
	)


func _on_fade_out_finished(request_id: int, fade_in_duration: float) -> void:
	if not _is_current_request(request_id):
		return
	_active_tween = null
	var previous_visual := _active_visual
	var previous_target_alpha := _active_target_alpha
	var apply_succeeded := _apply_status(_active_status_name)
	if not _is_current_request(request_id):
		return
	_apply_succeeded = apply_succeeded
	if _apply_succeeded:
		status_applied.emit(_active_status_name)
		if not _is_current_request(request_id):
			return

	var next_visual := _get_visual()
	if not _is_current_request(request_id):
		return
	if next_visual == null or not _can_animate():
		_restore_canvas_item(previous_visual, previous_target_alpha)
		_finish(request_id)
		return

	_active_visual = next_visual
	_active_target_alpha = (
		previous_target_alpha if next_visual == previous_visual else next_visual.modulate.a
	)
	_set_alpha(next_visual, 0.0)
	if fade_in_duration <= 0.0:
		_restore_visual()
		_finish(request_id)
		return

	_active_tween = _host.create_tween()
	_active_tween.set_trans(Tween.TRANS_SINE)
	_active_tween.set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(
		_active_visual, "modulate:a", _active_target_alpha, fade_in_duration
	)
	_active_tween.finished.connect(
		_on_fade_in_finished.bind(request_id), ConnectFlags.CONNECT_ONE_SHOT
	)


func _on_fade_in_finished(request_id: int) -> void:
	if not _is_current_request(request_id):
		return
	_active_tween = null
	_finish(request_id)


func _apply_and_finish(request_id: int) -> void:
	var apply_succeeded := _apply_status(_active_status_name)
	if not _is_current_request(request_id):
		return
	_apply_succeeded = apply_succeeded
	if _apply_succeeded:
		status_applied.emit(_active_status_name)
		if not _is_current_request(request_id):
			return
	_finish(request_id)


func _finish(request_id: int) -> void:
	if not _is_current_request(request_id):
		return
	var status_name := _active_status_name
	var completion := _active_completion
	var succeeded := _apply_succeeded
	_stop_tween()
	var cleanup_state := _take_cleanup_state()
	_clear_active_state()
	_restore_cleanup_state(cleanup_state)
	transition_finished.emit(status_name, succeeded)
	_call_completion(completion, succeeded)


func _create_blend_overlay(request_id: int, old_frame: RefCounted, new_frame: RefCounted) -> bool:
	if not _can_create_blend_overlay():
		return false
	var target := _active_visual as Control
	var target_parent := target.get_parent()
	var overlay := Control.new()
	overlay.name = "_KonadoStateBlend"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blend_bounds = _get_blend_bounds(old_frame, new_frame)
	_blend_visibility_layer = int(old_frame.get("visibility_layer"))
	_blend_light_mask = int(old_frame.get("light_mask"))
	_sync_blend_overlay_state(overlay, target)

	var blend_rect := ColorRect.new()
	blend_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blend_rect.color = Color.WHITE
	blend_rect.visibility_layer = _blend_visibility_layer
	blend_rect.light_mask = _blend_light_mask
	overlay.add_child(blend_rect)
	blend_rect.position = _blend_bounds.position
	blend_rect.size = _blend_bounds.size

	var material := ShaderMaterial.new()
	material.shader = BLEND_SHADER
	blend_rect.material = material
	blend_rect.texture_filter = int(old_frame.get("texture_filter")) as CanvasItem.TextureFilter
	material.set_shader_parameter("target_origin", _blend_bounds.position)
	material.set_shader_parameter("target_size", _blend_bounds.size)
	_set_frame_shader_parameters(material, "old", old_frame)
	_set_frame_shader_parameters(material, "new", new_frame)
	material.set_shader_parameter("progress", 0.0)
	_blend_overlay = overlay
	_blend_material = material
	(target_parent as Control).add_child(overlay)
	if not _is_current_request(request_id):
		return false
	(target_parent as Control).move_child(overlay, target.get_index())
	if not _is_current_request(request_id):
		return false
	_sync_blend_overlay(0.0, request_id)
	return true


func _can_create_blend_overlay() -> bool:
	if not (_active_visual is Control):
		return false
	var target := _active_visual as Control
	if target.size.x < 1.0 or target.size.y < 1.0:
		return false
	var target_parent := target.get_parent()
	# 交融层必须是稳定挂载层的同级节点，才能在隐藏整个实时角色画面时继续显示。
	# 非 Control 父节点无法可靠复刻布局，直接使用安全降级路径。
	if not (target_parent is Control) or target_parent is Container or target.top_level:
		return false
	# Overlay 只能复刻普通 CanvasItem 合成。挂载层本身使用材质、父材质，
	# 或由 CanvasGroup 统一合成时，隐藏实时节点会改变最终渲染语义，必须降级。
	return (
		target.material == null
		and not target.use_parent_material
		and not target_parent is CanvasGroup
	)


func _sync_blend_overlay(_progress: float = 0.0, request_id: int = -1) -> void:
	if request_id >= 0 and not _is_current_request(request_id):
		return
	if (
		_blend_overlay == null
		or not is_instance_valid(_blend_overlay)
		or not (_active_visual is Control)
	):
		return
	var target := _active_visual as Control
	_sync_blend_overlay_state(_blend_overlay, target)


func _sync_blend_overlay_state(overlay: Control, target: Control) -> void:
	# 覆盖层与实时挂载层属于同一父节点。复制完整的可见变换和绘制顺序，避免
	# Godot 4.7 的视觉偏移、运行时布局动画或 behind-parent 设置在交融期间跳变。
	overlay.modulate = target.modulate
	overlay.self_modulate = target.self_modulate
	overlay.position = target.position
	overlay.size = target.size
	overlay.pivot_offset = target.pivot_offset
	overlay.rotation = target.rotation
	overlay.scale = target.scale
	overlay.offset_transform_position = target.offset_transform_position
	overlay.offset_transform_position_ratio = target.offset_transform_position_ratio
	overlay.offset_transform_scale = target.offset_transform_scale
	overlay.offset_transform_rotation = target.offset_transform_rotation
	overlay.offset_transform_pivot = target.offset_transform_pivot
	overlay.offset_transform_pivot_ratio = target.offset_transform_pivot_ratio
	overlay.offset_transform_visual_only = target.offset_transform_visual_only
	overlay.offset_transform_enabled = target.offset_transform_enabled
	overlay.clip_contents = target.clip_contents
	overlay.show_behind_parent = target.show_behind_parent
	overlay.z_index = target.z_index
	overlay.z_as_relative = target.z_as_relative
	overlay.visibility_layer = _blend_visibility_layer
	overlay.light_mask = _blend_light_mask


func _set_frame_shader_parameters(
	material: ShaderMaterial, prefix: String, frame: RefCounted
) -> void:
	var frame_to_target: Transform2D = frame.get("frame_to_target")
	var target_inverse: Transform2D = frame_to_target.affine_inverse()
	var texture: Texture2D = frame.get("texture")
	var source_region: Rect2 = frame.get("source_region")
	var sampling_clip_region: Rect2 = frame.get("sampling_clip_region")
	material.set_shader_parameter(prefix + "_texture", texture)
	material.set_shader_parameter(
		prefix + "_inverse_basis",
		Vector4(target_inverse.x.x, target_inverse.x.y, target_inverse.y.x, target_inverse.y.y)
	)
	material.set_shader_parameter(prefix + "_inverse_origin", target_inverse.origin)
	material.set_shader_parameter(
		prefix + "_region",
		Vector4(
			source_region.position.x,
			source_region.position.y,
			source_region.size.x,
			source_region.size.y
		)
	)
	material.set_shader_parameter(prefix + "_texture_size", Vector2(texture.get_size()))
	material.set_shader_parameter(
		prefix + "_clip_region",
		Vector4(
			sampling_clip_region.position.x,
			sampling_clip_region.position.y,
			sampling_clip_region.size.x,
			sampling_clip_region.size.y
		)
	)
	material.set_shader_parameter(prefix + "_filter_clip", frame.get("filter_clip"))
	material.set_shader_parameter(
		prefix + "_flip", Vector2(float(frame.get("flip_h")), float(frame.get("flip_v")))
	)
	material.set_shader_parameter(prefix + "_modulate", frame.get("modulate"))


func _hide_blend_visual() -> void:
	if (
		_active_visual == null
		or not is_instance_valid(_active_visual)
		or not _active_visual.visible
	):
		return
	for existing in _hidden_frame_visuals:
		if existing == _active_visual:
			return
	_hidden_frame_visuals.append(_active_visual)
	# 先登记再隐藏；visible_changed 回调若重入并取消转场，清理逻辑才能恢复该节点。
	_active_visual.visible = false


func _take_cleanup_state() -> Dictionary:
	var cleanup_state := {
		"overlay": _blend_overlay,
		"hidden_visuals": _hidden_frame_visuals.duplicate(),
		"active_visual": _active_visual,
		"target_alpha": _active_target_alpha,
		"restore_active_alpha": _restore_active_alpha,
	}
	_blend_overlay = null
	_blend_material = null
	_blend_bounds = Rect2()
	_blend_visibility_layer = 1
	_blend_light_mask = 1
	_hidden_frame_visuals.clear()
	return cleanup_state


func _restore_cleanup_state(cleanup_state: Dictionary) -> void:
	var overlay: Control = cleanup_state.get("overlay") as Control
	if overlay and is_instance_valid(overlay):
		# queue_free 在当前帧末才执行；先隐藏可避免新状态实时节点
		# 与已到达 100% 的交融层短暂叠加，导致透明边缘变亮。
		overlay.visible = false
		overlay.queue_free()
	if cleanup_state.get("restore_active_alpha", false):
		_restore_canvas_item(
			cleanup_state.get("active_visual") as CanvasItem,
			float(cleanup_state.get("target_alpha", 1.0))
		)
	var hidden_visuals: Array = cleanup_state.get("hidden_visuals", [])
	for visual: CanvasItem in hidden_visuals:
		if visual != null and is_instance_valid(visual):
			visual.visible = true


func _can_blend_frames(old_frame: RefCounted, new_frame: RefCounted) -> bool:
	return (
		old_frame != new_frame
		and _is_valid_transition_frame(old_frame)
		and _is_valid_transition_frame(new_frame)
		and old_frame.get("texture_filter") == new_frame.get("texture_filter")
		and old_frame.get("visibility_layer") == new_frame.get("visibility_layer")
		and old_frame.get("light_mask") == new_frame.get("light_mask")
	)


func _get_blend_bounds(old_frame: RefCounted, new_frame: RefCounted) -> Rect2:
	# 不信任可独立修改的缓存边界；官方状态帧会从采样区域和变换实时推导。
	var old_bounds: Rect2 = old_frame.call("get_target_bounds")
	var new_bounds: Rect2 = new_frame.call("get_target_bounds")
	return old_bounds.merge(new_bounds)


func _get_transition_frame(status_name: String) -> RefCounted:
	if not _frame_provider.is_valid():
		return null
	var frame: Variant = _frame_provider.call(status_name)
	if frame is RefCounted and _is_official_transition_frame(frame as RefCounted):
		return frame as RefCounted
	return null


func _is_valid_transition_frame(frame: RefCounted) -> bool:
	if (
		frame == null
		or not _is_official_transition_frame(frame)
		or frame.call("is_valid") != true
		or _active_visual == null
		or not is_instance_valid(_active_visual)
	):
		return false
	var source_visual := frame.get("source_visual") as CanvasItem
	return (
		source_visual != null
		and is_instance_valid(source_visual)
		and source_visual.is_visible_in_tree()
		and (source_visual == _active_visual or _active_visual.is_ancestor_of(source_visual))
	)


func _is_official_transition_frame(frame: RefCounted) -> bool:
	# 不在这里静态引用全局类。Godot 4.7.1 会把仅由类型依赖加载、却未实例化的
	# GDScript 留到错误的清理阶段，令无关的 headless 测试报告资源泄漏。
	# 状态帧是控制器信任的纯数据边界，只接受官方脚本的直接实例；自定义场景应通过
	# 官方构造器创建帧，不能用覆写 is_valid() 的子类绕过纹理和几何校验。
	var frame_script := frame.get_script() as Script
	return (
		frame_script != null
		and (
			frame_script.resource_path
			== TRANSITION_FRAME_SCRIPT_DIRECTORY + TRANSITION_FRAME_SCRIPT_NAME
		)
	)


func _can_apply_status(status_name: String) -> bool:
	if not _status_validator.is_valid():
		return true
	return _status_validator.call(status_name) == true


func _apply_status(status_name: String) -> bool:
	if not _status_applier.is_valid():
		return false
	return _status_applier.call(status_name) == true


func _get_visual() -> CanvasItem:
	if not _visual_provider.is_valid():
		return null
	var visual: Variant = _visual_provider.call()
	if visual is CanvasItem and is_instance_valid(visual):
		return visual as CanvasItem
	return null


func _can_animate() -> bool:
	return _host != null and is_instance_valid(_host) and _host.is_inside_tree()


func _is_current_request(request_id: int) -> bool:
	return request_id == _active_request_id and _has_active_request


func _stop_tween() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null


func _restore_visual() -> void:
	_restore_canvas_item(_active_visual, _active_target_alpha)


func _restore_canvas_item(visual: CanvasItem, target_alpha: float) -> void:
	if visual == null or not is_instance_valid(visual):
		return
	_set_alpha(visual, target_alpha)


func _set_alpha(visual: CanvasItem, alpha: float) -> void:
	var color := visual.modulate
	color.a = clampf(alpha, 0.0, 1.0)
	visual.modulate = color


func _clear_active_state() -> void:
	_has_active_request = false
	_active_status_name = ""
	_active_completion = Callable()
	_active_visual = null
	_active_target_alpha = 1.0
	_restore_active_alpha = false
	_apply_succeeded = false
	_hidden_frame_visuals.clear()


func _call_completion(completion: Callable, succeeded: bool) -> void:
	if completion.is_valid():
		completion.call(succeeded)
