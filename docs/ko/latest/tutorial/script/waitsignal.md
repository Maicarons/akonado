---
title: 외부 신호 기다리기
order: 6
---

# 외부 신호 기다리기

```text
waitsignal "minigame_done"
```

```gdscript
$KonadoDialogueManager.emit_wait_signal("minigame_done")
```

외부 코드가 같은 이름을 보낼 때까지 스토리를 일시 중지합니다.
