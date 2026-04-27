## 设置分类类 - 将相关的设置项分组在一起
@tool
class_name KND_SettingCategory
extends Resource

## 分类的唯一标识符
@export var id: String = ""

## 分类的显示名称
@export var display_name: String = ""

## 分类包含的设置项数组
@export var items: Array[KND_SettingItem] = []
