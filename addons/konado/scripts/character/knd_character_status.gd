extends KND_Data
class_name KND_CharacterStatus

# 状态名称
@export var status_name: String
# 状态角色场景，优先于图片。可用于视频、Spine、Live2D 或其他自定义角色表现。
@export var status_scene: PackedScene
# 状态角色图片
@export var status_texture: CompressedTexture2D
