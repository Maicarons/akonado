---
title: Asynchronous camera
order: 4
---

# Asynchronous camera

`asyncam` starts camera work without blocking dialogue:

```text
asyncam move <camera_id> [none|linear|ease_in_out] [seconds]
asyncam reset [none|linear|ease_in_out] [seconds]
asyncam shake [seconds]
asyncam stop
```

`stop` finishes the active asynchronous operation immediately. Use `cam` instead when dialogue must wait for the camera animation.
