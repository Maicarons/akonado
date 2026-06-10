extends Control
class_name KND_ActingInterface

## 表演管理器

## 完成背景切换的信号
signal background_change_finished
## 完成角色显示的信号
signal character_shown
## 完成角色创建的信号，保留给旧调用方兼容
signal character_created
## 完成角色删除的信号
signal character_deleted
## 完成角色切换状态的信号
signal character_state_changed
## 完成角色移动的信号
signal character_moved
## 指定角色舞台动作开始的信号
signal character_motion_started(actor_id: String, motion_name: String)
## 指定角色舞台动作完成的信号
signal character_motion_finished(actor_id: String, motion_name: String)

## 特效种类
enum BackgroundTransitionEffectsType {
	NONE_EFFECT, ## 无效果
	EraseEffect, ## 擦除效果
	BlindsEffect, ## 百叶窗效果
	WaveEffect, ## 波浪效果
	ALPHA_FADE_EFFECT, ## ALPHA淡入淡出
	VORTEX_SWAP_EFFECT, ## 极坐标漩涡效果
	WINDMILL_EFFECT, ## 风车效果
	CYBER_GLITCH_EFFECT, ## 电子故障效果
	BlinkEffect, ## 眨眼效果
	NULL = -1
	}
	
## 演员模板
@onready var _konado_actor_template: PackedScene = preload("res://addons/konado/template/character/character_template.tscn")

## 演员字典
var actor_dict = {}
## 演员节点字典，用于快速访问演员节点
var actor_nodes = {}
## 角色列表
var chara_list: KND_CharacterList
## 背景底色层
@onready var _background: ColorRect = get_node_or_null("BackgroundLayer") as ColorRect
## 背景场景容器
@onready var _background_container: Control = get_node_or_null("BackgroundLayer/BackgroundContainer") as Control
## 背景 shader 转场层
@onready var _background_transition_layer: KND_BackgroundTransitionLayer = get_node_or_null("BackgroundTransitionLayer") as KND_BackgroundTransitionLayer
## 角色容器
@onready var _chara_controler: Control = get_node_or_null("CharaControl") as Control
## 效果层
@onready var _effect_layer: ColorRect = get_node_or_null("EffectLayer") as ColorRect

## 存档用背景 id
var background_id: String = ""

var _current_background_scene: KND_BackgroundSceneBase
var _transition_old_background: KND_BackgroundSceneBase
var _pending_shader_background: KND_BackgroundSceneBase
var _background_transition_wait_count: int = 0

const BACKGROUND_EFFECT_NAMES := {
	BackgroundTransitionEffectsType.NONE_EFFECT: "none",
	BackgroundTransitionEffectsType.EraseEffect: "erase",
	BackgroundTransitionEffectsType.BlindsEffect: "blinds",
	BackgroundTransitionEffectsType.WaveEffect: "wave",
	BackgroundTransitionEffectsType.ALPHA_FADE_EFFECT: "fade",
	BackgroundTransitionEffectsType.VORTEX_SWAP_EFFECT: "vortex",
	BackgroundTransitionEffectsType.WINDMILL_EFFECT: "windmill",
	BackgroundTransitionEffectsType.CYBER_GLITCH_EFFECT: "cyberglitch",
	BackgroundTransitionEffectsType.BlinkEffect: "blink",
}


func _ready() -> void:
	_ensure_stage_nodes()
	for child in _chara_controler.get_children():
		child.queue_free()

