@tool
class_name KND_SettingItem
extends Resource

## 设置类型枚举
## SLIDER: 滑块类型，用于数值调节
## TOGGLE: 开关类型，用于布尔值
## OPTION: 选项类型，用于下拉选择
enum Type {
	SLIDER,  # 滑块
	TOGGLE,  # 开关
	OPTION   # 选项
	}

## 设置项的唯一标识符
@export var key: String = ""

## 设置项的显示标签
@export var label: String = ""

## 设置项的类型
@export var type: Type = Type.SLIDER

## 滑块专用属性
@export var min_value: float = 0.0  # 最小值
@export var max_value: float = 1.0  # 最大值
@export var step: float = 0.01      # 步长

## 选项（下拉）专用属性 - 每个条目是一个可选择的字符串
@export var options: Array[String] = []

## 平台过滤 - 空数组表示在所有平台可见
@export var platforms: Array[String] = []

## 提示文本 - 鼠标悬浮时显示的说明
@export var tooltip: String = ""

## 默认值 - SLIDER使用float，TOGGLE使用bool，OPTION使用String
@export var default_value: Variant
