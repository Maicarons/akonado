---
title: 오디오 재생 API
order: 7
---

# 오디오 재생 API

`KonadoAudioController`는 GDScript 사용자 지정 구현에서 배경 음악, 효과음, 음성을 제어할 수 있는 런타임 재생 API를 제공합니다. KonadoScript의 `play bgm`, `play sfx`, `stop bgm` 같은 스토리 명령은 “오디오” 섹션을 참조하세요.

## 오디오 인터페이스 가져오기

스크립트에서 `KonadoAudioController` 참조를 내보낸 다음 Inspector에서 대화 장면의 `KonadoAudioController` 노드를 할당합니다. 오디오 리소스에는 Godot의 `AudioStream`을 사용합니다.

```gdscript
@export var audio_interface: KonadoAudioController
@export var bgm: AudioStream
@export var sound_effect: AudioStream
@export var voice: AudioStream
```

대화 장면의 오디오 인터페이스에는 `background_music_player`, `sound_effect_player`, `voice_player`가 올바르게 할당되어 있어야 합니다. 해당 플레이어가 없는 API를 호출하면 Godot 출력에 오류가 보고됩니다.

## 배경 음악

`play_background_music()`은 배경 음악의 반복 재생을 즉시 시작하며 재생이 끝날 때까지 기다리지 않습니다. 다시 호출하면 현재 음악을 새 음악으로 교체합니다.

```gdscript
audio_interface.play_background_music(bgm, "main_theme")
```

두 번째 인자는 현재 시그니처에 유지된 오디오 식별자입니다. 현재 재생 동작에는 영향을 주지 않지만 안정적이고 읽기 쉬운 리소스 이름을 사용하는 것이 좋습니다.

현재 배경 음악을 중지하려면 다음과 같이 호출합니다.

```gdscript
audio_interface.stop_background_music()
```

## 효과음

`play_sound_effect()`는 효과음을 비차단 방식으로 재생합니다. 기본 오디오 인터페이스는 하나의 효과음 플레이어를 사용하므로 새 효과음은 현재 효과음을 중지하고 교체합니다.

```gdscript
audio_interface.play_sound_effect(sound_effect)
```

## 음성

### 비차단 재생

`play_voice()`는 재생을 시작한 뒤 음성이 끝날 때까지 기다리지 않고 즉시 반환합니다.

```gdscript
audio_interface.play_voice(voice)
```

이미 다른 음성이 재생 중이면 새 음성이 기존 음성을 대체합니다.

### 재생 후 완료 기다리기

재생 결과를 기다려야 할 때는 `play_voice_and_wait()`를 사용합니다.

```gdscript
var completed := await audio_interface.play_voice_and_wait(voice)
if completed:
	print("음성이 자연스럽게 재생 완료됨")
else:
	print("음성이 중지 또는 교체되었거나 재생을 시작하지 못함")
```

반환값:

| 값 | 의미 |
|---|---|
| `true` | 음성이 자연스럽게 재생 완료됨 |
| `false` | `stop_voice()`로 중지됨, 새 음성으로 교체됨 또는 재생을 시작하지 못함 |

### 재생 중지

```gdscript
audio_interface.stop_voice()
```

### 자연 재생 완료 감지

`voice_finished` 신호는 음성이 자연스럽게 재생 완료된 경우에만 발생합니다. 재생이 중지되거나 다른 음성으로 교체되면 발생하지 않습니다.

```gdscript
func _ready() -> void:
	audio_interface.voice_finished.connect(_on_voice_finished)


func _on_voice_finished() -> void:
	print("음성이 자연스럽게 재생 완료됨")
```

## API 동작 규칙

- `play_background_music()`, `play_sound_effect()`, `play_voice()`는 모두 비차단 방식입니다.
- 음성의 자연 완료, 중단, 재생 시작 실패를 구분해야 할 때는 `play_voice_and_wait()`를 사용합니다.
- 재생 메서드에는 유효한 비어 있지 않은 `AudioStream`을 전달하세요.
- 음성을 중지하거나 교체하면 해당 `play_voice_and_wait()`는 `false`를 반환하며 자연 완료로 보고되지 않습니다.
