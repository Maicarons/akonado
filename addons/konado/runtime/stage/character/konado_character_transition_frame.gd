@tool
extends RefCounted
class_name KonadoCharacterTransitionFrame

## 角色状态交融所需的一帧纯渲染数据。
## 该对象只引用纹理和几何信息，不复制或运行角色场景中的脚本、音频和动态媒体节点。

var texture: Texture2D
var source_region := Rect2()
var sampling_clip_region := Rect2()
var filter_clip := false
var frame_to_target := Transform2D.IDENTITY
var modulate := Color.WHITE
var flip_h := false
var flip_v := false
var texture_filter := CanvasItem.TEXTURE_FILTER_PARENT_NODE
var visibility_layer := 1
var light_mask := 1
var source_visual: CanvasItem
var source_visible := true


func is_valid() -> bool:
	var transform_determinant := frame_to_target.determinant()
	var target_bounds := get_target_bounds()
	return (
		texture != null
		and _is_static_texture(texture)
		and _is_region_inside_texture(source_region, Vector2(texture.get_size()))
		and source_region.size.x > 0.0
		and source_region.size.y > 0.0
		and source_region.position.is_finite()
		and source_region.size.is_finite()
		and (
			not filter_clip
			or (
				_is_region_inside_texture(sampling_clip_region, Vector2(texture.get_size()))
				and sampling_clip_region.position.is_finite()
				and sampling_clip_region.size.is_finite()
			)
		)
		and frame_to_target.x.is_finite()
		and frame_to_target.y.is_finite()
		and frame_to_target.origin.is_finite()
		and is_finite(transform_determinant)
		and not is_zero_approx(transform_determinant)
		and target_bounds.position.is_finite()
		and target_bounds.size.is_finite()
		and target_bounds.size.x > 0.0
		and target_bounds.size.y > 0.0
		and is_finite(modulate.r)
		and is_finite(modulate.g)
		and is_finite(modulate.b)
		and is_finite(modulate.a)
		and source_visual != null
		and is_instance_valid(source_visual)
		and source_visible
		and texture_filter >= CanvasItem.TEXTURE_FILTER_PARENT_NODE
		and texture_filter < CanvasItem.TEXTURE_FILTER_MAX
	)


## 边界始终由经过校验的纹理尺寸与变换实时推导，不能由调用方单独覆写成
## 与实际采样几何不一致的矩形。
func get_target_bounds() -> Rect2:
	return _get_transformed_bounds(frame_to_target, source_region.size)


## 为 AnimatedSprite2D 创建状态帧。animation_name 为空时捕获当前帧，
## 指定动画时捕获该动画的第一帧，且不会改变正在运行的 AnimatedSprite2D。
static func from_animated_sprite(
	sprite: AnimatedSprite2D, target_space: CanvasItem, animation_name: StringName = &""
) -> KonadoCharacterTransitionFrame:
	if sprite == null or target_space == null or sprite.sprite_frames == null:
		return null
	var selected_animation := animation_name if not animation_name.is_empty() else sprite.animation
	if not sprite.sprite_frames.has_animation(selected_animation):
		return null
	var frame_count := sprite.sprite_frames.get_frame_count(selected_animation)
	if frame_count <= 0:
		return null
	var frame_index := (
		0 if not animation_name.is_empty() else clampi(sprite.frame, 0, frame_count - 1)
	)
	var frame_texture := sprite.sprite_frames.get_frame_texture(selected_animation, frame_index)
	if frame_texture == null:
		return null
	return _from_texture_canvas_item(
		frame_texture,
		Rect2(Vector2.ZERO, Vector2(frame_texture.get_size())),
		sprite,
		target_space,
		sprite.centered,
		sprite.offset,
		sprite.flip_h,
		sprite.flip_v,
		false
	)


## 为 Sprite2D 创建状态帧。可传入目标纹理，在不修改实时节点的情况下准备下一状态。
static func from_sprite(
	sprite: Sprite2D, target_space: CanvasItem, target_texture: Texture2D = null
) -> KonadoCharacterTransitionFrame:
	if sprite == null or target_space == null:
		return null
	var frame_texture := target_texture if target_texture else sprite.texture
	if frame_texture == null:
		return null
	var texture_size := Vector2(frame_texture.get_size())
	# 与 Sprite2D::_get_rects 保持一致：先确定完整区域，再从区域中选取当前帧。
	# region_enabled 与 hframes/vframes 可以同时使用，不能作为互斥分支处理。
	var base_region := (
		sprite.region_rect if sprite.region_enabled else Rect2(Vector2.ZERO, texture_size)
	)
	var frame_size := base_region.size / Vector2(sprite.hframes, sprite.vframes)
	var source_region := Rect2(
		base_region.position + Vector2(sprite.frame_coords) * frame_size, frame_size
	)
	return _from_texture_canvas_item(
		frame_texture,
		source_region,
		sprite,
		target_space,
		sprite.centered,
		sprite.offset,
		sprite.flip_h,
		sprite.flip_v,
		(
			sprite.hframes > 1
			or sprite.vframes > 1
			or (sprite.region_enabled and sprite.region_filter_clip_enabled)
		)
	)


