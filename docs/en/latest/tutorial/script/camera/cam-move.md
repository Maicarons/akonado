---
title: Move camera
order: 1
---

# Move camera

Move to a uniquely named `KonadoCameraMarker` in the current background. A `KonadoCameraMarker` stores a target position and zoom; it does not render the scene itself:

```text
cam move <camera_id> [none|linear|ease_in_out] [seconds]
```

Omitting the transition, or using `none`, moves immediately. An animated transition defaults to one second.
