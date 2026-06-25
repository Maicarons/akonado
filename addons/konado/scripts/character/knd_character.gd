extends KND_Data
class_name KND_Character

## 角色姓名
@export var chara_name: String

## 角色场景，由场景内部决定表情、动画和表现形式
@export var character_scene: PackedScene

## 可选的演员动作层场景，用于配置震动、跳跃等舞台层动作。
## 不配置时使用默认动作层；特殊角色可以指定自己的 MotionLayer 和 AnimationPlayer。
@export var actor_motion_layer: PackedScene