## 确保表演舞台的层级存在。
## 背景已经全面转成场景，这里只兜住“场景挂载层”本身，避免旧模板实例没有 BackgroundContainer 时背景无法显示。
func _ensure_stage_nodes() -> void:
	if _background == null:
		_background = ColorRect.new()
		_background.name = "BackgroundLayer"
		_background.color = Color.BLACK
		add_child(_background)
	if _background_container == null:
		_background_container = Control.new()
		_background_container.name = "BackgroundContainer"
		_background.add_child(_background_container)
	elif _background_container.get_parent() != _background:
		var container_parent := _background_container.get_parent()
		if container_parent:
			container_parent.remove_child(_background_container)
		_background.add_child(_background_container)

	if _background_transition_layer == null:
		_background_transition_layer = KND_BackgroundTransitionLayer.new()
		_background_transition_layer.name = "BackgroundTransitionLayer"
		add_child(_background_transition_layer)
	elif _background_transition_layer.get_parent() != self:
		var transition_parent := _background_transition_layer.get_parent()
		if transition_parent:
			transition_parent.remove_child(_background_transition_layer)
		add_child(_background_transition_layer)

	if _chara_controler == null:
		_chara_controler = get_node_or_null("BackgroundLayer/CharaControl") as Control
	if _chara_controler == null:
		_chara_controler = Control.new()
		_chara_controler.name = "CharaControl"
		add_child(_chara_controler)
	elif _chara_controler.get_parent() != self:
		var chara_parent := _chara_controler.get_parent()
		if chara_parent:
			chara_parent.remove_child(_chara_controler)
		add_child(_chara_controler)

	if _effect_layer == null:
		_effect_layer = ColorRect.new()
		_effect_layer.name = "EffectLayer"
		_effect_layer.color = Color(0, 0, 0, 0)
		add_child(_effect_layer)

	_set_full_rect(_background)
	_set_full_rect(_background_container)
	_set_full_rect(_background_transition_layer)
	_set_full_rect(_chara_controler)
	_set_full_rect(_effect_layer)

	## 层级顺序固定为：背景场景 -> shader 转场 -> 角色 -> 全屏效果。
	if _background.get_parent() == self:
		move_child(_background, 0)
	if _background_transition_layer.get_parent() == self:
		move_child(_background_transition_layer, min(1, get_child_count() - 1))
	if _chara_controler.get_parent() == self:
		move_child(_chara_controler, min(2, get_child_count() - 1))
	if _effect_layer.get_parent() == self:
		move_child(_effect_layer, get_child_count() - 1)

func _set_full_rect(control: Control) -> void:
	if control == null:
		return
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.set_anchors_preset(Control.PRESET_FULL_RECT, true)
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0
	control.position = Vector2.ZERO
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
## 获取角色节点的方法
func get_chara_node(actor_id: String) -> Node:
	 # 首先从演员节点字典中获取
	if actor_nodes.has(actor_id):
		var cached_node = actor_nodes[actor_id]
		if cached_node and is_instance_valid(cached_node):
			return cached_node
		actor_nodes.erase(actor_id)
		
	# 如果字典中没有，再通过find_child方法查找
	var chara_node: Node = _chara_controler.find_child(actor_id, true, false)
	if chara_node:
		# 将找到的节点添加到字典中
		actor_nodes[actor_id] = chara_node
		return chara_node
	return null
			
## 清空背景
func clean_background(effects_type: BackgroundTransitionEffectsType) -> void:
	_ensure_stage_nodes()
	_clear_pending_background_transition()
	background_id = ""
	if _current_background_scene == null:
		background_change_finished.emit()
		return
	_transition_old_background = _current_background_scene
	_current_background_scene = null
	_background_transition_wait_count = 1
	_transition_old_background.background_exit_finished.connect(
		_on_background_transition_part_finished.bind(_transition_old_background),
		ConnectFlags.CONNECT_ONE_SHOT
	)
	_transition_old_background.play_exit(_background_effect_name(effects_type))

