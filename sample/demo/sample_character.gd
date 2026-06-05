extends Node2D

const STATUS_ALIASES := {
	"正常": "default",
	"介绍正常": "介绍",
}

var sprite: AnimatedSprite2D

func _ready() -> void:
	sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

func apply_status(status_name: String) -> void:
	var sprite_node := _get_sprite()
	if sprite_node == null or sprite_node.sprite_frames == null:
		push_warning("角色场景缺少 AnimatedSprite2D 或 SpriteFrames")
		return

	var animation_key: String = STATUS_ALIASES.get(status_name, status_name)
	var animation_name := StringName(animation_key)
	if sprite_node.sprite_frames.has_animation(animation_name):
		sprite_node.play(animation_name)
		return

	push_warning("角色场景未找到动画：" + status_name)

func set_highlight(highlight: bool) -> void:
	if highlight:
		modulate = Color(1.0, 1.0, 1.0, modulate.a)
	else:
		modulate = Color(0.35, 0.35, 0.35, modulate.a)

func _get_sprite() -> AnimatedSprite2D:
	if sprite == null:
		sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	return sprite
