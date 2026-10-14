class_name AudioCueManager
extends Node

## 只做项目事件到既有 SoundManager 的映射；没有引入任何音频素材。
@export var perfect_guard_sound: AudioStream
@export var hit_sound: AudioStream
@export var weapon_cues: Dictionary = {}
@export_range(0.0, 1.0, 0.01) var duplicate_cooldown: float = 0.05

var _last_played_at: Dictionary = {}
var _perfect_chain: int = 0
var _last_perfect_time: float = -10.0


func _ready() -> void:
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.damage_resolved.connect(_on_damage_resolved)
		events.weapon_cue_requested.connect(_on_weapon_cue_requested)


func _on_damage_resolved(result: DamageResult) -> void:
	if result.perfect:
		var now := Time.get_ticks_msec() / 1000.0
		_perfect_chain = _perfect_chain + 1 if now - _last_perfect_time <= 1.2 else 1
		_last_perfect_time = now
		_play(perfect_guard_sound, minf(1.0 + (_perfect_chain - 1) * 0.08, 1.4), &"perfect")
	elif result.final_damage > 0:
		_play(hit_sound, 1.0, &"hit")


func _play(stream: AudioStream, pitch: float, key: StringName) -> void:
	if stream == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played_at.get(key, -10.0)) < duplicate_cooldown:
		return
	_last_played_at[key] = now
	var sound_manager := get_node_or_null("/root/SoundManager")
	if sound_manager != null:
		sound_manager.play_sound_with_pitch(stream, pitch)


func _on_weapon_cue_requested(weapon_id: StringName, cue: StringName, world_position: Vector2) -> void:
	var key := StringName("%s:%s" % [weapon_id, cue])
	var stream := weapon_cues.get(key, weapon_cues.get(String(key))) as AudioStream
	if stream == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played_at.get(key, -10.0)) < duplicate_cooldown:
		return
	_last_played_at[key] = now
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.global_position = world_position
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
