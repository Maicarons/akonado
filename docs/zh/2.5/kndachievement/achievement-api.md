---
title: 使用API
order: 3
---

# KND_AchievementManager API 参考

## 信号

成就系统提供以下信号，可用于监听成就相关事件并执行自定义逻辑：

### achievement_unlocked

**信号签名：** `achievement_unlocked(achievement_id: String, data: Dictionary)`

**触发时机：** 当任何成就被解锁时触发

**参数说明：**
- `achievement_id`: 被解锁的成就ID
- `data`: 成就的完整数据字典，包含名称、描述、图标等信息

**使用场景：** 用于在成就解锁时执行奖励逻辑、播放庆祝动画、显示自定义通知等

**示例代码：**
```gdscript
# 连接信号
KND_AchievementManager.achievement_unlocked.connect(_on_achievement_unlocked)

# 信号处理函数
func _on_achievement_unlocked(achievement_id: String, data: Dictionary) -> void:
    print("成就解锁: " + data.get("name"))
    # 播放成就解锁音效
    # 显示自定义庆祝动画
    # 给予玩家奖励
```

### achievement_progress_updated

**信号签名：** `achievement_progress_updated(achievement_id: String, current: float, target: float)`

**触发时机：** 当成就的进度值更新时触发

**参数说明：**
- `achievement_id`: 进度更新的成就ID
- `current`: 当前进度值
- `target`: 目标进度值

**使用场景：** 用于显示成就进度条、提供进度反馈、更新UI显示等

**示例代码：**
```gdscript
# 连接信号
KND_AchievementManager.achievement_progress_updated.connect(_on_progress_updated)

# 信号处理函数
func _on_progress_updated(achievement_id: String, current: float, target: float) -> void:
    var progress_percentage = (current / target) * 100
    print("成就进度更新: " + achievement_id + " - " + str(progress_percentage) + "%")
    # 更新UI进度条
    # 显示进度提示
```

### achievements_reset

**信号签名：** `achievements_reset()`

**触发时机：** 当所有成就被重置时触发

**参数说明：** 无参数

**使用场景：** 用于在成就重置后更新UI、显示重置通知、执行清理操作等

**示例代码：**
```gdscript
# 连接信号
KND_AchievementManager.achievements_reset.connect(_on_achievements_reset)

# 信号处理函数
func _on_achievements_reset() -> void:
    print("所有成就已重置")
    # 更新成就面板
    # 显示重置通知
```

### achievements_loaded

**信号签名：** `achievements_loaded()`

**触发时机：** 当成就系统完成加载时触发

**参数说明：** 无参数

**使用场景：** 用于在成就加载完成后初始化UI、执行依赖于成就数据的逻辑等

**示例代码：**
```gdscript
# 连接信号
KND_AchievementManager.achievements_loaded.connect(_on_achievements_loaded)

# 信号处理函数
func _on_achievements_loaded() -> void:
    print("成就数据加载完成")
    # 初始化成就面板
    # 执行依赖于成就数据的逻辑
```


## 核心方法

### 解锁成就

```gdscript
# 通过 ID 直接解锁成就
KND_AchievementManager.unlock_achievement("achievement_id")
```

### 进度管理

```gdscript
# 增加计数器值
KND_AchievementManager.increment_progress("counter_key", 1.0)

# 设置标志值
KND_AchievementManager.set_flag("flag_key", true)
```

### 成就查询

```gdscript
# 检查成就是否已解锁
KND_AchievementManager.is_unlocked("achievement_id")

# 获取单个成就数据
KND_AchievementManager.get_achievement("achievement_id")

# 获取所有成就
KND_AchievementManager.get_all_achievements()

# 获取已解锁成就
KND_AchievementManager.get_unlocked_achievements()

# 获取未解锁成就
KND_AchievementManager.get_locked_achievements()

# 获取解锁百分比
KND_AchievementManager.get_unlock_percentage()
```

### 面板管理

```gdscript
# 显示成就面板
KND_AchievementManager.show_panel()

# 隐藏成就面板
KND_AchievementManager.hide_panel()

# 切换成就面板显示状态
KND_AchievementManager.toggle_panel()

# 检查面板是否可见
KND_AchievementManager.is_panel_visible()
```

#### 重置功能
```gdscript
# 重置所有成就
KND_AchievementManager.reset_all()

# 重置单个成就
KND_AchievementManager.reset_achievement("achievement_id")
```
