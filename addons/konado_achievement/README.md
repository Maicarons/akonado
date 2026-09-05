# Konado成就系统框架插件

基于 JSON 配置，完全与对话逻辑解耦，包含弹出通知。


### 配置成就

编辑 `addons/konado_achievement/data/default_achievements.json`：

```json
{
  "achievements": [
	{
	  "id": "first_blood",
	  "name": "首次击杀",
	  "description": "击败你的第一个敌人。",
	  "icon": "",
	  "hidden": false,
	  "category": "combat",
	  "points": 10,
	  "conditions": {
		"type": "counter",
		"target_key": "enemies_defeated",
		"target_value": 1
	  }
	}
  ]
}
```

**字段说明：**

| 字段 | 类型 | 描述 |
|------|------|------|
| `id` | String | 唯一标识符 |
| `name` | String | 显示名称 |
| `description` | String | 描述文本 |
| `icon` | String | 图标纹理路径（空 = 默认星星） |
| `hidden` | bool | 如果为 true，解锁前名称/描述会隐藏 |
| `category` | String | 分组标签（用于筛选） |
| `points` | int | 点数价值 |
| `conditions.type` | String | `"counter"` 或 `"flag"` |
| `conditions.target_key` | String | 要跟踪的进度键 |
| `conditions.target_value` | Variant | 解锁需要达到的值 |

### 触发成就

```gdscript
# 直接解锁
KonadoAchievements.unlock_achievement("first_blood")

# 基于计数器（自动检查条件）
KonadoAchievements.increment_progress("enemies_defeated", 1)

# 基于标志（自动检查条件）
KonadoAchievements.set_flag("secret_ending_found", true)
```

## API 参考

### 信号

```gdscript
signal achievement_unlocked(achievement_id: String, data: Dictionary)
signal achievement_progress_updated(achievement_id: String, current: float, target: float)
signal achievement_reset(achievement_id: String)
signal achievements_reset()
signal achievements_loaded()
```

### 核心方法

| 方法 | 返回值 | 描述 |
|------|--------|------|
| `unlock_achievement(id)` | `bool` | 直接解锁。如果是新解锁则返回 true。 |
| `increment_progress(key, amount)` | `void` | 增加计数器，自动检查成就。 |
| `set_flag(key, value)` | `void` | 设置标志，自动检查成就。 |
| `is_unlocked(id)` | `bool` | 检查成就是否已解锁。 |
| `get_achievement(id)` | `Dictionary` | 获取成就数据。 |
| `get_all_achievements()` | `Array` | 所有成就（包含 `unlocked` 字段）。 |
| `get_unlocked_achievements()` | `Array` | 仅已解锁的成就。 |
| `get_locked_achievements()` | `Array` | 仅未解锁的成就。 |
| `get_progress(key)` | `float` | 当前计数器值。 |
| `get_unlock_percentage()` | `float` | 0.0 – 1.0 的完成比率。 |
| `reset_all()` | `void` | 清除所有进度和解锁状态。 |
| `reset_achievement(id)` | `void` | 重置单个成就。 |
| `reload_config()` | `void` | 运行时重新加载 JSON 配置。 |

### UI 方法

| 方法 | 描述 |
|------|------|
| `show_panel()` | 打开成就概览面板。 |
| `hide_panel()` | 关闭面板。 |
| `toggle_panel()` | 切换面板可见性。 |
| `is_panel_visible()` | 检查面板是否打开。 |

### 配置属性

```gdscript
KonadoAchievements.config_path = "res://my_data/achievements.json"
KonadoAchievements.save_path = "user://my_save.json"
KonadoAchievements.popup_duration = 4.0
KonadoAchievements.popup_position = "top_right"  # top_left, top_right, bottom_left, bottom_right
KonadoAchievements.panel_layer = 100
KonadoAchievements.popup_layer = 110
```

## 外部集成

### 自定义保存/加载后端

```gdscript
# 提供服务器端持久化的自定义处理程序
KonadoAchievements.custom_save_handler = func(data: Dictionary):
	MyServerAPI.save_achievements(data)

KonadoAchievements.custom_load_handler = func() -> Dictionary:
	return MyServerAPI.load_achievements()
```

### 平台 SDK 同步（Steam 等）

```gdscript
# 挂钩到解锁事件以与外部平台同步
KonadoAchievements.on_external_unlock = func(id: String, data: Dictionary):
	SteamworksAPI.set_achievement(id)
	SteamworksAPI.store_stats()
```

### 监听事件

```gdscript
KonadoAchievements.achievement_unlocked.connect(func(id, data):
	print("玩家解锁：", data["name"])
)
```
