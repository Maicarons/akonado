---
title: 背景切换特效
order: 3
---

# 背景转场特效

## 前言

背景转场特效，是指在切换场景时，当前背景场景退出，同时新背景场景进入的效果。这种特效可以增加的视觉冲击力，提升用户体验。阅读本章节可以帮助您实现自定义的背景转场特效。

如果您只是想制作普通背景场景，或想了解图片、视频、Spine、Live2D 背景如何接入，请先阅读[场景化资源](scene-assets.md)。

## 背景切换 Shader 规范

为了统一管理和播放背景转场特效，我们约定了一个 Shader 规范，具体如下：

shader类型必须是 `canvas_item`

```glsl
shader_type canvas_item;
```

必须实现以下三个参数：

```glsl
uniform float progress : hint_range(0, 1) = 0.0; // 转场进度 0=仅current 1=仅target
uniform sampler2D current_texture : hint_default_black; // 当前纹理
uniform sampler2D target_texture : hint_default_black; // 目标纹理
```

- progress：转场进度，取值范围 0~1，0 表示仅显示当前纹理，1 表示仅显示目标纹理。
- current_texture：当前纹理，没切换场景时显示的纹理。
- target_texture：目标纹理，切换场景后显示的纹理。

## 背景切换特效配置

同时，切换背景是一个动态的过程，因此还需要补充以下：

在 `KND_BackgroundTransitionLayer` 中注册效果名，用于标识背景切换特效类型。
```
your_effect
```

定义shader变量，推荐使用 `preload` 函数加载 Shader 文件。
```
var your_effect_shader: Shader = preload("res://path/to/your_effect_shader.shader")
```

接下来需要为效果名添加背景切换特效配置。

```gdscript
"your_effect": {
	"shader": your_effect_shader,  // 背景切换 Shader，应和上文中变量一致
	"duration": 1.0,  // 转场时长，默认为1.0s
	"progress_target": 1.0,  // 目标进度，默认为1.0
	"tween_trans": Tween.TRANS_LINEAR  // 切换时缓动类型
}
```

配置完成后，就可以在 KS 中使用：

```text
background bg1 your_effect
```

接下来测试一下背景切换特效，在切换场景时，添加以下测试代码，观察背景切换效果是否符合预期。

```gdscript
bg.material.set("shader", your_effect_shader)

bg.material.set_shader_parameter("progress", 0.0)
bg.material.set_shader_parameter("current_texture", current_texture)
bg.material.set_shader_parameter("target_texture", tex)

# 创建并配置过渡动画
effect_tween = get_tree().create_tween()
effect_tween.tween_property(
	bg.material, 
	"shader_parameter/progress", 
	1.0, 
	1.0
)

effect_tween.play()
```

