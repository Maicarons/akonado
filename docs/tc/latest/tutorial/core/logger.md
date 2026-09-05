---
title: Logger
order: 4
---

# 日誌器 KonadoLogger

## 前言

KonadoLogger 是基於 Godot Logger 實作的日誌模組，支援日誌級別、日誌格式、日誌輸出、日誌檔案等功能，用於記錄 Konado 執行時的日誌資訊。

## 日誌路徑

日誌檔案的邏輯路徑為 `user://konado_log.log`，實際目錄由 Godot 依目前作業系統與專案名稱決定，可透過 `OS.get_user_data_dir()` 查看。`LOG_FILE_PATH` 是內建常數；如需改用其他路徑，應在維護自訂外掛版本時修改此常數。

## 螢幕覆蓋日誌

發生錯誤時，對話場景會在螢幕上覆蓋一個日誌視窗，用於顯示錯誤資訊並中斷遊戲執行。一般警告仍會寫入日誌檔案，但不會顯示為執行時錯誤或中斷遊戲。如果您希望關閉錯誤覆蓋視窗，可以將 `KonadoDialogueManager` 的 `enable_overlay_log` 屬性設定為 `false`。

## 日誌回呼

`KonadoLogger` 實例會發出 `error_caught(msg)` 與 `message_caught(message, error)` 訊號。`KonadoDialogueManager` 進入場景樹時會建立內部日誌器並向 Godot 註冊，再以 `error_caught` 驅動畫面覆蓋日誌；它不是全域自動載入物件。自訂日誌整合若另行建立 `KonadoLogger`，必須使用 `OS.add_logger()` 註冊，並在釋放前使用 `OS.remove_logger()` 移除，避免重複記錄或殘留無效實例。

## 執行時故障

原子指令執行失敗時，`KonadoDialogueManager` 只會寫入一筆最終錯誤，並發出 `runtime_failure_reported(failure)` 訊號。`failure` 包含穩定錯誤碼、具體操作、相關資源、底層原因、原始碼路徑與行號、指令 ID、操作碼及程式位置，可用於錯誤回報或自訂除錯介面。`runtime_failed(message, instruction_id, source_line)` 仍保留為精簡介面。