## 显示背景场景的方法
func change_background_scene(scene: PackedScene, name: String, effects_type: BackgroundTransitionEffectsType) -> void:
	_ensure_stage_nodes()
	if scene == null:
		print_rich("[color=red]切换背景失败，空背景场景，请检查背景资源[/color]")
		background_change_finished.emit()
		return
	_clear_pending_background_transition()
	var instance := scene.instantiate()
	if not (instance is KND_BackgroundSceneBase):
		push_error("背景场景必须继承 KND_BackgroundSceneBase：" + name)
		instance.queue_free()
		background_change_finished.emit()
		return

	var next_background := instance as KND_BackgroundSceneBase
	background_id = name
	next_background.name = name
	_prepare_background_scene(next_background)
	next_background.setup_background(name)

	var old_background := _current_background_scene
	var effect_name := _background_effect_name(effects_type)
	if _should_use_shader_transition(effect_name):
		_pending_shader_background = next_background
		_transition_old_background = old_background
		if not _background_transition_layer.transition_finished.is_connected(_on_shader_background_transition_finished):
			_background_transition_layer.transition_finished.connect(_on_shader_background_transition_finished)
		_background_transition_layer.play_transition(old_background, next_background, effect_name)
		print_rich("[color=cyan]切换背景为: [/color]"+str(name) +" " + "过渡效果: " + str(effects_type))
		return

	_background_container.add_child(next_background)
	_current_background_scene = next_background
	_transition_old_background = old_background
	_background_transition_wait_count = 1
	next_background.background_enter_finished.connect(
		_on_background_transition_part_finished.bind(next_background),
		ConnectFlags.CONNECT_ONE_SHOT
	)
	if old_background and is_instance_valid(old_background):
		_background_transition_wait_count += 1
		old_background.background_exit_finished.connect(
			_on_background_transition_part_finished.bind(old_background),
			ConnectFlags.CONNECT_ONE_SHOT
		)
		old_background.play_exit(effect_name)
	next_background.play_enter(effect_name)
	print_rich("[color=cyan]切换背景为: [/color]"+str(name) +" " + "过渡效果: " + str(effects_type))

func _prepare_background_scene(background: KND_BackgroundSceneBase) -> void:
	_set_full_rect(background)

func _background_effect_name(effects_type: BackgroundTransitionEffectsType) -> String:
	return BACKGROUND_EFFECT_NAMES.get(effects_type, "none")

func _should_use_shader_transition(effect_name: String) -> bool:
	return _background_transition_layer != null and _background_transition_layer.supports_effect(effect_name)

func _clear_pending_background_transition() -> void:
	if _background_transition_layer and _background_transition_layer.is_transitioning():
		_background_transition_layer.cancel_transition(true)
		_current_background_scene = null
		_pending_shader_background = null
	if _transition_old_background and is_instance_valid(_transition_old_background):
		_transition_old_background.stop_background_transition()
		if _transition_old_background != _current_background_scene:
			_transition_old_background.queue_free()
	_transition_old_background = null
	_background_transition_wait_count = 0

func _on_background_transition_part_finished(background: KND_BackgroundSceneBase) -> void:
	_background_transition_wait_count -= 1
	if _background_transition_wait_count > 0:
		return
	if _transition_old_background and is_instance_valid(_transition_old_background):
		_transition_old_background.queue_free()
	_transition_old_background = null
	print("背景场景切换完成")
	background_change_finished.emit()

func _on_shader_background_transition_finished(old_background: KND_BackgroundSceneBase, new_background: KND_BackgroundSceneBase) -> void:
	if old_background and is_instance_valid(old_background):
		old_background.queue_free()
	if new_background and is_instance_valid(new_background):
		var parent := new_background.get_parent()
		if parent:
			parent.remove_child(new_background)
		_background_container.add_child(new_background)
		_prepare_background_scene(new_background)
		new_background.show()
		_current_background_scene = new_background
	else:
		_current_background_scene = null
	_pending_shader_background = null
	_transition_old_background = null
	_background_transition_wait_count = 0
	print("背景 shader 转场完成")
	background_change_finished.emit()

