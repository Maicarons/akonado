---
title: 场景化资源
order: 4
---

# 场景化资源

## 前言

Konado 的角色和背景资源已经转向场景形式。资源列表不再直接保存一张图片，而是保存一个 `PackedScene`。具体要显示图片、视频、Spine、Live2D、shader 或其他节点，都由这个场景自己决定。

这样做的目的，是让剧本命令只表达剧情意图：

```text
actor show kona normal at 2
background bg1 fade
```

而资源场景负责把 `normal`、`bg1`、`fade` 这些语义转换成真正的表现。

## 角色场景

角色场景建议继承 `KonadoCharacterSceneBase`。对话系统创建角色时，会把角色列表中的 `character_scene` 实例化，然后把剧本里的状态名传给角色场景。

### 基本结构

一个简单的角色场景可以这样组织：

```text
SampleCharacter (KonadoCharacterSceneBase)
├─ AnimatedSprite2D
└─ AnimationPlayer
```

也可以换成其他表现：

```text
Live2DCharacter (KonadoCharacterSceneBase)
└─ Live2D 节点

SpineCharacter (KonadoCharacterSceneBase)
└─ Spine 节点

VideoCharacter (KonadoCharacterSceneBase)
└─ VideoStreamPlayer
```

### 状态切换

剧本中的第二个参数是角色状态：

```text
actor show kona normal at 2
actor change kona happy
```

系统会调用角色场景的 `apply_status(status_name)`。用户场景通常覆写 `_apply_status`：

```gdscript
extends KonadoCharacterSceneBase

@export var animated_sprite_path: NodePath = ^"AnimatedSprite2D"

var sprite: AnimatedSprite2D

func _ready() -> void:
	sprite = get_node_or_null(animated_sprite_path) as AnimatedSprite2D

func _apply_status(resolved_status_name: String, original_status_name: String) -> void:
	sprite.play(resolved_status_name)

func _has_status(resolved_status_name: String, original_status_name: String) -> bool:
	if sprite == null or sprite.sprite_frames == null:
		push_warning("角色场景缺少 AnimatedSprite2D 或 SpriteFrames")
		return false
	if sprite.sprite_frames.has_animation(resolved_status_name):
		return true
	push_warning("角色场景未找到状态：" + original_status_name)
	return false

func _get_status_transition_frame(
	resolved_status_name: String,
	_original_status_name: String,
	target_space: CanvasItem,
) -> RefCounted:
	return KonadoCharacterTransitionFrame.from_animated_sprite(
		sprite, target_space, StringName(resolved_status_name)
	)

func _get_current_status_transition_frame(
	target_space: CanvasItem,
) -> RefCounted:
	return KonadoCharacterTransitionFrame.from_animated_sprite(sprite, target_space)
```

对于 Live2D、Spine、视频角色，只需要把 `_apply_status` 内部换成对应的播放逻辑。例如设置 Live2D 表情、播放 Spine 动画、切换视频流。

`_has_status` 只用于查询状态是否存在，必须保持无副作用且结果幂等；延迟转场可能在接收请求和最终提交时分别调用它。`_get_current_status_transition_frame` 和 `_get_status_transition_frame` 是可选的无副作用状态帧协议。前者捕获当前实际显示帧，后者准备目标状态帧；两次调用必须各自返回新建的独立帧，不能复用并改写同一个对象。能安全提供两者的角色会获得真正的像素交融；无法安全提供状态帧的 Live2D、Spine、视频和自定义场景无需实现，系统会自动使用“淡出—应用状态—淡入”。两条路径都不会复制角色场景。具体配置请参阅[演员切换状态](../script/actor/actor-change-state.md)。

### 状态别名

角色场景有 `status_aliases`，用于把剧本里的语义名映射到资源里的实际名字。

例如剧本写：

```text
actor show kona angry at 2
```

但资源里的动画叫 `face_anger_01`，就可以在 `status_aliases` 中配置：

| status_name | resolved_status_name |
|-------------|----------------------|
| `angry` | `face_anger_01` |

这样剧本保持可读，资源内部命名也不用被剧本强行约束。

### 角色动作和舞台动作

角色内部动作和舞台动作是两件事。

角色内部动作由角色场景负责，适合眨眼、挥手、切 Live2D motion、播放 Spine 短动画：

```gdscript
func _play_action(action_name: String) -> void:
	# 播放角色内部动作
	finish_action(action_name)
```

舞台动作由 `KonadoActorMotionLayer` 负责，适合震动、跳跃、弹一下、左右晃动。动作层使用 `AnimationPlayer` 中的同名动画：

```text
actor motion kona shake
actor motion kona jump_twice
```

制作动作层时，建议让动画作用在 `CharacterMount` 上，不要直接改角色槽位本身。这样不会破坏角色的站位计算。

## 背景场景

背景场景建议继承 `KonadoBackgroundSceneBase`。背景列表中的每个背景资源需要配置：

| 字段 | 说明 |
|------|------|
| `background_name` | 剧本中使用的背景名称 |
| `background_scene` | 要实例化的背景场景 |

剧本命令：

```text
background bg1 none
background bg1 fade
```