static func _from_texture_canvas_item(
	frame_texture: Texture2D,
	logical_region: Rect2,
	source: CanvasItem,
	target_space: CanvasItem,
	centered: bool,
	offset: Vector2,
	horizontal_flip: bool,
	vertical_flip: bool,
	logical_filter_clip: bool
) -> KonadoCharacterTransitionFrame:
	if frame_texture == null or source == null or target_space == null:
		return null
	if not _is_static_texture(frame_texture):
		return null
	# 交融期间会隐藏整个 target_space；帧来源必须属于该挂载层，
	# 否则实时节点仍会继续显示，造成双重画面和不可控的副作用。
	if source != target_space and not target_space.is_ancestor_of(source):
		return null
	# 单个覆盖矩形无法可靠复刻源节点或中间节点参与的独立 Z 排序、behind-parent
	# 与 Y-sort 语义。遇到这些场景应回退到隐藏/显示同一个稳定挂载层的安全淡变。
	if _has_unsupported_draw_order(source, target_space):
		return null
	# 自定义材质和中间裁切容器无法由单个纹理矩形等价还原。
	# 这些场景应走安全淡变，或由插件作者提供已经合成好的完整状态帧。
	if source.material != null or source.use_parent_material:
		return null
	# shader 使用 repeat_disable 采样。若源节点启用了平铺或镜像重复，纹理边缘
	# 的过滤结果会不同，必须降级而不是生成一个看似可用但不等价的状态帧。
	if _resolve_texture_repeat(source) != CanvasItem.TEXTURE_REPEAT_DISABLED:
		return null
	if _has_intermediate_clip(source, target_space):
		return null
	# Godot 会在渲染阶段逐层吸附 CanvasItem 的局部变换，而公开的全局变换仍是
	# 未吸附值。单个纹理矩形无法从公共 API 精确复刻该结果，必须使用安全淡变。
	var viewport := source.get_viewport()
	if viewport != null and viewport.is_snap_2d_transforms_to_pixel_enabled():
		return null
	var logical_texture_size := Vector2(frame_texture.get_size())
	if not _is_region_inside_texture(logical_region, logical_texture_size):
		return null

	# AtlasTexture 的区域偏移必须递归折算到最终纹理；带 margin、循环引用或越界裁切
	# 无法只靠一个矩形精确还原，宁可返回 null 走安全淡变，也不制造错误交融帧。
	var sampling_texture := frame_texture
	var sampling_region := logical_region
	var sampling_clip_region := logical_region
	var filter_clip := logical_filter_clip
	var visited_atlases := {}
	while sampling_texture is AtlasTexture:
		var atlas_texture := sampling_texture as AtlasTexture
		var atlas_id := atlas_texture.get_instance_id()
		if visited_atlases.has(atlas_id):
			return null
		visited_atlases[atlas_id] = true
		if atlas_texture.atlas == null or atlas_texture.margin != Rect2():
			return null
		# AtlasTexture 对外暴露的是向下取整后的逻辑尺寸，使用 get_size() 才能与
		# Godot 实际绘制和下一层 AtlasTexture 的坐标系一致。
		if not _is_region_inside_texture(sampling_region, Vector2(atlas_texture.get_size())):
			return null
		if filter_clip:
			sampling_clip_region.position += atlas_texture.region.position
		elif atlas_texture.filter_clip:
			sampling_clip_region = atlas_texture.region
			filter_clip = true
		sampling_region.position += atlas_texture.region.position
		sampling_texture = atlas_texture.atlas
		if not _is_static_texture(sampling_texture):
			return null
	if not _is_region_inside_texture(sampling_region, Vector2(sampling_texture.get_size())):
		return null

	var target_inverse := target_space.get_global_transform_with_canvas().affine_inverse()
	var source_to_target := target_inverse * source.get_global_transform_with_canvas()
	var draw_origin := offset - logical_region.size * 0.5 if centered else offset
	var result := KonadoCharacterTransitionFrame.new()
	result.texture = sampling_texture
	result.source_region = sampling_region
	result.sampling_clip_region = sampling_clip_region
	result.filter_clip = filter_clip
	result.frame_to_target = source_to_target * Transform2D(0.0, draw_origin)
	result.modulate = _get_relative_modulate(source, target_space)
	result.flip_h = horizontal_flip
	result.flip_v = vertical_flip
	result.texture_filter = _resolve_texture_filter(source, target_space)
	result.visibility_layer = source.visibility_layer
	result.light_mask = source.light_mask
	result.source_visual = source
	result.source_visible = source.is_visible_in_tree()
	return result


