extends KonadoCharacterSceneBase

## Akonado-generated character scene.
## Uses a TextureRect to display expression sprites based on status name.

@export var texture_rect: TextureRect

## Maps status_name -> texture path (relative to this scene's directory)
@export var expression_textures: Dictionary = {}

var _cached_textures: Dictionary = {}


func _ready() -> void:
	if texture_rect == null:
		texture_rect = get_node_or_null("TextureRect") as TextureRect


func _apply_status(resolved_status_name: String, original_status_name: String) -> void:
	if texture_rect == null:
		return
	var tex := _get_texture(resolved_status_name)
	if tex:
		texture_rect.texture = tex
		texture_rect.visible = true


func _has_status(resolved_status_name: String, original_status_name: String) -> bool:
	if resolved_status_name.is_empty():
		return false
	return resolved_status_name in expression_textures


func _get_texture(status_name: String) -> Texture2D:
	if status_name in _cached_textures:
		return _cached_textures[status_name]
	var path := expression_textures.get(status_name, "")
	if path.is_empty():
		return null
	var tex := load(path) as Texture2D
	if tex:
		_cached_textures[status_name] = tex
	return tex