---
title: 等待外部信号
order: 6
---

# 等待外部信号

## 功能描述

用于在脚本中暂停对话流程，等待外部代码触发指定信号后，再继续执行下一句对话。适合与过场动画、小游戏、自定义交互等场景配合使用。

## 语法结构

```text
waitsignal <signal_name>
```

## 参数说明

| 参数 | 必需 | 示例 | 说明 |
|------|------|------|------|
| signal_name | 是 | `"over"` | 外部信号名称，可以是字符串字面量或标识符 |

## 外部调用

在对话暂停后，需要在外部代码中通过 `KonadoDialogueManager` 的 `emit_wait_signal` 方法触发信号，才能继续对话流程。

```gdscript
# 触发信号，继续对话
$KonadoDialogueManager.emit_wait_signal("over")
```

## 示例

```text
# 等待名为 "over" 的外部信号
waitsignal "over"

# 也可以使用标识符形式（不带引号）
waitsignal over
```

### 配合脚本使用

```text
# 显示对话框
showtextbox 0.5

# 普通对话
alice "接下来我们来玩个小游戏！"

# 等待外部触发器（如小游戏完成）
waitsignal "minigame_done"

# 小游戏完成后继续
alice "恭喜你完成了！"
```

外部代码：

```gdscript
# 小游戏完成后触发
func _on_minigame_finished():
    $KonadoDialogueManager.emit_wait_signal("minigame_done")
```