class_name CombatMusicController
extends Node

signal cyberpsychosis_insert_started
signal cyberpsychosis_insert_ended

enum PlaybackMode {
	SILENT,
	REGULAR,
	BOSS,
}

@export var regular_tracks: Array[AudioStream] = []
@export var boss_phase_tracks: Array[AudioStream] = []
@export var cyberpsychosis_insert: AudioStream
@export_range(0.0, 5.0, 0.05) var crossfade_duration: float = 1.25
@export_range(0.0, 5.0, 0.05) var stop_fade_duration: float = 1.0

var _mode: PlaybackMode = PlaybackMode.SILENT
var _regular_index: int = 0
var _boss_phase: int = 0
var _current_stream: AudioStream
var _current_player: AudioStreamPlayer
var _finished_callback: Callable
var _playback_generation: int = 0
var _run_manager: Node
var _sound_manager: Node
var _insert_player: AudioStreamPlayer
var _insert_tween: Tween
var _base_bus_tween: Tween


func _ready() -> void:
	_run_manager = get_node_or_null("/root/RunManager")
	_sound_manager = get_node_or_null("/root/SoundManager")
	_insert_player = AudioStreamPlayer.new()
	_insert_player.name = "CyberpsychosisInsert"
	_insert_player.stream = cyberpsychosis_insert
	_insert_player.bus = &"Music"
	_insert_player.volume_db = -80.0
	_insert_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_insert_player)
	_insert_player.finished.connect(_on_insert_finished)
	var psychosis := get_node_or_null("../CyberpsychosisScreen") as CyberpsychosisScreen
	if psychosis != null:
		psychosis.music_cue_requested.connect(_on_insert_requested)
		psychosis.music_stop_requested.connect(_stop_music)
		cyberpsychosis_insert_started.connect(psychosis._on_music_started)
		cyberpsychosis_insert_ended.connect(psychosis._on_music_ended)
	var scene_flow := get_node_or_null("../SceneFlow")
	if scene_flow != null:
		scene_flow.load_started.connect(_on_scene_loading)
	if _run_manager == null:
		return
	_run_manager.mandatory_enemy_count_changed.connect(_on_mandatory_enemy_count_changed)
	_on_mandatory_enemy_count_changed(_run_manager.mandatory_enemies_remaining)


func _exit_tree() -> void:
	if _run_manager != null and _run_manager.mandatory_enemy_count_changed.is_connected(_on_mandatory_enemy_count_changed):
		_run_manager.mandatory_enemy_count_changed.disconnect(_on_mandatory_enemy_count_changed)
	if is_instance_valid(_insert_tween):
		_insert_tween.kill()
	if is_instance_valid(_base_bus_tween):
		_base_bus_tween.kill()
	if _insert_player != null:
		_insert_player.stop()
	_disconnect_finished_callback()
	if _sound_manager != null:
		_sound_manager.stop_music(stop_fade_duration)
	_set_base_bus_db(0.0)


func start_regular_combat() -> void:
	if regular_tracks.is_empty():
		return
	if _mode == PlaybackMode.REGULAR and _is_current_stream_playing():
		return
	_boss_phase = 0
	_mode = PlaybackMode.REGULAR
	_regular_index = posmod(_regular_index, regular_tracks.size())
	_play_track(regular_tracks[_regular_index])


func start_boss_phase(phase: int) -> void:
	if phase < 1 or phase > boss_phase_tracks.size():
		push_warning("无效的 BOSS 音乐阶段：%s" % phase)
		return
	if _mode == PlaybackMode.BOSS and _boss_phase == phase and _is_current_stream_playing():
		return
	_mode = PlaybackMode.BOSS
	_boss_phase = phase
	_play_track(boss_phase_tracks[phase - 1])


func end_boss_music() -> void:
	if _run_manager != null and _run_manager.mandatory_enemies_remaining > 0:
		_mode = PlaybackMode.SILENT
		start_regular_combat()


func stop_combat_music() -> void:
	_boss_phase = 0
	_stop_music()


