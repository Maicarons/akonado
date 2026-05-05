---
title: 演员移动
order: 3
---

# 演员移动

## 功能描述
将指定的角色移动到指定的位置。


## 语法结构
```text
actor move [角色ID] [目标v] [目标h]
```

## 参数详解
| 参数 | 必需 | 示例 | 说明 |
|------|------|------|------|
| 角色ID | 是 | `alice` | 角色资源标识符 |
| 目标v | 是 | `3` | 目标位置的x坐标 |
| 目标h | 是 | `5` | 目标位置的y坐标 |

关于坐标，请参考[演员坐标和缩放](/zh/tutorial/actor-coordinate-and-scaling)

## 示例

```text
actor move alice 3 5
```
