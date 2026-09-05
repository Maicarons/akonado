---
title: Wait for an external signal
order: 6
---

# Wait for an external signal

Pause the story until application code emits the same name:

```text
waitsignal "minigame_done"
```

```gdscript
$KonadoDialogueManager.emit_wait_signal("minigame_done")
```

Quoted strings and identifiers are accepted. This is useful for cutscenes, minigames, and custom interactions.
