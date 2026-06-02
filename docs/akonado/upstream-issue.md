# Issue: 角色在位置 0 时身体出屏 + 模板场景缺少 `_autoPlayButton`

## Bug 1: 角色精灵在位置 0 时超出屏幕

### 描述

角色显示在位置 0（最左侧）时，约一半的身体被屏幕左边缘截断。位置 4（最右侧）存在同样的问题，右侧身体被截断。

### 根因分析

`konado_actor.gd` 的 `_on_resized()` 通过移动 Slot 的 `position.x` 来定位角色，但 Slot 的尺寸从未被修改——它始终填满整个视口（1920px 宽，锚点 0→1）。由于 TextureRect 也填满 Slot，角色精灵无论在哪个位置都会被缩放到 1920px 宽。

原始公式：

```gdscript
slot.position.x = -size.x / h_division * (h_division - h_character_position) + slot.size.x/2
```

以 1920px 视口、`h_division = 5` 为例：

| 位置 | slot.position.x | 精灵显示范围 | 出屏情况 |
|------|-----------------|-------------|---------|
| 0 | -768 | -768 ~ 1152 | 左侧 768px 被截断 |
| 1 | -384 | -384 ~ 1536 | 左侧 384px 被截断 |
| 2 | 0 | 0 ~ 1920 | 完全可见 |
| 3 | 384 | 384 ~ 2304 | 右侧 384px 被截断 |
| 4 | 768 | 768 ~ 2688 | 右侧 768px 被截断 |

### 修复方案

根据纹理宽高比计算精灵实际渲染宽度，定位时确保精灵不超出视口边界：

```gdscript
func _on_resized() -> void:
    if not texture_rect:
        print("警告：texture_rect未赋值")
        return

    var division_size: float = size.x / h_division
    var division_center: float = (h_character_position + 0.5) * division_size
    # 根据纹理宽高比计算精灵渲染宽度
    # expand_mode=3 + stretch_mode=5: 精灵缩放到视口高度，保持宽高比
    var sprite_w: float = size.x  # 回退值：满视口宽度
    if texture_rect.texture:
        var tex_size: Vector2 = texture_rect.texture.get_size()
        if tex_size.y > 0:
            sprite_w = tex_size.x * (size.y / tex_size.y)
    # 偏移使精灵中心 = 区块中心，同时确保精灵不超出视口
    var target_x: float = division_center - sprite_w / 2.0
    target_x = clampf(target_x, 0.0, size.x - sprite_w)

    if use_tween:
        var tween: Tween = slot.create_tween()
        tween.set_parallel(true)
        tween.tween_property(slot, "position:x", target_x, animation_time)
        await tween.finished
        actor_moved.emit()
    else:
        slot.position.x = target_x
        actor_moved.emit()
```

修复后（视口 1920x1080，`h_division = 5`，768x1024 精灵，`sprite_w = 810`）：

| 位置 | 区块中心 | 目标 x（clamp 前） | 目标 x（clamp 后） | 精灵范围 | 可见性 |
|------|---------|------------------|------------------|---------|-------|
| 0 | 192 | -213 | **0** | 0 ~ 810 | 完全可见 |
| 1 | 576 | 171 | 171 | 171 ~ 981 | 完全可见 |
| 2 | 960 | 555 | 555 | 555 ~ 1365 | 完全可见 |
| 3 | 1344 | 939 | 939 | 939 ~ 1749 | 完全可见 |
| 4 | 1728 | 1323 | **1110** | 1110 ~ 1920 | 完全可见 |

关键改进：
1. 从纹理实际宽高比计算精灵渲染宽度，而非假设精灵填满视口
2. 使用 `clampf` 确保精灵左右边缘不超出视口
3. 不修改 Slot 尺寸，不影响 TextureRect 布局

### 涉及文件

- `addons/konado/template/character/konado_actor.gd` — `_on_resized()` 函数

### 完整 diff

