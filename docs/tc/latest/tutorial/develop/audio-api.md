---
title: 播放音訊 API
order: 7
---

# 播放音訊 API

`KonadoAudioController` 提供背景音樂、音效和語音的執行階段播放介面，適用於需要在 GDScript 中直接控制音訊的客製化場景。KonadoScript 中的 `play bgm`、`play sfx` 和 `stop bgm` 等劇情指令仍請參閱「音訊」章節。

## 取得音訊介面

在腳本中匯出 `KonadoAudioController` 參照，然後在 Inspector 中將對話場景的 `KonadoAudioController` 節點指派給它。音訊資源使用 Godot 的 `AudioStream`：

```gdscript
@export var audio_interface: KonadoAudioController
@export var bgm: AudioStream
@export var sound_effect: AudioStream
@export var voice: AudioStream
```

對話場景中的音訊介面需要正確設定 `background_music_player`、`sound_effect_player` 和 `voice_player`。呼叫缺少對應播放器的介面會在 Godot 輸出中回報錯誤。

## 背景音樂

`play_background_music()` 會立即開始循環播放背景音樂，不會等待播放結束。再次呼叫會取代目前的背景音樂：

```gdscript
audio_interface.play_background_music(bgm, "main_theme")
```

第二個參數是目前簽章保留的音訊識別名稱；現階段不會改變播放行為，建議仍傳入穩定且易讀的資源名稱。

停止目前的背景音樂：

```gdscript
audio_interface.stop_background_music()
```

## 音效

`play_sound_effect()` 會以非阻塞方式播放音效。預設音訊介面使用單一音效播放器，因此新音效會停止並取代目前的音效：

```gdscript
audio_interface.play_sound_effect(sound_effect)
```

## 語音

### 非阻塞播放

`play_voice()` 開始播放後立即返回，不會等待語音結束：

```gdscript
audio_interface.play_voice(voice)
```

如果目前已有語音正在播放，新語音會取代它。

### 播放並等待

需要等待播放結果時，使用 `play_voice_and_wait()`：

```gdscript
var completed := await audio_interface.play_voice_and_wait(voice)
if completed:
	print("語音自然播放完成")
else:
	print("語音已停止、被取代或未能開始播放")
```

返回值含義：

| 返回值 | 含義 |
|---|---|
| `true` | 語音自然播放完成 |
| `false` | 語音被 `stop_voice()` 停止、被新語音取代，或未能開始播放 |

### 停止播放

```gdscript
audio_interface.stop_voice()
```

### 監聽自然播放完成

`voice_finished` 訊號只會在語音自然播放完成時發出。主動停止或被新語音取代時不會發出：

```gdscript
func _ready() -> void:
	audio_interface.voice_finished.connect(_on_voice_finished)


func _on_voice_finished() -> void:
	print("語音自然播放完成")
```

## 呼叫約定

- `play_background_music()`、`play_sound_effect()` 和 `play_voice()` 均為非阻塞介面。
- 需要區分語音自然結束、中斷和啟動失敗時，使用 `play_voice_and_wait()`。
- 傳入的音訊資源應為有效且非空的 `AudioStream`。
- 停止或取代語音會使對應的 `play_voice_and_wait()` 返回 `false`，不會誤報為自然播放完成。
