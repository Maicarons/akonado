extends Node
class_name KonadoAudioController

## 音频接口类

## Bgm播放成功
signal background_music_started
## 语音播放成功
signal voice_started
## 音效播放成功
signal sound_effect_started

## 语音播放完成
signal voice_finished

const SETTINGS_ADAPTER_SCRIPT := preload(
	"res://addons/konado/runtime/integrations/konado_settings_adapter.gd"
)


class VoicePlaybackWaiter:
	extends RefCounted

	signal settled(completed: bool)

	var result: Variant = null

	func settle(completed: bool) -> void:
		if result != null:
			return
		result = completed
		settled.emit(completed)


## BGM播放器
@export var background_music_player: AudioStreamPlayer
## 对话播放器
@export var voice_player: AudioStreamPlayer
## 音效播放器
@export var sound_effect_player: AudioStreamPlayer

## 设置桥接器引用
@export var settings_adapter: SETTINGS_ADAPTER_SCRIPT

## 缓存的音量值
var _master_volume: float = 1.0
var _music_volume: float = 0.8
var _sound_effect_volume: float = 1.0
var _voice_volume: float = 1.0
var _background_music_loop_enabled: bool = false
var _connected_background_music_player: AudioStreamPlayer
var _connected_voice_player: AudioStreamPlayer
var _voice_playing: bool = false
var _voice_generation: int = 0
var _voice_waiters: Dictionary[int, VoicePlaybackWaiter] = {}


func _exit_tree() -> void:
	_background_music_loop_enabled = false
	_cancel_voice_playback()
	var pending_generations: Array[int] = []
	pending_generations.assign(_voice_waiters.keys())
	for generation: int in pending_generations:
		_settle_voice_playback(generation, false)
	_disconnect_audio_connections()


## 从设置更新音量
func _update_volume_from_settings() -> void:
	if settings_adapter == null:
		return

	_master_volume = settings_adapter.get_master_volume()
	_music_volume = settings_adapter.get_music_volume()
	_sound_effect_volume = settings_adapter.get_sfx_volume()
	_voice_volume = settings_adapter.get_voice_volume()

	# 应用音量
	if background_music_player:
		background_music_player.volume_db = linear_to_db(_master_volume * _music_volume)
	if voice_player:
		voice_player.volume_db = linear_to_db(_master_volume * _voice_volume)
	if sound_effect_player:
		sound_effect_player.volume_db = linear_to_db(_master_volume * _sound_effect_volume)


## 设置变更处理
func _on_setting_changed(category: String, _key: String, _value: Variant) -> void:
	if category == "audio":
		_update_volume_from_settings()


## 将线性音量转换为分贝
func linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0
	return 20.0 * log(linear) / log(10.0)


## 播放BGM的方法（循环播放）
func play_background_music(audio: AudioStream, _audio_id: String) -> void:
	if not background_music_player:
		push_error("没找到background_music_player")
		background_music_started.emit()
		return
	_ensure_background_music_connection()
	_background_music_loop_enabled = true
	if background_music_player.is_playing():
		background_music_player.stop()
	background_music_player.stream = audio
	background_music_player.play()
	background_music_started.emit()


## 停止播放BGM的方法
func stop_background_music() -> void:
	if not background_music_player:
		push_error("没找到background_music_player")
		return
	_background_music_loop_enabled = false
	if background_music_player.is_playing():
		background_music_player.stop()


## 非阻塞地开始播放语音。自然播放完成时发出 voice_finished。
func play_voice(audio: AudioStream) -> void:
	_begin_voice_playback(audio, false)


## 播放并等待当前语音结束。
##
## 自然播放完成返回 true；被 stop_voice() 中断、被新语音替换或无法开始播放时返回 false。
func play_voice_and_wait(audio: AudioStream) -> bool:
	var generation := _begin_voice_playback(audio, true)
	if generation < 0:
		return false
	var waiter := _voice_waiters.get(generation)
	if waiter == null:
		return false
	if waiter.result != null:
		var immediate_result := bool(waiter.result)
		_voice_waiters.erase(generation)
		return immediate_result
	var result: bool = await waiter.settled
	_voice_waiters.erase(generation)
	return result


## 停止播放语音的方法
func stop_voice() -> void:
	if not voice_player and not is_instance_valid(_connected_voice_player):
		push_error("没找到voice_player")
	_cancel_voice_playback()


## Cancel transient playback owned by the current VM instruction.
## BGM is committed ambient state and is deliberately left untouched.
func cancel_pending_operations() -> void:
	_cancel_voice_playback()
	if sound_effect_player != null and sound_effect_player.is_playing():
		sound_effect_player.stop()
	var pending_generations: Array[int] = []
	pending_generations.assign(_voice_waiters.keys())
	for generation: int in pending_generations:
		_settle_voice_playback(generation, false)


func _begin_voice_playback(audio: AudioStream, track_result: bool) -> int:
	var previous_generation := _voice_generation
	var had_previous_playback := _voice_playing
	_voice_generation += 1
	var generation := _voice_generation
	if track_result:
		_voice_waiters[generation] = VoicePlaybackWaiter.new()

	_voice_playing = false
	if had_previous_playback:
		_stop_connected_voice_player()
		_settle_voice_playback(previous_generation, false)
		if generation != _voice_generation:
			_settle_voice_playback(generation, false)
			return generation if track_result else -1

	if not voice_player:
		push_error("没找到voice_player")
		voice_started.emit()
		_settle_voice_playback(generation, false)
		return generation if track_result else -1
	if audio == null:
		push_error("无法播放空的语音资源")
		voice_started.emit()
		_settle_voice_playback(generation, false)
		return generation if track_result else -1

	_ensure_voice_connection()
	voice_player.stream = audio
	_voice_playing = true
	voice_player.play()
	voice_started.emit()
	if not _did_voice_playback_start():
		_voice_playing = false
		_stop_connected_voice_player()
		_settle_voice_playback(generation, false)
	return generation


