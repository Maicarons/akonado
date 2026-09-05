---
title: 移动镜头
order: 1
---

# 移动镜头

## 功能描述

将镜头移动到指定的目标镜头位置，并支持可选的过渡动画效果。目标镜头需要在背景场景中添加 `KonadoCameraMarker` 节点，可以添加多个来表示不同机位，并且要求每个节点都有唯一的镜头名称。`KonadoCameraMarker` 只保存机位数据，不直接渲染画面。

## 语法结构

```text
cam move [目标镜头ID] [过渡类型] [过渡时间]
```

## 参数详解

| 参数 | 必需 | 示例 | 说明 |
|------|------|------|------|
| 目标镜头ID | 是 | `cam1` | 要移动到的镜头资源标识符 |
| 过渡类型 | 否 | `linear` / `ease_in_out` / `none` | 过渡动画类型，不填或填 `none` 表示无动画 |
| 过渡时间 | 否 | `1.0` / `2.5` | 过渡动画的持续时间（秒），默认值为 `1.0` |

## 过渡类型说明

| 类型 | 说明 |
|------|------|
| 不填 | 默认无动画，直接切换 |
| `none` | 显式指定无动画 |
| `linear` | 线性过渡 |
| `ease_in_out` | 缓入缓出过渡 |

## 默认值规则

- 不写过渡类型 → `cam_tween_type=""`，`cam_tween_time=0.0`（无动画）
- 写 `none` → `cam_tween_type="none"`，`cam_tween_time=0.0`（无动画）
- 写其他过渡类型但不写时间 → `cam_tween_time=1.0`（默认1秒）

## 示例

```text
cam move cam1
cam move cam1 none
cam move cam1 linear
cam move cam1 linear 1.0
cam move cam1 ease_in_out 2.5
```
