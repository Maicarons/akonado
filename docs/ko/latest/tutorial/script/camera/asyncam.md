---
title: 비동기 카메라
order: 4
---

# 비동기 카메라

`asyncam`은 대화를 멈추지 않고 카메라 작업을 시작합니다.

```text
asyncam move <camera_id> [none|linear|ease_in_out] [초]
asyncam reset [none|linear|ease_in_out] [초]
asyncam shake [초]
asyncam stop
```

`stop`은 진행 중인 작업을 즉시 완료합니다. 대화가 카메라를 기다려야 하면 `cam`을 사용하세요.
