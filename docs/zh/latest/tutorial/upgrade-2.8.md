---
title: 升级到 2.8
order: 2
---

# 升级到 2.8

2.8 重构了运行时、编译器和插件目录，并统一了公开标识符。升级前请备份项目，再用完整的 2.8 插件目录替换旧版本并重新打开 Godot。

插件会自动迁移已知的插件路径和 Autoload 名称。带 UID 的场景与资源引用通常会自动解析到新目录；插件不会改写用户的 GDScript，因此代码中的旧类型名需要手动更新。

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
| `KND_Dialogue` / `KND_DialogueChoice` | 只读的 `KonadoInstruction` |
| `KND_ScreenText` | `KonadoScreenText` |
| `KND_TypewriterText` | `KonadoTypewriterText` |
| `KND_Data` | `KonadoData` |
| `KND_VariableStore` | `KonadoVariableStore` |
| `KND_BackgroundSceneBase` | `KonadoBackgroundSceneBase` |
| `KND_ActorMotionLayer` | `KonadoActorMotionLayer` |
| `KonadoCamera2D` | `KonadoCameraMarker` |
| `KND_Logger` | `KonadoLogger` |

直接写在字符串中的旧插件路径也需要改为 2.8 的新路径；普通场景引用如果能通过 UID 正常加载，无需手动改写。

旧版 `KND_CharacterStatus` 资源已由角色场景的状态协议和 `status_aliases` 取代。不要再直接创建 `KND_BackgroundTransitionLayer`；背景转场现在由 `KonadoStageController` 内部管理。直接使用 `KonadoScriptsInterpreter` 的工具代码应改为通过 `KonadoScriptCompiler` 生成 `KonadoProgram`，播放时交给 `KonadoDialogueManager`。

`.ks` 源文件会由 2.8 编译器重新导入，不要复制旧版生成的编译缓存。2.7 的存档格式不能恢复到 2.8，加载时会被明确拒绝。无引号的对话署名在 2.8 中表示演员 ID；需要纯文本署名时请使用引号。

升级完成后，请确认项目没有 GDScript 解析错误，重新导入全部 `.ks`，并实际测试开场、跨脚本跳转、存读档和语言切换。
