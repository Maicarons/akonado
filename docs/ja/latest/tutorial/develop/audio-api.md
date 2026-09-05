---
title: オーディオ再生 API
order: 7
---

# オーディオ再生 API

`KonadoAudioController` は、GDScript によるカスタム実装向けに、BGM、効果音、ボイスのランタイム再生 API を提供します。KonadoScript の `play bgm`、`play sfx`、`stop bgm` などのシナリオ用コマンドについては、「オーディオ」セクションを参照してください。

## オーディオインターフェースの取得

スクリプトで `KonadoAudioController` の参照をエクスポートし、Inspector でダイアログシーンの `KonadoAudioController` ノードを割り当てます。オーディオリソースには Godot の `AudioStream` を使用します。

```gdscript
@export var audio_interface: KonadoAudioController
@export var bgm: AudioStream
@export var sound_effect: AudioStream
@export var voice: AudioStream
```

ダイアログシーンのオーディオインターフェースでは、`background_music_player`、`sound_effect_player`、`voice_player` を正しく設定する必要があります。対応するプレイヤーが未設定の API を呼び出すと、Godot の出力にエラーが表示されます。

## BGM

`play_background_music()` は BGM のループ再生を直ちに開始し、再生終了を待ちません。再度呼び出すと、現在の BGM が置き換えられます。

```gdscript
audio_interface.play_background_music(bgm, "main_theme")
```

第 2 引数は現在のシグネチャに残されているオーディオ識別子です。現時点では再生動作に影響しませんが、安定した分かりやすいリソース名を使用してください。

現在の BGM を停止するには、次のように呼び出します。

```gdscript
audio_interface.stop_background_music()
```

## 効果音

`play_sound_effect()` は効果音を非ブロッキングで再生します。標準のオーディオインターフェースは効果音プレイヤーを 1 つ使用するため、新しい効果音は現在の効果音を停止して置き換えます。

```gdscript
audio_interface.play_sound_effect(sound_effect)
```

## ボイス

### 非ブロッキング再生

`play_voice()` は再生を開始するとすぐに制御を返し、ボイスの終了を待ちません。

```gdscript
audio_interface.play_voice(voice)
```

すでに別のボイスが再生中の場合は、新しいボイスに置き換わります。

### 再生して完了を待つ

再生結果を待つ場合は `play_voice_and_wait()` を使用します。

```gdscript
var completed := await audio_interface.play_voice_and_wait(voice)
if completed:
	print("ボイスが最後まで再生されました")
else:
	print("ボイスが停止、置換されたか、再生を開始できませんでした")
```

戻り値：

| 値 | 意味 |
|---|---|
| `true` | ボイスが最後まで自然に再生された |
| `false` | `stop_voice()` で停止された、別のボイスに置き換えられた、または再生を開始できなかった |

### 再生の停止

```gdscript
audio_interface.stop_voice()
```

### 自然終了の検知

`voice_finished` シグナルは、ボイスが最後まで自然に再生された場合にのみ発行されます。停止または置換された場合は発行されません。

```gdscript
func _ready() -> void:
	audio_interface.voice_finished.connect(_on_voice_finished)


func _on_voice_finished() -> void:
	print("ボイスが最後まで再生されました")
```

## API の動作保証

- `play_background_music()`、`play_sound_effect()`、`play_voice()` はすべて非ブロッキングです。
- ボイスの自然終了、中断、再生開始失敗を区別する必要がある場合は、`play_voice_and_wait()` を使用します。
- 再生メソッドには、有効な空でない `AudioStream` を渡してください。
- ボイスを停止または置換すると、対応する `play_voice_and_wait()` は `false` を返し、自然終了としては扱われません。
