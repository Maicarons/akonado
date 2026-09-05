---
title: 自訂對話框
order: 4
---

# 自訂對話介面

## 介紹

若作品需要自訂對話介面，請先將選用的範本場景複製到專案自己的目錄（例如 `res://ui/dialogue/`），再編輯副本或套用自訂主題。

不要直接修改 `res://addons/konado/` 內的檔案；外掛升級會替換外掛目錄。使用專案內副本後即可正常升級 Konado。

## 編輯範本檔案

`res://addons/konado/templates/` 保存內建對話介面範本。將需要的 `.tscn` 複製到專案目錄，在自己的對話場景中實例化副本，並把其中的 `KonadoDialogueBox` 節點指派給 `KonadoDialogueManager` 的 `dialogue_box` 屬性。

一般情況下請不要修改節點上的腳本，而是透過修改節點屬性來達到自訂效果。

## 顯示與隱藏 API

`KonadoDialogueBox` 將暫時隱藏與關閉清理分為兩組介面：

```gdscript
dialogue_box.hide_dialogue_box()
dialogue_box.hide_dialogue_box_with_duration(0.5)

dialogue_box.dismiss_dialogue_box()
dialogue_box.dismiss_dialogue_box_with_duration(0.5)
```

`hide_dialogue_box*()` 會保留目前的角色名稱和對話文字，適合暫時隱藏後恢復；`dismiss_dialogue_box*()` 會在隱藏動畫完成後清除目前內容，適合結束目前的對話內容。KonadoScript 的 `hidetextbox` 指令使用後者。

## 介面層級約定

內建介面使用以下 `CanvasLayer.layer` 層級，避免全螢幕介面因場景樹順序不同而互相遮擋：

| 層級 | 用途 |
|------|------|
| `1` | 舞台、背景與演出內容 |
| `10` | 對話框、選項與對話工具列 |
| `50` | 存檔介面 |
| `100` | 設定、成就等模態面板 |
| `110` | 成就解鎖等短暫通知 |
| `120` | 必須位於最上層的執行階段錯誤提示 |

自訂介面應依用途放在對應區間。除非確實需要覆蓋系統錯誤提示，否則不要使用 `120` 或更高層級。成就面板和通知的層級亦可透過 `KonadoAchievements.panel_layer` 與 `popup_layer` 調整。

## 自訂語音進度顯示

一般對話已設定語音標籤且語音正在播放時，對話框會顯示播放進度；沒有語音、資源無法解析或播放結束時會自動隱藏。可在 `KonadoDialogueBox` 節點關閉 `show_voice_progress`。

內建元件來源位於 `res://addons/konado/templates/default/voice_progress_display.tscn`。請將它複製到專案後修改顏色、圓角、尺寸或節點結構，再由對話框副本引用。若完全替換元件，請保留以下介面：

```gdscript
func set_progress(current: float, total: float) -> void
func hide_progress() -> void
```