```diff
 func _on_resized() -> void:
 	if not texture_rect:
 		print("警告：texture_rect未赋值")
 		return
-	
+
+	var division_size: float = size.x / h_division
+	var division_center: float = (h_character_position + 0.5) * division_size
+	# 根据纹理宽高比计算精灵渲染宽度
+	# expand_mode=3 + stretch_mode=5: 精灵缩放到视口高度，保持宽高比
+	var sprite_w: float = size.x  # 回退值：满视口宽度
+	if texture_rect.texture:
+		var tex_size: Vector2 = texture_rect.texture.get_size()
+		if tex_size.y > 0:
+			sprite_w = tex_size.x * (size.y / tex_size.y)
+	# 偏移使精灵中心 = 区块中心，同时确保精灵不超出视口
+	var target_x: float = division_center - sprite_w / 2.0
+	target_x = clampf(target_x, 0.0, size.x - sprite_w)
+
 	if use_tween:
 		var tween: Tween = slot.create_tween()
 		tween.set_parallel(true)
-		tween.tween_property(slot, "position:x", -size.x / h_division * (h_division - h_character_position ) + slot.size.x/2, animation_time)
+		tween.tween_property(slot, "position:x", target_x, animation_time)
 		await tween.finished
 		actor_moved.emit()
 	else:
-		slot.position.x = -size.x / h_division * (h_division - h_character_position ) + slot.size.x/2
-	
+		slot.position.x = target_x
 		actor_moved.emit()
```

---

## Bug 2: 模板场景缺少 `_autoPlayButton` 绑定

### 描述

`knd_dialogue_manager.gd` 导出了 `_autoPlayButton`（第 76 行），并在 `_ready()` 中检查它（第 204-207 行）：

```gdscript
@export var _autoPlayButton: Button  # 第 76 行

func _ready():
    if _autoPlayButton:                # 第 204 行
        _autoPlayButton.toggled.connect(start_autoplay)  # 第 205 行
    else:
        push_error("未指定 _autoPlayButton")  # 第 207 行
```

但 `konado_dialogue.tscn` 的 `node_paths` PackedStringArray 中没有包含 `_autoPlayButton`，也没有设置导出值。这导致场景每次加载时都会报运行时错误。

### 修复方案

在 `konado_dialogue.tscn` 中，将 `"_autoPlayButton"` 添加到 `node_paths` 并设置导出值：

```diff
 [node name="KonadoDialogueManager" ... node_paths=PackedStringArray(
     "_konado_choice_interface", "_konado_dialogue_box",
     "_acting_interface", "_audio_interface",
     "error_tooltip_panel", "error_tooltip_label",
-    "error_skip_btn", "save_system"
+    "error_skip_btn", "save_system", "_autoPlayButton"
 )]
 ...
 save_system = NodePath("KND_SaveSystem")
+_autoPlayButton = NodePath("KonadoUI/ColorRect/HBoxContainer/AutoPlay")
```

### 涉及文件

- `addons/konado/template/konado_dialogue.tscn` — `node_paths` 数组和导出值

### 完整 diff

```diff
-[node name="KonadoDialogueManager" type="Control" unique_id=1487339260 node_paths=PackedStringArray("_konado_choice_interface", "_konado_dialogue_box", "_acting_interface", "_audio_interface", "error_tooltip_panel", "error_tooltip_label", "error_skip_btn", "save_system")]
+[node name="KonadoDialogueManager" type="Control" unique_id=1487339260 node_paths=PackedStringArray("_konado_choice_interface", "_konado_dialogue_box", "_acting_interface", "_audio_interface", "error_tooltip_panel", "error_tooltip_label", "error_skip_btn", "save_system", "_autoPlayButton")]
 ...
 save_system = NodePath("KND_SaveSystem")
+_autoPlayButton = NodePath("KonadoUI/ColorRect/HBoxContainer/AutoPlay")
```

---

## 环境信息

- Godot 4.6
- Konado 最新版（2026-06-03）
- 分辨率：1920×1080
