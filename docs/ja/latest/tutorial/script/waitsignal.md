---
title: 外部シグナルを待つ
order: 6
---

# 外部シグナルを待つ

```text
waitsignal "minigame_done"
```

```gdscript
$KonadoDialogueManager.emit_wait_signal("minigame_done")
```

同名のシグナルが外部コードから送られるまでシナリオを停止します。
