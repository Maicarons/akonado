---
title: Audio Playback API
order: 7
---

# Audio Playback API

`KonadoAudioController` provides runtime playback APIs for background music, sound effects, and voice audio in custom GDScript integrations. For story-level commands such as `play bgm`, `play sfx`, and `stop bgm`, see the KonadoScript “Audio” section instead.

## Getting the audio interface

Export a `KonadoAudioController` reference and assign the dialogue scene's `KonadoAudioController` node to it in the Inspector. Audio resources use Godot's `AudioStream` type:

```gdscript
@export var audio_interface: KonadoAudioController
@export var bgm: AudioStream
@export var sound_effect: AudioStream
@export var voice: AudioStream
```

The audio interface in the dialogue scene must have its `background_music_player`, `sound_effect_player`, and `voice_player` properties assigned. Calling an API whose player is missing reports an error in the Godot output.

## Background music

`play_background_music()` immediately starts looping the background music and does not wait for playback to finish. Calling it again replaces the current track:

```gdscript
audio_interface.play_background_music(bgm, "main_theme")
```

The second argument is the audio identifier retained by the current signature. It does not currently change playback behavior, but a stable, readable resource name is recommended.

Stop the current background music with:

```gdscript
audio_interface.stop_background_music()
```

## Sound effects

`play_sound_effect()` plays a sound effect without blocking. The default audio interface uses one sound-effect player, so a new effect stops and replaces the current effect:

```gdscript
audio_interface.play_sound_effect(sound_effect)
```

## Voice audio

### Non-blocking playback

`play_voice()` starts playback and returns immediately:

```gdscript
audio_interface.play_voice(voice)
```

If another voice is already playing, the new voice replaces it.

### Playing and waiting

Use `play_voice_and_wait()` when you need the playback result:

```gdscript
var completed := await audio_interface.play_voice_and_wait(voice)
if completed:
	print("Voice playback completed naturally")
else:
	print("Voice playback was stopped, replaced, or could not start")
```

Return values:

| Value | Meaning |
|---|---|
| `true` | The voice completed naturally |
| `false` | The voice was stopped with `stop_voice()`, replaced by another voice, or could not start |

### Stopping playback

```gdscript
audio_interface.stop_voice()
```

### Listening for natural completion

The `voice_finished` signal is emitted only when playback completes naturally. It is not emitted when playback is stopped or replaced:

```gdscript
func _ready() -> void:
	audio_interface.voice_finished.connect(_on_voice_finished)


func _on_voice_finished() -> void:
	print("Voice playback completed naturally")
```

## API guarantees

- `play_background_music()`, `play_sound_effect()`, and `play_voice()` are non-blocking.
- Use `play_voice_and_wait()` when natural completion, interruption, and startup failure must be distinguished.
- Pass a valid, non-null `AudioStream` to playback methods.
- Stopping or replacing voice playback resolves its `play_voice_and_wait()` call with `false`; it is never reported as natural completion.