系统会根据 `background_name` 找到对应的 `background_scene`，实例化后挂到背景层。

需要镜头命令时，可以在背景场景中添加名称唯一的 `KonadoCameraMarker`。它只保存目标机位的位置和缩放，不负责渲染画面；实际渲染由对话模板中的相机完成。因此不要把普通背景相机替换为 `KonadoCameraMarker`。

### 基本结构

一个图片背景可以这样组织：

```text
Background (KonadoBackgroundSceneBase)
├─ TextureRect
└─ AnimationPlayer
```

`TextureRect` 建议铺满父节点：

| 属性 | 建议 |
|------|------|
| Anchors | Full Rect |
| Expand Mode | Ignore Size |
| Stretch Mode | Keep Aspect Covered |

视频、Spine、Live2D 或 shader 背景，也可以放在同一个场景中：

```text
Background (KonadoBackgroundSceneBase)
├─ VideoStreamPlayer
├─ ColorRect(ShaderLayer)
└─ AnimationPlayer
```

### 入场和退场动画

背景场景可以通过 `AnimationPlayer` 响应切换效果。命名规则是：

| 动画名 | 触发时机 |
|--------|----------|
| `enter` | 新背景进入，任意效果都可兜底 |
| `exit` | 旧背景退出，任意效果都可兜底 |
| `enter_fade` | 新背景以 `fade` 效果进入 |
| `exit_fade` | 旧背景以 `fade` 效果退出 |
| `enter_custom` | 新背景以 `custom` 效果进入 |
| `exit_custom` | 旧背景以 `custom` 效果退出 |

例如：

```text
background bg1 custom
```

如果背景场景中存在 `enter_custom` 或 `exit_custom`，系统会优先播放这些动画。没有对应动画时，如果效果不是 `none`，基类会用默认淡入淡出兜底，避免剧情卡住。

### 内置 shader 转场

Konado 的内置背景转场 shader 由 `KonadoBackgroundTransitionLayer` 统一处理，不需要每个背景场景自己挂旧版转场 shader。

目前内置效果包括：

| 效果 | 说明 |
|------|------|
| `none` | 立即切换，不走 shader |
| `fade` | 淡入淡出 |
| `erase` | 擦除 |
| `blinds` | 百叶窗 |
| `wave` | 波浪 |
| `vortex` | 旋涡 |
| `windmill` | 风车 |
| `cyberglitch` | 赛博故障 |
| `blink` | 眨眼 |

背景转场默认使用 `SubViewport` 捕获完整场景，确保布局、裁剪、染色、材质、相机、动画以及运行时创建的视觉节点都能正确进入转场画面。

`DIRECT_TEXTURE` 是可选的性能优化，只适用于最终画面与一张原始纹理完全等价的静态背景。使用布局裁剪、节点变换、多个可绘制节点、相机、动画、材质或染色的背景必须保持默认的 `VIEWPORT_CAPTURE`。

确认满足约束后，可以在 Inspector 中将 `transition_render_mode` 改为 `DIRECT_TEXTURE`。系统会递归寻找第一个 `TextureRect` 或 `Sprite2D`；如需手动指定纹理，可以覆写：

```gdscript
func get_transition_texture() -> Texture2D:
	return my_texture
```

### 背景自身 shader

如果 shader 是背景自己的表现，例如水波、扫描线、色差、噪声、呼吸光，不属于“旧背景到新背景”的双纹理转场，可以直接挂在背景场景里的 `TextureRect` 或 `ColorRect` 上。

这类 shader 建议由背景场景自己的 `AnimationPlayer` 控制参数：

```text
ShaderLayer:material:shader_parameter/intensity
ShaderLayer:material:shader_parameter/progress
```

## 资源表配置流程

### 配置角色

1. 创建一个继承 `KonadoCharacterSceneBase` 的角色场景。
2. 在角色场景里实现 `_apply_status`。
3. 打开角色列表资源。
4. 给角色配置 `character_scene`。
5. 如需舞台动作，配置 `actor_motion_layer`。

### 配置背景

1. 创建一个继承 `KonadoBackgroundSceneBase` 的背景场景。
2. 在背景场景里放入图片、视频、Spine、Live2D 或 shader 节点。
3. 如需自定义入场/退场动画，添加 `AnimationPlayer` 并制作 `enter_xxx`、`exit_xxx` 动画。
4. 打开背景列表资源。
5. 给背景配置 `background_name` 和 `background_scene`。

## 注意事项

- 角色状态由角色场景决定，系统只负责传入状态名。
- 背景切换由背景场景和转场层决定，系统只负责实例化场景并传入效果名。
- 旧版图片字段已经不再作为主要配置方式，资源表应配置场景。
- 图片背景建议使用 `TextureRect`；仅在启用 `DIRECT_TEXTURE` 时，转场层才会直接读取其纹理。
- 视频、Spine、Live2D 等动态背景需要注意自身播放状态，必要时在 `setup_background` 中初始化。
- `none` 是立即切换，不会播放内置 shader；如果想做自定义无 shader 动画，可以使用自己的效果名，例如 `custom`。
