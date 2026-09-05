---
title: Achievement System
order: 2
---

# Achievement System KonadoAchievement

## Preface

KonadoAchievement is a lightweight, data-driven achievement system plugin designed for Konado. It provides complete functionality including unlocking, progress tracking, popup notifications, and an achievement panel. It can be used together with Konado or run independently.

### Configuration File

The achievement system uses a JSON configuration file to define achievements. The default path is `res://addons/konado_achievement/data/default_achievements.json`, and another path can be configured in `KonadoAchievements`.

Example configuration file structure:

```json
{
  "achievements": [
    {
      "id": "first_blood",
      "name": "First Encounter Chapter",
      "description": "Unlock the first main story branch.",
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

### Configuration Options (Optional)

In `KonadoAchievements`, you can configure the following properties:

- `config_path`: Path to the achievement configuration file
- `save_path`: Path for saving achievement progress
- `popup_duration`: Display duration of the achievement unlock popup notification
- `popup_position`: Popup notification position (top_left, top_right, bottom_left, bottom_right)
- `panel_layer`: CanvasLayer index for the achievement panel; defaults to `100`
- `popup_layer`: CanvasLayer index for unlock notifications; defaults to `110`

## Core Features

### Achievement Unlocking

The achievement system supports two unlocking methods:

1. **Direct unlock**: Unlock achievements directly through the API
2. **Conditional unlock**: Automatically unlock achievements when specific conditions are met

### Progress Tracking

The system supports two types of progress tracking:

1. **Counter**: Unlock when an accumulated value reaches the target value
2. **Flag**: Unlock when a flag is set to a specific value

### Notification System

When an achievement is unlocked, the system displays a popup notification containing the achievement name, description, and icon.

### Achievement Panel

Provides a panel that can display all achievements, including unlocked and locked achievements, as well as unlock progress.

## Achievement Configuration Details

### Achievement Properties

Each achievement can contain the following properties:

- `id`: Unique achievement identifier
- `name`: Achievement name
- `description`: Achievement description
- `icon`: Achievement icon path (optional)
- `hidden`: Whether to hide it (when locked, the name and description are not shown)
- `category`: Achievement category (optional)
- `points`: Achievement points (optional)
- `conditions`: Unlock conditions

### Condition Types

#### Counter Type

```json
{
  "type": "counter",
  "target_key": "counter_key",
  "target_value": 10
}
```

Unlocked when the value of `counter_key` reaches or exceeds `target_value`.

#### Flag Type

```json
{
  "type": "flag",
  "target_key": "flag_key",
  "target_value": true
}
```

Unlocked when the value of `flag_key` equals `target_value`.

## Usage Examples

### Basic Usage

```gdscript
# Increase counter value
KonadoAchievements.increment_progress("story_branch_unlocked", 1)

# Set flag
KonadoAchievements.set_flag("secret_ending_unlocked", true)

# Directly unlock achievement
KonadoAchievements.unlock_achievement("special_achievement")

# Show achievement panel
KonadoAchievements.show_panel()
```

### Signal Listening

```gdscript
# Listen for achievement unlock events
KonadoAchievements.achievement_unlocked.connect(_on_achievement_unlocked)

func _on_achievement_unlocked(achievement_id: String, data: Dictionary) -> void:
    print("Achievement unlocked: " + data.get("name"))
    # Additional reward logic can be added here
```

### Custom Save/Load

```gdscript
# Set custom save handler
KonadoAchievements.custom_save_handler = Callable(self, "_custom_save")
KonadoAchievements.custom_load_handler = Callable(self, "_custom_load")

func _custom_save(data: Dictionary) -> void:
    # Custom save logic
    pass

func _custom_load() -> Dictionary:
    # Custom load logic
    return {"unlocked": {}, "progress": {}}
```

### External Integration

```gdscript
# Set external unlock callback
KonadoAchievements.on_external_unlock = Callable(self, "_on_external_unlock")

func _on_external_unlock(achievement_id: String, data: Dictionary) -> void:
    # Sync to external backend
    pass
```