func get_playback_mode() -> PlaybackMode:
	return _mode


func get_boss_phase() -> int:
	return _boss_phase


func get_current_track_path() -> String:
	return _current_stream.resource_path if _current_stream != null else ""


func _on_mandatory_enemy_count_changed(remaining: int) -> void:
	if _mode == PlaybackMode.BOSS:
		return
	if remaining > 0:
		start_regular_combat()


func _on_scene_loading(_scene_path: String) -> void:
	_stop_music()


func _play_track(stream: AudioStream) -> void:
	if stream == null:
		push_warning("战斗音乐资源为空")
		return
	if _sound_manager == null:
		push_warning("SoundManager 不存在，无法播放战斗音乐")
		return
	_disconnect_finished_callback()
	_current_stream = stream
	_playback_generation += 1
	var generation := _playback_generation
	var player := _sound_manager.play_music(stream, crossfade_duration, "CombatBase") as AudioStreamPlayer
	if player != null:
		_current_player = player
		_finished_callback = _on_track_finished.bind(generation)
		player.finished.connect(_finished_callback, CONNECT_ONE_SHOT)


func _stop_music() -> void:
	_stop_insert()
	_disconnect_finished_callback()
	_playback_generation += 1
	_mode = PlaybackMode.SILENT
	_current_stream = null
	if _sound_manager != null:
		_sound_manager.stop_music(stop_fade_duration)


func _on_insert_requested() -> void:
	if _mode == PlaybackMode.SILENT or not _is_current_stream_playing() or cyberpsychosis_insert == null or _insert_player.playing:
		return
	if is_instance_valid(_insert_tween):
		_insert_tween.kill()
	_insert_player.volume_db = -80.0
	_insert_player.play(0.0)
	cyberpsychosis_insert_started.emit()
	_insert_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_insert_tween.tween_property(_insert_player, "volume_db", 0.0, 0.4)
	_fade_base_bus(-12.0, 0.4)


func _stop_insert() -> void:
	if _insert_player == null:
		return
	if is_instance_valid(_insert_tween):
		_insert_tween.kill()
	if _insert_player.playing:
		_insert_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_insert_tween.tween_property(_insert_player, "volume_db", -80.0, 0.45)
		_insert_tween.tween_callback(_finish_insert)
	_fade_base_bus(0.0, 0.45)


func _on_insert_finished() -> void:
	cyberpsychosis_insert_ended.emit()
	_fade_base_bus(0.0, 0.45)


func _finish_insert() -> void:
	_insert_player.stop()
	cyberpsychosis_insert_ended.emit()


func _fade_base_bus(target_db: float, duration: float) -> void:
	var bus := AudioServer.get_bus_index(&"CombatBase")
	if bus < 0:
		return
	if is_instance_valid(_base_bus_tween):
		_base_bus_tween.kill()
	_base_bus_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_base_bus_tween.tween_method(_set_base_bus_db, AudioServer.get_bus_volume_db(bus), target_db, duration)


func _set_base_bus_db(value: float) -> void:
	var bus := AudioServer.get_bus_index(&"CombatBase")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, value)


func _on_track_finished(generation: int) -> void:
	_current_player = null
	_finished_callback = Callable()
	if generation != _playback_generation:
		return
	match _mode:
		PlaybackMode.REGULAR:
			_regular_index = (_regular_index + 1) % regular_tracks.size()
			_play_track(regular_tracks[_regular_index])
		PlaybackMode.BOSS:
			_play_track(boss_phase_tracks[_boss_phase - 1])


func _is_current_stream_playing() -> bool:
	if _current_stream == null:
		return false
	return _sound_manager != null and _sound_manager.is_music_playing(_current_stream)


func _disconnect_finished_callback() -> void:
	if is_instance_valid(_current_player) and _finished_callback.is_valid():
		if _current_player.finished.is_connected(_finished_callback):
			_current_player.finished.disconnect(_finished_callback)
	_current_player = null
	_finished_callback = Callable()
