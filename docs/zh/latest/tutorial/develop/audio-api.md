---
title: 播放音频 API
order: 7
---

# 播放音频 API

`KonadoAudioController` 提供背景音乐、音效和语音的运行时播放接口，适用于需要在 GDScript 中直接控制音频的定制化场景。KonadoScript 中的 `play bgm`、`play sfx` 和 `stop bgm` 等剧情指令仍请参阅“音频”章节。

## 获取音频接口

在脚本中导出 `KonadoAudioController` 引用，然后在 Inspector 中将对话场景的 `KonadoAudioController` 节点赋给它。音频资源使用 Godot 的 `AudioStream`：

```gdscript
@export var audio_interface: KonadoAudioController
@export var bgm: AudioStream
@export var sound_effect: AudioStream
@export var voice: AudioStream
```

对话场景中的音频接口需要正确配置 `background_music_player`、`sound_effect_player` 和 `voice_player`。调用缺少对应播放器的接口会在 Godot 输出中报告错误。

## 背景音乐

`play_background_music()` 会立即开始循环播放背景音乐，不会等待播放结束。再次调用会替换当前背景音乐：

```gdscript
audio_interface.play_background_music(bgm, "main_theme")
```

第二个参数是当前签名保留的音频标识；现阶段不会改变播放行为，建议仍传入稳定且可读的资源名称。

停止当前背景音乐：

```gdscript
audio_interface.stop_background_music()
```

## 音效

`play_sound_effect()` 非阻塞地播放音效。默认音频接口使用单个音效播放器，因此新音效会停止并替换当前音效：

```gdscript
audio_interface.play_sound_effect(sound_effect)
```

## 语音

### 非阻塞播放

`play_voice()` 开始播放后立即返回，不会等待语音结束：

```gdscript
audio_interface.play_voice(voice)
```

如果当前已有语音正在播放，新语音会替换它。

### 播放并等待

需要等待播放结果时，使用 `play_voice_and_wait()`：

```gdscript
var completed := await audio_interface.play_voice_and_wait(voice)
if completed:
	print("语音自然播放完成")
else:
	print("语音被停止、替换或未能开始播放")
```

返回值含义：

| 返回值 | 含义 |
|---|---|
| `true` | 语音自然播放完成 |
| `false` | 语音被 `stop_voice()` 停止、被新语音替换，或未能开始播放 |

### 停止播放

```gdscript
audio_interface.stop_voice()
```

### 监听自然播放完成

`voice_finished` 信号只会在语音自然播放完成时发出。主动停止或被新语音替换时不会发出：

```gdscript
func _ready() -> void:
	audio_interface.voice_finished.connect(_on_voice_finished)


func _on_voice_finished() -> void:
	print("语音自然播放完成")
```

## 调用约定

- `play_background_music()`、`play_sound_effect()` 和 `play_voice()` 均为非阻塞接口。
- 需要区分语音自然结束、中断和启动失败时，使用 `play_voice_and_wait()`。
- 传入的音频资源应为有效的非空 `AudioStream`。
- 停止或替换语音会使对应的 `play_voice_and_wait()` 返回 `false`，不会误报为自然播放完成。
