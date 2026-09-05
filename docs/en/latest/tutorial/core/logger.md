---
title: Logger
order: 4
---

# Logger KonadoLogger

## Preface

KonadoLogger is a logging module based on the Godot Logger implementation. It supports log levels, log formats, log output, log files, and other features, and is used to record Konado runtime log information.

## Log Path

The logical log path is `user://konado_log.log`. Godot resolves its physical directory for the current operating system and project name; use `OS.get_user_data_dir()` to inspect it. `LOG_FILE_PATH` is a built-in constant, so changing the location requires maintaining that change in a customized plugin build.

## On-Screen Overlay Log

When an error occurs, the dialogue scene overlays a log window to show the error and interrupt game execution. Regular warnings are still written to the log file, but they are not presented as runtime failures and do not interrupt the game. To disable the error overlay, set the `enable_overlay_log` property of `KonadoDialogueManager` to `false`.

## Log Callback

A `KonadoLogger` instance emits `error_caught(msg)` and `message_caught(message, error)`. When `KonadoDialogueManager` enters the scene tree, it creates and registers an internal logger with Godot and uses `error_caught` to drive its overlay; the logger is not a global autoload. A custom integration that creates another `KonadoLogger` must register it with `OS.add_logger()` and call `OS.remove_logger()` before freeing it to avoid duplicate logging or stale instances.

## Runtime Failures

When an atomic instruction fails, `KonadoDialogueManager` writes one final error and emits `runtime_failure_reported(failure)`. The payload contains a stable error code, operation, related resource, underlying cause, source path and line, instruction ID, opcode, and program counter for crash reporting or custom debugging UI. `runtime_failed(message, instruction_id, source_line)` remains available as the compact interface.