## 显示角色。角色不存在时创建，已存在时复用节点并更新状态或位置。
func show_character(chara_id: String, h_division: int, pos_h: int, state: String, character_scene: PackedScene = null, motion_layer_scene: PackedScene = null) -> void:
	var existing_actor := get_chara_node(chara_id) as KND_Actor
	if existing_actor != null:
		_update_existing_character(existing_actor, chara_id, h_division, pos_h, state)
		return

	# actor_dict 可能残留旧数据；没有有效节点时按新建处理。
	if actor_dict.has(chara_id):
		actor_dict.erase(chara_id)

	if character_scene == null:
		push_error("显示角色失败：角色[%s]没有配置角色场景" % chara_id)
		_emit_character_shown()
		return
			
	# 角色信息字典结构说明:
	# {
	#     "id": int,        # 角色唯一标识
	#     "division": int,       # X轴坐标
	#     "y": float,       # Y轴坐标
	#     "state": String,   # 当前状态标识
	#     "c_scale": float, # 缩放系数
	#     "mirror": bool    # 是否镜像翻转
	# }

	var initial_h_division: int = clamp(h_division, 2, 5)
	var initial_pos_h: int = clamp(pos_h, 0, initial_h_division)
	var chara_dict: Dictionary = {
		"id": chara_id,
		"h_division": initial_h_division,
		"pos": initial_pos_h,
		"state": state
	}
		
	# 添加到角色字典
	actor_dict[chara_dict["id"]] = chara_dict
	var node_name : String = str(chara_dict["id"])
	var temp_node : KND_Actor = _konado_actor_template.instantiate() as KND_Actor
	temp_node.name = node_name
	temp_node.use_tween = false
	temp_node.set_stage_position(h_division, pos_h)
	# 添加到角色容器
	_chara_controler.add_child(temp_node)
	temp_node.actor_motion_started.connect(_on_character_motion_started.bind(chara_id))
	temp_node.actor_motion_finished.connect(_on_character_motion_finished.bind(chara_id))
	temp_node.set_motion_layer_scene(motion_layer_scene)
	temp_node.set_character_scene(character_scene, state)
	# 添加到演员节点字典
	actor_nodes[chara_id] = temp_node
	# 移动信号
	temp_node.actor_moved.connect(_on_character_moved)
	temp_node.actor_entered.connect(_on_character_entered.bind(chara_id, state), ConnectFlags.CONNECT_ONE_SHOT)
	temp_node.use_tween = true
	temp_node.enter_actor(true)

## 旧接口名保留兼容。新代码应使用 show_character，表达 show 的 upsert 语义。
func create_new_character(chara_id: String, h_division: int, pos_h: int, state: String, character_scene: PackedScene = null, motion_layer_scene: PackedScene = null) -> void:
	show_character(chara_id, h_division, pos_h, state, character_scene, motion_layer_scene)

func _update_existing_character(chara_node: KND_Actor, chara_id: String, h_division: int, pos_h: int, state: String) -> void:
	var previous_state := ""
	if actor_dict.has(chara_id):
		previous_state = str(actor_dict[chara_id].get("state", ""))

	var next_h_division: int = clamp(h_division, 2, 5)
	var next_pos_h: int = clamp(pos_h, 0, next_h_division)
	var position_changed: bool = chara_node.h_division != next_h_division or chara_node.h_character_position != next_pos_h
	var state_changed: bool = previous_state != state

	actor_dict[chara_id] = {
		"id": chara_id,
		"h_division": next_h_division,
		"pos": next_pos_h,
		"state": state
	}
	actor_nodes[chara_id] = chara_node

	if position_changed:
		chara_node.set_stage_position(next_h_division, next_pos_h)
	if state_changed:
		chara_node.apply_character_status(state)
	if position_changed and chara_node.slot != null and chara_node.use_tween and chara_node.animation_time > 0.0:
		await chara_node.actor_moved

	print("复用已有演员：" + str(chara_id) + " 演员状态：" + str(state))
	_emit_character_shown()

func _on_character_entered(chara_id: String, state: String) -> void:
	_emit_character_shown()
	print("新建了演员："+str(chara_id)+" 演员状态："+str(state))

func _emit_character_shown() -> void:
	character_shown.emit()
	character_created.emit()

