class_name AudioCueManager
extends Node

## 只做项目事件到既有 SoundManager 的映射。
@export var perfect_guard_sound: AudioStream
@export var block_sound: AudioStream
@export var hit_sound: AudioStream
@export var enemy_death_sound: AudioStream
@export var reinforcement_approach_sound: AudioStream
@export var weapon_cues: Dictionary = {}
@export var hotline_dial_sounds: Array[AudioStream] = []
@export var hotline_connect_sound: AudioStream
@export_range(0.0, 1.0, 0.01) var duplicate_cooldown: float = 0.05
@export_range(0.0, 10.0, 0.1) var reinforcement_cooldown: float = 3.0

var _last_played_at: Dictionary = {}
var _perfect_chain: int = 0
var _last_perfect_time: float = -10.0


func _ready() -> void:
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.damage_resolved.connect(_on_damage_resolved)
		events.enemy_alerted.connect(_on_enemy_alerted)
		events.entity_defeated.connect(_on_entity_defeated)
		events.weapon_cue_requested.connect(_on_weapon_cue_requested)


func _on_damage_resolved(result: DamageResult) -> void:
	if result.perfect:
		var now := Time.get_ticks_msec() / 1000.0
		_perfect_chain = _perfect_chain + 1 if now - _last_perfect_time <= 1.2 else 1
		_last_perfect_time = now
		_play(perfect_guard_sound, minf(1.0 + (_perfect_chain - 1) * 0.08, 1.4), &"perfect")
	elif result.outcome == DamageResult.Outcome.BLOCKED:
		_play(block_sound, 1.0, &"block")
	elif result.final_damage > 0 and result.target is PlayerController:
		_play(hit_sound, 1.0, &"hit")


func play_hotline_dial(variant: int = 0) -> void:
	if hotline_dial_sounds.is_empty():
		return
	var index := posmod(variant, hotline_dial_sounds.size())
	_play_ui(hotline_dial_sounds[index])


func play_hotline_connect() -> void:
	_play_ui(hotline_connect_sound)


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
	_play_spatial(stream, world_position, key)


func _on_entity_defeated(entity: Node) -> void:
	if not is_instance_valid(entity) or not entity is EnemyController:
		return
	_play_spatial(enemy_death_sound, entity.global_position, &"enemy_death")


func _on_enemy_alerted(_enemy: Node, world_position: Vector2) -> void:
	_play_spatial(reinforcement_approach_sound, world_position, &"reinforcement", reinforcement_cooldown)


func _play_spatial(
	stream: AudioStream,
	world_position: Vector2,
	key: StringName,
	cooldown: float = -1.0
) -> void:
	if stream == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var minimum_delay := duplicate_cooldown if cooldown < 0.0 else cooldown
	if now - float(_last_played_at.get(key, -10.0)) < minimum_delay:
		return
	_last_played_at[key] = now
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.global_position = world_position
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _play_ui(stream: AudioStream) -> void:
	if stream == null:
		return
	var sound_manager := get_node_or_null("/root/SoundManager")
	if sound_manager != null:
		sound_manager.play_ui_sound(stream)
