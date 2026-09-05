---
title: Save System
order: 2
---

# Save System

The default dialogue template includes Quick Save, Quick Load, and a save-slot panel. Slot `0` is reserved for quick saves. The default configuration provides 20 slots numbered `0` through `19`.

## Usage

Reference the dialogue manager from the default dialogue template first:

```gdscript
@export var dialogue_manager: KonadoDialogueManager
```

### Save Game

```gdscript
# Save to specified slot
dialogue_manager.save_game(1)  # Save to slot 1
```

### Load Game

```gdscript
# Load from specified slot
dialogue_manager.load_game(1)  # Load from slot 1
```

### Delete Save

```gdscript
# Delete the save in the specified slot
dialogue_manager.delete_save(1)  # Delete save in slot 1
```

### Get Save Information

```gdscript
# Get save information for a specified slot
var save_info = dialogue_manager.get_save_info(1)
print("Save time: " + str(save_info.get("save_time", {})))

# Get all save information
var all_save_infos = dialogue_manager.get_all_save_info()
for i in range(all_save_infos.size()):
    if all_save_infos[i].get("exists", false):
        print("Save " + str(i) + " exists")
```

## Save Data Structure

Konado saves the current instruction, temporary and persistent variables, dialogue box, actors, background, camera, audio, and other runtime state at one atomic execution boundary. The complete state is saved and restored as one unit so the presentation cannot diverge from story logic.

Loading validates the file format, compiler ABI, script fingerprint, and instruction identity. If a changed script can no longer be restored precisely, loading fails instead of silently continuing at the wrong story position. `save_game()`, `load_game()`, and `delete_save()` return `bool`; callers should handle failure.

## Save File Format

Save files are stored under `user://konado_saves/` as `[slot ID].kns`. They use a binary envelope with a format version, payload length, and SHA-256 integrity digest. This detects corruption and incomplete writes; it is not encryption or a tamper-resistance mechanism.
