---
title: 成就系统
order: 2
---

# 成就系统 KonadoAchievement

## 前言

KonadoAchievement 是一款轻量、数据驱动的成就系统插件，为 Konado 设计，提供解锁、进度跟踪、弹窗通知、成就面板等完整功能。支持与 Konado 联动使用，也可独立运行。


### 配置文件

成就系统使用 JSON 配置文件定义成就，默认路径为 `res://addons/konado_achievement/data/default_achievements.json`，可以在 `KonadoAchievements` 中配置其他路径。



配置文件结构示例：

```json
{
  "achievements": [
    {
      "id": "first_blood",
      "name": "初遇篇章",
      "description": "解锁第一条主线剧情分支。",
      "icon": "",
      "hidden": false,
      "category": "story",
      "points": 10,
      "conditions": {
        "type": "counter",
        "target_key": "story_branch_unlocked",
        "target_value": 1
      }
    }
  ]
}
```

### 配置选项（可选）

在 `KonadoAchievements` 中，您可以通过以下属性进行配置：

- `config_path`: 成就配置文件路径
- `save_path`: 成就进度保存路径
- `popup_duration`: 成就解锁弹出通知的显示时长
- `popup_position`: 弹出通知的位置（top_left, top_right, bottom_left, bottom_right）
- `panel_layer`: 成就面板的 CanvasLayer 层级，默认为 `100`
- `popup_layer`: 成就解锁通知的 CanvasLayer 层级，默认为 `110`

## 核心功能

### 成就解锁

成就系统支持两种解锁方式：

1. **直接解锁**：通过 API 直接解锁成就
2. **条件解锁**：当满足特定条件时自动解锁成就

### 进度跟踪

系统支持两种类型的进度跟踪：

1. **计数器**：累计数值达到目标值时解锁
2. **标志**：当标志被设置为特定值时解锁

### 通知系统

当成就解锁时，系统会显示一个弹出通知，包含成就名称、描述和图标。

### 成就面板

提供一个可显示所有成就的面板，包括已解锁和未解锁的成就，以及解锁进度。


## 成就配置详解

### 成就属性

每个成就可以包含以下属性：

- `id`: 成就唯一标识符
- `name`: 成就名称
- `description`: 成就描述
- `icon`: 成就图标路径（可选）
- `hidden`: 是否隐藏（未解锁时不显示名称和描述）
- `category`: 成就分类（可选）
- `points`: 成就点数（可选）
- `conditions`: 解锁条件

### 条件类型

#### 计数器类型

```json
{
  "type": "counter",
  "target_key": "counter_key",
  "target_value": 10
}
```

当 `counter_key` 的值达到或超过 `target_value` 时解锁。

#### 标志类型

```json
{
  "type": "flag",
  "target_key": "flag_key",
  "target_value": true
}
```

当 `flag_key` 的值等于 `target_value` 时解锁。

## 使用示例

### 基本使用

```gdscript
# 增加计数器值
KonadoAchievements.increment_progress("story_branch_unlocked", 1)

# 设置标志
KonadoAchievements.set_flag("secret_ending_unlocked", true)

# 直接解锁成就
KonadoAchievements.unlock_achievement("special_achievement")

# 显示成就面板
KonadoAchievements.show_panel()
```

### 信号监听

```gdscript
# 监听成就解锁事件
KonadoAchievements.achievement_unlocked.connect(_on_achievement_unlocked)

func _on_achievement_unlocked(achievement_id: String, data: Dictionary) -> void:
    print("成就解锁: " + data.get("name"))
    # 可以在这里添加额外的奖励逻辑
```

### 自定义保存/加载

```gdscript
# 设置自定义保存处理
KonadoAchievements.custom_save_handler = Callable(self, "_custom_save")
KonadoAchievements.custom_load_handler = Callable(self, "_custom_load")

func _custom_save(data: Dictionary) -> void:
    # 自定义保存逻辑
    pass

func _custom_load() -> Dictionary:
    # 自定义加载逻辑
    return {"unlocked": {}, "progress": {}}
```

### 外部集成

```gdscript
# 设置外部解锁回调
KonadoAchievements.on_external_unlock = Callable(self, "_on_external_unlock")

func _on_external_unlock(achievement_id: String, data: Dictionary) -> void:
    # 同步到外部后端
    pass
```
