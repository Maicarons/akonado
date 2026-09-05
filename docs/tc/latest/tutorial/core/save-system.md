---
title: 存檔系統
order: 2
---

# 存檔系統

預設對話模板提供快速儲存、快速讀取和存檔面板。槽位 `0` 用作快速存檔；預設共有 20 個槽位，編號為 `0`–`19`。

## 使用方法

先取得預設對話模板中的對話管理器，例如：

```gdscript
@export var dialogue_manager: KonadoDialogueManager
```

### 儲存遊戲

```gdscript
# 儲存到指定槽位
dialogue_manager.save_game(1)  # 儲存到 1 號槽位
```

### 載入遊戲

```gdscript
# 從指定槽位載入
dialogue_manager.load_game(1)  # 從 1 號槽位載入
```

### 刪除存檔

```gdscript
# 刪除指定槽位的存檔
dialogue_manager.delete_save(1)  # 刪除 1 號槽位的存檔
```

### 取得存檔資訊

```gdscript
# 取得指定槽位的存檔資訊
var save_info = dialogue_manager.get_save_info(1)
print("存檔時間: " + str(save_info.get("save_time", {})))

# 取得所有存檔資訊
var all_save_infos = dialogue_manager.get_all_save_info()
for i in range(all_save_infos.size()):
    if all_save_infos[i].get("exists", false):
        print("存檔 " + str(i) + " 存在")
```

## 存檔資料結構

Konado 會在一個原子執行邊界中儲存目前指令、臨時與持久變數、對話框、演員、背景、相機和音訊等執行狀態。完整狀態必須整體儲存和還原，避免畫面與劇情邏輯不一致。

讀取時會驗證存檔格式、編譯器 ABI、劇本指紋和指令標識。劇本結構變更而無法準確還原時，載入會明確失敗，不會靜默跳到錯誤的劇情位置。`save_game()`、`load_game()` 和 `delete_save()` 都會回傳 `bool`，呼叫端應處理失敗結果。

## 存檔檔案格式

存檔保存在 `user://konado_saves/`，檔名為 `[槽位ID].kns`。檔案使用包含格式版本、長度和 SHA-256 完整性校驗的二進位封裝；這可以發現損壞或不完整寫入，但不屬於加密或防竄改安全機制。
