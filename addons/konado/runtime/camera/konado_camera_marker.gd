@tool
extends Camera2D
class_name KonadoCameraMarker

## 供 Konado 镜头命令读取位置和缩放的机位标记。
## 实际画面由 KonadoCameraController.active_camera 指向的 Camera2D 渲染；
## 机位标记进入场景树时会自动禁用，
## 避免在主视口或转场 SubViewport 中抢占活动相机。

## 机位唯一名称。
@export var marker_id: String = "cam1"


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	enabled = false
