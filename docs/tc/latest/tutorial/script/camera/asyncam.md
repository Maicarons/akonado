---
title: 非同步運鏡
order: 4
---

# 非同步運鏡

`asyncam` 不會阻塞對話：

```text
asyncam move <camera_id> [none|linear|ease_in_out] [秒]
asyncam reset [none|linear|ease_in_out] [秒]
asyncam shake [秒]
asyncam stop
```

`stop` 會立即完成目前操作。若對話必須等待鏡頭，請使用 `cam`。