static func _has_unsupported_draw_order(source: CanvasItem, target_space: CanvasItem) -> bool:
	# target_space 自身的 Z 与 behind-parent 属性由覆盖层完整复制；其内部启用
	# Y-sort 时，子节点相对顺序依赖运行时位置，不能折叠成单个纹理矩形。
	if target_space.y_sort_enabled:
		return true
	var current := source
	while current != target_space:
		if (
			current.z_index != 0
			or not current.z_as_relative
			or current.show_behind_parent
			or current.y_sort_enabled
		):
			return true
		current = _get_canvas_parent(current)
		if current == null:
			return true
	return false


static func _get_canvas_parent(item: CanvasItem) -> CanvasItem:
	var parent := item.get_parent()
	while parent != null and not parent is CanvasItem:
		parent = parent.get_parent()
	return parent as CanvasItem


static func _get_transformed_bounds(transform: Transform2D, local_size: Vector2) -> Rect2:
	var points := [
		transform * Vector2.ZERO,
		transform * Vector2(local_size.x, 0.0),
		transform * Vector2(0.0, local_size.y),
		transform * local_size,
	]
	var minimum: Vector2 = points[0]
	var maximum: Vector2 = points[0]
	for point: Vector2 in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum)


static func _is_static_texture(candidate: Texture2D) -> bool:
	if candidate == null:
		return false
	# 状态帧 shader 只能等价采样标准的二维纹理 RID。MeshTexture 使用网格绘制且没有
	# 可采样 RID；DPITexture 会根据 CanvasItem oversampling 选择不同 RID；动态、占位、
	# 可绘制和渲染设备纹理在转场期间也可能变化。宁可安全淡变，不能把特殊纹理误判
	# 成已经冻结的旧状态快照。
	for unsupported_class: StringName in [
		&"AnimatedTexture",
		&"ViewportTexture",
		&"CameraTexture",
		&"ExternalTexture",
		&"MeshTexture",
		&"DPITexture",
		&"DrawableTexture2D",
		&"Texture2DRD",
		&"PlaceholderTexture2D",
		&"NoiseTexture2D",
	]:
		if candidate.is_class(unsupported_class):
			return false
	if candidate is CanvasTexture:
		return false
	return candidate.get_rid().is_valid()


static func _is_region_inside_texture(region: Rect2, texture_size: Vector2) -> bool:
	return (
		region.size.x > 0.0
		and region.size.y > 0.0
		and region.position.x >= 0.0
		and region.position.y >= 0.0
		and region.end.x <= texture_size.x
		and region.end.y <= texture_size.y
	)


static func _get_relative_modulate(source: CanvasItem, target_space: CanvasItem) -> Color:
	var result := Color.WHITE
	var current: Node = source
	while current != null and current != target_space:
		if current is CanvasItem:
			var canvas_item := current as CanvasItem
			result *= canvas_item.modulate
			if current == source:
				result *= canvas_item.self_modulate
		current = current.get_parent()
	return result


static func _has_intermediate_clip(source: CanvasItem, target_space: CanvasItem) -> bool:
	var current: Node = source
	while current != null:
		if current is CanvasGroup:
			return true
		if current is CanvasItem:
			var canvas_item := current as CanvasItem
			if canvas_item.clip_children != CanvasItem.CLIP_CHILDREN_DISABLED:
				return true
		if current != source and current is Control and (current as Control).clip_contents:
			return true
		if current == target_space:
			break
		current = current.get_parent()
	return false


static func _resolve_texture_filter(source: CanvasItem, target_space: CanvasItem) -> int:
	var current: Node = source
	while current != null:
		if current is CanvasItem:
			var canvas_item := current as CanvasItem
			if canvas_item.texture_filter != CanvasItem.TEXTURE_FILTER_PARENT_NODE:
				return canvas_item.texture_filter
		if current == target_space:
			break
		current = current.get_parent()
	return CanvasItem.TEXTURE_FILTER_PARENT_NODE


static func _resolve_texture_repeat(source: CanvasItem) -> int:
	var current: Node = source
	while current != null:
		if current is CanvasItem:
			var canvas_item := current as CanvasItem
			if canvas_item.texture_repeat != CanvasItem.TEXTURE_REPEAT_PARENT_NODE:
				return canvas_item.texture_repeat
		current = current.get_parent()
	return CanvasItem.TEXTURE_REPEAT_DISABLED