func _did_voice_playback_start() -> bool:
	return is_instance_valid(voice_player) and voice_player.playing


func _cancel_voice_playback() -> void:
	if not _voice_playing:
		if is_instance_valid(voice_player) and voice_player.is_playing():
			voice_player.stop()
		return
	var generation := _voice_generation
	_voice_playing = false
	_stop_connected_voice_player()
	_settle_voice_playback(generation, false)


func _stop_connected_voice_player() -> void:
	var player := (
		_connected_voice_player if is_instance_valid(_connected_voice_player) else voice_player
	)
	if is_instance_valid(player) and player.is_playing():
		player.stop()


func _settle_voice_playback(generation: int, completed: bool) -> void:
	var waiter := _voice_waiters.get(generation)
	if waiter == null:
		return
	waiter.settle(completed)


func _disconnect_audio_connections() -> void:
	if (
		is_instance_valid(_connected_background_music_player)
		and _connected_background_music_player.finished.is_connected(
			_on_background_music_player_finished
		)
	):
		_connected_background_music_player.finished.disconnect(_on_background_music_player_finished)
	if (
		is_instance_valid(_connected_voice_player)
		and _connected_voice_player.finished.is_connected(_on_voice_player_finished)
	):
		_connected_voice_player.finished.disconnect(_on_voice_player_finished)
	_connected_background_music_player = null
	_connected_voice_player = null


func _ensure_background_music_connection() -> void:
	if (
		_connected_background_music_player == background_music_player
		and _connected_background_music_player.finished.is_connected(
			_on_background_music_player_finished
		)
	):
		return
	if (
		is_instance_valid(_connected_background_music_player)
		and _connected_background_music_player.finished.is_connected(
			_on_background_music_player_finished
		)
	):
		_connected_background_music_player.finished.disconnect(_on_background_music_player_finished)
	_connected_background_music_player = background_music_player
	if not _connected_background_music_player.finished.is_connected(
		_on_background_music_player_finished
	):
		_connected_background_music_player.finished.connect(_on_background_music_player_finished)


func _ensure_voice_connection() -> void:
	if (
		_connected_voice_player == voice_player
		and _connected_voice_player.finished.is_connected(_on_voice_player_finished)
	):
		return
	if (
		is_instance_valid(_connected_voice_player)
		and _connected_voice_player.finished.is_connected(_on_voice_player_finished)
	):
		_connected_voice_player.finished.disconnect(_on_voice_player_finished)
	_connected_voice_player = voice_player
	if not _connected_voice_player.finished.is_connected(_on_voice_player_finished):
		_connected_voice_player.finished.connect(_on_voice_player_finished)


func _on_background_music_player_finished() -> void:
	if (
		_background_music_loop_enabled
		and is_instance_valid(background_music_player)
		and background_music_player.stream != null
	):
		background_music_player.play()


func _on_voice_player_finished() -> void:
	if not _voice_playing:
		return
	var generation := _voice_generation
	_voice_playing = false
	voice_finished.emit()
	_settle_voice_playback(generation, true)


## 播放音效的方法
func play_sound_effect(audio: AudioStream) -> void:
	if not sound_effect_player:
		push_error("没找到sound_effect_player")
		sound_effect_started.emit()
		return
	sound_effect_player.stop()
	sound_effect_player.stream = audio
	sound_effect_player.play()
	sound_effect_started.emit()


## 捕获可序列化的音频播放状态。只记录资源路径和播放游标，不保存节点引用。
func capture_state() -> Dictionary:
	return {
		"bgm": _capture_player(background_music_player, _background_music_loop_enabled),
		"voice": _capture_player(voice_player, false),
		"sound_effect": _capture_player(sound_effect_player, false),
	}


## 原子地恢复音频播放状态。无法加载的资源会停止对应播放器并返回 false。
func restore_state(state: Dictionary) -> bool:
	_cancel_voice_playback()
	var valid := true
	valid = _restore_player(background_music_player, state.get("bgm", {})) and valid
	valid = _restore_player(voice_player, state.get("voice", {})) and valid
	valid = _restore_player(sound_effect_player, state.get("sound_effect", {})) and valid
	_background_music_loop_enabled = bool(state.get("bgm", {}).get("loop", false))
	_voice_playing = voice_player != null and voice_player.playing
	if _voice_playing:
		_voice_generation += 1
	return valid


func _capture_player(player: AudioStreamPlayer, loop: bool) -> Dictionary:
	if player == null or player.stream == null:
		return {}
	return {
		"stream_path": player.stream.resource_path,
		"playing": player.playing,
		"position": player.get_playback_position() if player.playing else 0.0,
		"volume_db": player.volume_db,
		"pitch_scale": player.pitch_scale,
		"loop": loop,
	}


func _restore_player(player: AudioStreamPlayer, state: Dictionary) -> bool:
	if player == null:
		return state.is_empty()
	player.stop()
	if state.is_empty():
		player.stream = null
		return true
	var stream_path := String(state.get("stream_path", ""))
	if stream_path.is_empty() or not ResourceLoader.exists(stream_path, "AudioStream"):
		player.stream = null
		return false
	var stream := load(stream_path) as AudioStream
	if stream == null:
		player.stream = null
		return false
	player.stream = stream
	player.volume_db = float(state.get("volume_db", player.volume_db))
	player.pitch_scale = float(state.get("pitch_scale", player.pitch_scale))
	if bool(state.get("playing", false)):
		player.play(maxf(0.0, float(state.get("position", 0.0))))
	return true
