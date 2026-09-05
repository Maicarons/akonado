---
title: 非同期カメラ
order: 4
---

# 非同期カメラ

`asyncam` は対話を止めずにカメラ処理を開始します。

```text
asyncam move <camera_id> [none|linear|ease_in_out] [秒]
asyncam reset [none|linear|ease_in_out] [秒]
asyncam shake [秒]
asyncam stop
```

`stop` は実行中の処理を即時完了します。対話を待たせる場合は `cam` を使用してください。
