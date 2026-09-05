---
title: 等待外部訊號
order: 6
---

# 等待外部訊號

```text
waitsignal "minigame_done"
```

```gdscript
$KonadoDialogueManager.emit_wait_signal("minigame_done")
```

劇情會暫停，直到外部程式送出同名訊號。
