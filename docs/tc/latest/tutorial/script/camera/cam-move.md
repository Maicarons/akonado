---
title: 移動鏡頭
order: 1
---

# 移動鏡頭

```text
cam move <camera_id> [none|linear|ease_in_out] [秒]
```

移動到目前背景中名稱唯一的 `KonadoCameraMarker`。`KonadoCameraMarker` 只儲存目標位置與縮放，不會直接繪製場景。省略或使用 `none` 會立即移動；動畫預設為一秒。
