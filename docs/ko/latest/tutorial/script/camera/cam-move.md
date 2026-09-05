---
title: 카메라 이동
order: 1
---

# 카메라 이동

```text
cam move <camera_id> [none|linear|ease_in_out] [초]
```

현재 배경의 고유한 `KonadoCameraMarker`로 이동합니다. `KonadoCameraMarker`는 목표 위치와 확대/축소만 저장하며 씬을 직접 렌더링하지 않습니다. 생략 또는 `none`은 즉시 이동하며 애니메이션 기본값은 1초입니다.
