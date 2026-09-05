---
title: Upgrade to 2.8
order: 2
---

# Upgrade to 2.8

Konado 2.8 rebuilds the runtime, compiler, and plugin layout, and standardizes the public API names. Back up the project, replace the complete old plugin directories with 2.8, and reopen Godot.

The plugin migrates known plugin paths and Autoload names. Scene and resource references with UIDs normally resolve to the new locations automatically. User GDScript is never rewritten, so update old type names manually.

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
| `KND_Dialogue` / `KND_DialogueChoice` | Read-only `KonadoInstruction` |
| `KND_ScreenText` | `KonadoScreenText` |
| `KND_TypewriterText` | `KonadoTypewriterText` |
| `KND_Data` | `KonadoData` |
| `KND_VariableStore` | `KonadoVariableStore` |
| `KND_BackgroundSceneBase` | `KonadoBackgroundSceneBase` |
| `KND_ActorMotionLayer` | `KonadoActorMotionLayer` |
| `KonadoCamera2D` | `KonadoCameraMarker` |
| `KND_Logger` | `KonadoLogger` |

Update old plugin paths that are stored as literal strings. Ordinary scene references that resolve through their UID do not need manual changes.

The old `KND_CharacterStatus` resource is replaced by the character-scene status protocol and `status_aliases`. Do not instantiate `KND_BackgroundTransitionLayer`; `KonadoStageController` now owns background transitions internally. Tools that used `KonadoScriptsInterpreter` directly should compile a `KonadoProgram` with `KonadoScriptCompiler` and play it through `KonadoDialogueManager`.

Godot reimports `.ks` source with the 2.8 compiler; do not copy generated 2.7 compiler caches. Version 2.7 saves cannot be restored by 2.8 and are rejected explicitly. An unquoted dialogue speaker is an actor ID in 2.8; quote the speaker when it is a text label.

After upgrading, verify that the project has no GDScript parse errors, reimport every `.ks` file, and test startup, cross-script jumps, save/load, and locale switching.