## 切换演员的状态
func change_actor_state(actor_id: String, state_id: String) -> void:
	var chara_node: KND_Actor = get_chara_node(actor_id)
	if chara_node == null:
		push_error("切换角色状态失败：角色ID[%s]，目标状态ID[%s]，未找到角色节点" % [actor_id, state_id])
		character_state_changed.emit()
	else:
		# 修改字典中角色的状态
		actor_dict[actor_id]["state"] = state_id
		chara_node.apply_character_status(state_id)
		character_state_changed.emit()
		print("切换"+actor_id+"到"+str(state_id)+"状态")

## 播放指定演员的舞台层动作，例如 shake、jump_twice、bounce。
## 这里不进入角色场景，避免把整体位移和内部表情/媒体播放混在一起。
func play_actor_motion(actor_id: String, motion_name: String, params: Dictionary = {}) -> void:
	if motion_name.is_empty():
		push_error("播放演员动作失败：角色ID[%s]，动作名为空" % actor_id)
		character_motion_finished.emit(actor_id, motion_name)
		return
	var chara_node: KND_Actor = get_chara_node(actor_id) as KND_Actor
	if chara_node == null:
		push_error("播放演员动作失败：角色ID[%s]，动作[%s]，未找到角色节点" % [actor_id, motion_name])
		character_motion_finished.emit(actor_id, motion_name)
		return
	chara_node.play_actor_motion(motion_name, params)


# 高亮角色
func highlight_actor(actor_id: String) -> void:
	if actor_dict.size() <= 0:
		return
	for actor in actor_dict.keys():
		var tmp = get_chara_node(actor)
		if actor_id == actor:
			tmp.set_highlight(true)
		else:
			tmp.set_highlight(false)

#
	#var chara_node: KND_Actor = get_chara_node(actor_id)
	##
	#if chara_node != null:
		##如果剧情角色名字和演员名字不匹配，就pass，防止崩溃
		#var tex_node = chara_node.find_child(actor_id, true, false)
		#if tex_node:
			## 修改字典中角色的状态
			#tex_node.set_modulate(Color(1.0, 1.0, 1.0))
		#pass
	#

# 删除指定角色图片的方法
func delete_character(chara_id: String) -> void:
	# 检查要删除的角色是否在容器和字典中
	for actor in actor_dict.values():
		if actor["id"] == chara_id:
			# 删除容器和字典中的角色
			actor_dict.erase(chara_id)
			# 从演员节点字典中删除
			actor_nodes.erase(chara_id)
			# 通过名称查找索引并删除
			var chara_node: KND_Actor = get_chara_node(chara_id) as KND_Actor
			if chara_node:
				chara_node.tree_exited.connect(func(): character_deleted.emit())
				chara_node.exit_actor(true)
			else:
				print("找不到要删除的演员")
				character_deleted.emit()
				return
				
## 删除所有演员
func delete_all_actor() -> void:
	actor_dict.clear()
	# 清空演员节点字典
	actor_nodes.clear()
	for node in _chara_controler.get_children():
		node.exit_actor(false)
	print("删除所有演员")

## 移动演员的方法
func move_actor(chara_id: String, target_h_division: int):
	print("移动演员")
	print(target_h_division)
	var chara_node: KND_Actor = get_chara_node(chara_id) as KND_Actor
	if chara_node == null:
		push_error("移动角色失败：角色ID[%s]，未找到角色节点" % chara_id)
		character_moved.emit()
		return
	if not chara_node.set_stage_position(chara_node.h_division, target_h_division):
		character_moved.emit()

	
func _on_character_moved() -> void:
	print("移动回调")
	character_moved.emit()
	pass

func _on_character_motion_started(motion_name: String, actor_id: String) -> void:
	character_motion_started.emit(actor_id, motion_name)

func _on_character_motion_finished(motion_name: String, actor_id: String) -> void:
	character_motion_finished.emit(actor_id, motion_name)
	
