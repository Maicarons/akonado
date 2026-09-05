---
title: 2.8 へのアップグレード
order: 2
---

# 2.8 へのアップグレード

2.8 ではランタイム、コンパイラー、プラグイン構成を再設計し、公開 API 名を統一しました。事前にプロジェクトをバックアップし、旧プラグイン一式を 2.8 に置き換えてから Godot を開き直してください。

既知のプラグインパスと Autoload 名は自動移行されます。UID を持つシーンやリソース参照は通常、新しい配置へ自動的に解決されます。ユーザーの GDScript は書き換えないため、旧型名は手動で更新します。

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
| `KND_Dialogue` / `KND_DialogueChoice` | 読み取り専用の `KonadoInstruction` |
| `KND_ScreenText` | `KonadoScreenText` |
| `KND_TypewriterText` | `KonadoTypewriterText` |
| `KND_Data` | `KonadoData` |
| `KND_VariableStore` | `KonadoVariableStore` |
| `KND_BackgroundSceneBase` | `KonadoBackgroundSceneBase` |
| `KND_ActorMotionLayer` | `KonadoActorMotionLayer` |
| `KonadoCamera2D` | `KonadoCameraMarker` |
| `KND_Logger` | `KonadoLogger` |

文字列として保持している旧プラグインパスも更新してください。UID で正常に解決できる通常のシーン参照は変更不要です。

旧 `KND_CharacterStatus` リソースは、キャラクターシーンのステータスプロトコルと `status_aliases` に置き換わりました。`KND_BackgroundTransitionLayer` は直接生成せず、背景遷移は `KonadoStageController` に任せてください。`KonadoScriptsInterpreter` を直接使っていたツールは、`KonadoScriptCompiler` で `KonadoProgram` を生成し、`KonadoDialogueManager` で再生する構成へ移行します。

`.ks` ソースは 2.8 コンパイラーで再インポートされるため、2.7 の生成済みキャッシュをコピーしないでください。2.7 のセーブデータは 2.8 では復元できず、明示的に拒否されます。2.8 では引用符なしの話者名はアクター ID です。文字ラベルとして使う場合は引用符で囲みます。

移行後は GDScript の解析エラーがないことを確認し、すべての `.ks` を再インポートして、起動、スクリプト間ジャンプ、セーブ・ロード、言語切り替えを実機で確認してください。
