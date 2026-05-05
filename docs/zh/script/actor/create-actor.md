---
title: 创建演员
order: 1
---

# 创建演员

## 功能描述

在对话场景中创建一个演员

## 语法结构

```text
actor show [角色ID] [状态] at [v] [h] scale [比例] <mirror>
```

## 参数详解
| 参数 | 必需 | 示例 | 说明 |
|------|------|------|------|
| 角色ID | 是 | `alice` | 角色资源标识符 |
| 状态 | 是 | `angry` | 立绘状态 |
| 横向坐标 | 是 | `2` | 水平位置 |
| 纵向坐标 | 是 | `5` | 垂直位置|
| 比例 | 是 | `1.3` | 缩放比例 |
| mirror | 否 | - | 水平镜像翻转 |



## 示例
```text
# 显示角色（正常状态）
actor show alice normal at 2 5 scale 1.3

# 显示角色（水平镜像翻转）
actor show alice normal at 2 5 scale 1.3 mirror
```

