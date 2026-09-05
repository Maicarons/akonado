---
title: 2.8로 업그레이드
order: 2
---

# 2.8로 업그레이드

2.8은 런타임, 컴파일러, 플러그인 구조를 다시 설계하고 공개 API 이름을 통일했습니다. 먼저 프로젝트를 백업한 다음 기존 플러그인 디렉터리 전체를 2.8로 교체하고 Godot을 다시 여세요.

알려진 플러그인 경로와 Autoload 이름은 자동으로 이전됩니다. UID가 있는 장면과 리소스 참조는 보통 새 위치로 자동 해석됩니다. 사용자 GDScript는 수정하지 않으므로 이전 타입 이름은 직접 변경해야 합니다.

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
| `KND_Dialogue` / `KND_DialogueChoice` | 읽기 전용 `KonadoInstruction` |
| `KND_ScreenText` | `KonadoScreenText` |
| `KND_TypewriterText` | `KonadoTypewriterText` |
| `KND_Data` | `KonadoData` |
| `KND_VariableStore` | `KonadoVariableStore` |
| `KND_BackgroundSceneBase` | `KonadoBackgroundSceneBase` |
| `KND_ActorMotionLayer` | `KonadoActorMotionLayer` |
| `KonadoCamera2D` | `KonadoCameraMarker` |
| `KND_Logger` | `KonadoLogger` |

문자열로 저장한 이전 플러그인 경로도 갱신하세요. UID로 정상 해석되는 일반 장면 참조는 직접 바꿀 필요가 없습니다.

이전 `KND_CharacterStatus` 리소스는 캐릭터 장면 상태 프로토콜과 `status_aliases`로 대체되었습니다. `KND_BackgroundTransitionLayer`를 직접 생성하지 말고 배경 전환은 `KonadoStageController`에 맡기세요. `KonadoScriptsInterpreter`를 직접 사용하던 도구는 `KonadoScriptCompiler`로 `KonadoProgram`을 만들고 `KonadoDialogueManager`에서 재생하도록 이전해야 합니다.

`.ks` 소스는 2.8 컴파일러로 다시 임포트됩니다. 2.7에서 생성된 컴파일 캐시는 복사하지 마세요. 2.7 저장 데이터는 2.8에서 복원할 수 없으며 명확하게 거부됩니다. 2.8에서 따옴표가 없는 대화 화자는 배우 ID입니다. 텍스트 레이블로 사용할 때는 따옴표로 감싸세요.

업그레이드 후 GDScript 구문 분석 오류가 없는지 확인하고 모든 `.ks`를 다시 임포트한 뒤 시작, 스크립트 간 점프, 저장/불러오기, 언어 전환을 실제로 테스트하세요.
