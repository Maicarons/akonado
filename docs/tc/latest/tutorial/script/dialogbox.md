---
title: 顯示或隱藏對話框
order: 5
---

# 顯示或隱藏對話框

這些指令用於控制對話框顯示狀態，並會等待淡入淡出動畫完成後再繼續執行。

## 語法

```text
showtextbox [duration]
hidetextbox [duration]
```

`duration` 為可選的秒數，且不能是負數。省略或使用 `0.0` 可立即切換顯示狀態。

`hidetextbox` 會在隱藏完成後清除目前的角色名稱和對話文字，避免下次顯示時短暫出現上一句內容。

## 範例

```text
# 用一秒淡入顯示對話框
showtextbox 1.0

# 用半秒淡出隱藏對話框
hidetextbox 0.5

# 立即切換顯示狀態
showtextbox 0.0
hidetextbox 0.0
```
