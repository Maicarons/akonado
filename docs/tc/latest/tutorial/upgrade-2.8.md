---
title: 升級到 2.8
order: 2
---

# 升級到 2.8

2.8 重構了執行階段、編譯器和外掛目錄，並統一公開識別符。升級前請備份專案，再以完整的 2.8 外掛目錄取代舊版本並重新開啟 Godot。

外掛會自動遷移已知的外掛路徑和 Autoload 名稱。帶 UID 的場景與資源參照通常會自動解析到新目錄；外掛不會改寫使用者的 GDScript，因此程式碼中的舊型別名稱需要手動更新。

| 2.7.4 | 2.8 |
|---|---|
| `KND_DialogueManager` | `KonadoDialogueManager` |
| `KND_Shot` | `KonadoShot` |
| `KND_SaveSystem` | `KonadoSaveSystem` |
| `KND_SaveData` | `KonadoSaveData` |
| `KND_Settings` | `KonadoSettings` |
| `KND_SettingCategory` | `KonadoSettingCategory` |
| `KND_SettingItem` | `KonadoSettingItem` |
| `KND_SettingsUIFactory` | `KonadoSettingsUIFactory` |
| `KND_AchievementManager` | `KonadoAchievements` |
| `KND_I18n` | `KonadoStoryLocalization` |
| `KND_Background` / `KND_BackgroundList` | `KonadoBackground` / `KonadoBackgroundList` |
| `KND_Character` / `KND_CharacterList` | `KonadoCharacter` / `KonadoCharacterList` |
| `KND_CharacterSceneBase` | `KonadoCharacterSceneBase` |
| `KND_CharacterTransitionFrame` | `KonadoCharacterTransitionFrame` |
| `KND_Actor` | `KonadoActor` |
| `KND_ActingInterface` | `KonadoStageController` |
| `KND_Bgm` / `KND_BgmList` | `KonadoBackgroundMusic` / `KonadoBackgroundMusicList` |
| `DialogVoice` / `DialogVoiceList` | `KonadoVoice` / `KonadoVoiceList` |
| `KND_SoundEffect` / `KND_SoundEffectList` | `KonadoSoundEffect` / `KonadoSoundEffectList` |
| `KND_AudioInterface` | `KonadoAudioController` |
| `KND_DialogueBox` | `KonadoDialogueBox` |
| `KND_Dialogue` / `KND_DialogueChoice` | 唯讀的 `KonadoInstruction` |
| `KND_ScreenText` | `KonadoScreenText` |
| `KND_TypewriterText` | `KonadoTypewriterText` |
| `KND_Data` | `KonadoData` |
| `KND_VariableStore` | `KonadoVariableStore` |
| `KND_BackgroundSceneBase` | `KonadoBackgroundSceneBase` |
| `KND_ActorMotionLayer` | `KonadoActorMotionLayer` |
| `KonadoCamera2D` | `KonadoCameraMarker` |
| `KND_Logger` | `KonadoLogger` |

直接寫在字串中的舊外掛路徑也需要改成 2.8 的新路徑；一般場景參照若能透過 UID 正常載入，便不需手動改寫。

舊版 `KND_CharacterStatus` 資源已由角色場景的狀態協定和 `status_aliases` 取代。請勿再直接建立 `KND_BackgroundTransitionLayer`；背景轉場現在由 `KonadoStageController` 內部管理。直接使用 `KonadoScriptsInterpreter` 的工具程式碼應改為透過 `KonadoScriptCompiler` 產生 `KonadoProgram`，播放時交由 `KonadoDialogueManager`。

`.ks` 原始檔會由 2.8 編譯器重新匯入，請勿複製舊版產生的編譯快取。2.7 的存檔格式無法還原到 2.8，載入時會被明確拒絕。2.8 中未加引號的對話署名代表演員 ID；需要純文字署名時請使用引號。

升級完成後，請確認專案沒有 GDScript 解析錯誤，重新匯入全部 `.ks`，並實際測試開場、跨腳本跳轉、存讀檔和語言切換。
