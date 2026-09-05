---
title: Logger
order: 4
---

# 日志器 KonadoLogger

## 前言

KonadoLogger 是基于Godot Logger实现的日志模块，支持日志级别、日志格式、日志输出、日志文件等功能，用于记录Konado运行时的日志信息。

## 日志路径

日志文件逻辑路径为 `user://konado_log.log`，其实际目录由 Godot 针对当前操作系统和项目名称决定，可通过 `OS.get_user_data_dir()` 查看。`LOG_FILE_PATH` 是内置常量；如需改用其他路径，应在维护自定义插件版本时修改该常量。

## 屏幕覆盖日志

发生错误时，对话场景会在屏幕上覆盖一个日志窗口，用于显示错误信息并中断游戏运行。普通警告仍会写入日志文件，但不会显示为运行时错误或中断游戏。如果您希望关闭错误覆盖窗口，可以将 `KonadoDialogueManager` 的 `enable_overlay_log` 属性设置为 `false`。

## 日志回调

`KonadoLogger` 实例会发出 `error_caught(msg)` 和 `message_caught(message, error)` 信号。`KonadoDialogueManager` 会在进入场景树时创建并向 Godot 注册内部日志器，再使用 `error_caught` 驱动覆盖日志；它不是全局自动加载对象。自定义日志集成如果另行创建 `KonadoLogger`，必须使用 `OS.add_logger()` 注册，并在释放前使用 `OS.remove_logger()` 注销，避免重复记录或残留无效实例。

## 运行时故障

原子指令执行失败时，`KonadoDialogueManager` 只写入一条最终错误，并发出 `runtime_failure_reported(failure)` 信号。`failure` 包含稳定错误码、具体操作、相关资源、底层原因、源码路径与行号、指令 ID、操作码和程序位置，适合接入崩溃上报或自定义调试界面。`runtime_failed(message, instruction_id, source_line)` 作为简化接口保留。
