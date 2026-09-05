---
title: 自定义对话框
order: 4
---

# 自定义对话界面

## 介绍

如果作品需要自定义对话界面，请先把选用的模板场景复制到项目自己的目录（例如 `res://ui/dialogue/`），再编辑副本或为它配置自定义主题。

不要直接修改 `res://addons/konado/` 中的文件；插件升级会替换插件目录。使用项目内副本后，可以正常升级 Konado。

## 编辑模板文件

`res://addons/konado/templates/` 保存的是内置对话界面模板。复制所需的 `.tscn` 到项目目录，在自己的对话场景中实例化副本，并把其中的 `KonadoDialogueBox` 节点分配给 `KonadoDialogueManager` 的 `dialogue_box` 属性。

一般情况下请不要修改节点上的脚本，而是通过修改节点上的属性来达到自定义的效果。

## 显示与隐藏 API

`KonadoDialogueBox` 将临时隐藏与关闭清理分为两组接口：

```gdscript
dialogue_box.hide_dialogue_box()
dialogue_box.hide_dialogue_box_with_duration(0.5)

dialogue_box.dismiss_dialogue_box()
dialogue_box.dismiss_dialogue_box_with_duration(0.5)
```

`hide_dialogue_box*()` 保留当前角色名和文本，适合暂时隐藏后恢复；`dismiss_dialogue_box*()` 会在隐藏动画完成后清除当前内容，适合结束当前对话内容。KonadoScript 的 `hidetextbox` 指令使用后者。

## 界面层级约定

内置界面使用以下 `CanvasLayer.layer` 层级，避免全屏界面因场景树顺序不同而相互遮挡：

| 层级 | 用途 |
|------|------|
| `1` | 舞台、背景与演出内容 |
| `10` | 对话框、选项与对话工具栏 |
| `50` | 存档界面 |
| `100` | 设置、成就等模态面板 |
| `110` | 成就解锁等短时通知 |
| `120` | 必须位于最上方的运行时错误提示 |

自定义界面应根据用途放在对应区间。除非确实需要覆盖系统错误提示，否则不要使用 `120` 或更高层级。成就面板和通知的层级还可以通过 `KonadoAchievements.panel_layer` 与 `popup_layer` 调整。

## 自定义音频进度显示

普通对话设置了配音标签，并且对应语音资源正在播放时，对话框右下角会显示音频播放进度。没有配音标签、没有找到语音资源，或语音播放结束后，进度显示会自动隐藏。

该功能默认开启。如果项目不需要显示语音进度，可以选中对话框节点 `KonadoDialogueBox`，在检查器中关闭 `show_voice_progress`。

音频进度显示是一个独立组件，默认场景位于：

```text
res://addons/konado/templates/default/voice_progress_display.tscn
```

如果只是修改进度条的颜色、圆角、尺寸或内部布局，优先复制并编辑这个场景。默认组件中包含：

| 节点 | 作用 |
|------|------|
| `VoiceProgressDisplay` | 音频进度显示组件根节点 |
| `VoiceProgressBar` | 实际显示进度的 `ProgressBar` |

常见自定义位置：

| 需求 | 修改位置 |
|------|----------|
| 修改进度条宽高 | `VoiceProgressDisplay.custom_minimum_size` |
| 修改背景颜色 | `VoiceProgressBar` 的 `background` StyleBox |
| 修改进度颜色 | `VoiceProgressBar` 的 `fill` StyleBox |
| 修改圆角 | `background` 和 `fill` StyleBox 的 `corner_radius_*` |
| 改成更复杂的显示样式 | 在 `voice_progress_display.tscn` 中替换或增加子节点 |

如果要调整进度显示在对话框中的位置，请在项目副本中编辑对应对话框模板里的 `VoiceProgressDisplay` 实例。内置源模板包括：

```text
res://addons/konado/templates/default/dialogue_box.tscn
res://addons/konado/templates/centered_dialogue/centered_dialogue_box.tscn
```

组件脚本通过两个方法接收对话框传入的状态：

```gdscript
func set_progress(current: float, total: float) -> void
func hide_progress() -> void
```

如果你想完全替换显示方式，可以保留这两个方法的含义：`set_progress()` 用于接收当前播放时间和总时长，`hide_progress()` 用于在没有配音或播放结束时隐藏组件。
