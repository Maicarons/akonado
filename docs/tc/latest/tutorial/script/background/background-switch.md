---
title: 背景切換
order: 1
---

# 背景切換

## 功能描述
切換遊戲場景的背景場景，支援過渡效果。

背景資源由場景清單統一配置。建立方式請參考[場景化資源](../../core/scene-assets.md)。

## 語法結構
```text
background <背景資源名> [效果類型]
```

## 參數說明
| 參數 | 必需 | 範例值 | 說明 |
|------|------|--------|------|
| 背景資源名 | 是 | `morning_forest` | 背景清單中配置的背景場景名稱 |
| 效果類型 | 否 | `fade` | 過渡效果（預設：立即切換） |

### 支援的效果類型

以下是支援的背景切換效果類型，每種效果都有其獨特的視覺效果：

| 效果 | 描述 |
|------|------|
| `none` | 立即切換 |
| `fade` | 淡入淡出 |
| `erase` | 擦除 |
| `blinds` | 百葉窗 |
| `wave` | 波浪 |
| `vortex` | 漩渦 |
| `windmill` | 風車 |
| `cyberglitch` | 賽博故障 |

如果不指定效果類型，預設使用 `none`（立即切換）。

## 範例
```text
# 白天切換到夜晚（淡入效果）
background night_street fade

# 戰鬥場景切換（立即切換）
background battle_field none

# 回憶場景（擦除效果）
background memory_flash erase

# 夢幻場景（漩渦效果）
background dream vortex
```
