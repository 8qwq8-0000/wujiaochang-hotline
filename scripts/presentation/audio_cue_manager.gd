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

@export_group("Weapon Fire")
@export var service_pistol_fire_sounds: Array[AudioStream] = []
@export var scattergun_fire_sounds: Array[AudioStream] = []
@export var rail_cannon_fire_sounds: Array[AudioStream] = []

@export_group("Defense and Player State")
@export var block_sounds: Array[AudioStream] = []
@export var perfect_guard_energy_sounds: Array[AudioStream] = []
@export var player_hurt_sounds: Array[AudioStream] = []
@export var heavy_damage_sounds: Array[AudioStream] = []
@export var low_health_warning_sound: AudioStream
@export var low_health_heartbeat_sound: AudioStream
@export_range(0.5, 3.0, 0.05) var low_health_heartbeat_interval: float = 1.35

@export_group("Defeat Feedback")
@export var kill_confirm_sounds: Array[AudioStream] = []
@export var heavy_kill_sounds: Array[AudioStream] = []

@export_group("Priority Mix")
@export_range(0.0, 6.0, 0.5) var duck_depth_db: float = 2.5
@export_range(0.0, 0.2, 0.005) var duck_hold_seconds: float = 0.025
@export_range(0.01, 0.3, 0.005) var duck_recovery_seconds: float = 0.055

@export_group("Enemy Weapon Hits")
@export var service_pistol_hit_sounds: Array[AudioStream] = []
@export var scattergun_hit_sounds: Array[AudioStream] = []
@export var rail_cannon_hit_sounds: Array[AudioStream] = []
@export var light_metal_hit_sounds: Array[AudioStream] = []
@export var heavy_metal_hit_sounds: Array[AudioStream] = []
@export_range(0.0, 0.1, 0.005) var hit_merge_window: float = 0.035
@export_range(1, 16, 1) var max_hit_voices: int = 4
@export_range(0.0, 0.1, 0.005) var hit_pitch_jitter: float = 0.03
@export_range(0.0, 3.0, 0.1) var hit_volume_jitter_db: float = 1.0
@export_range(-12.0, 6.0, 0.5) var hit_core_volume_db: float = 1.5
@export_range(-24.0, 0.0, 0.5) var hit_material_volume_db: float = -7.5

@export_group("")
@export_range(0.0, 1.0, 0.01) var duplicate_cooldown: float = 0.05
@export_range(0.0, 10.0, 0.1) var reinforcement_cooldown: float = 3.0

var _last_played_at: Dictionary = {}
var _perfect_chain: int = 0
var _last_perfect_time: float = -10.0
var _variant_bags: Dictionary = {}
var _active_hit_voices: Array[AudioStreamPlayer] = []
var _rng := RandomNumberGenerator.new()
var _bound_player_ids: Dictionary = {}
var _low_health_active := false
var _low_health_timer := 0.0
var _duck_elapsed := -1.0
var _duck_base_levels: Dictionary = {}
var _duck_active_depth_db := 0.0
var _death_priority_until_usec := 0
var _last_kill_chain_stream: AudioStream
var _continuous_hurt_at: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.damage_resolved.connect(_on_damage_resolved)
		events.enemy_alerted.connect(_on_enemy_alerted)
		events.entity_defeated.connect(_on_entity_defeated)
		events.weapon_cue_requested.connect(_on_weapon_cue_requested)
		events.combat_moment_requested.connect(_on_combat_moment_requested)
	var feedback := get_node_or_null("../CombatFeedbackManager") as CombatFeedbackManager
	if feedback != null:
		feedback.kill_chain_feedback.connect(_on_kill_chain_feedback)
		feedback.kill_chain_ended.connect(_on_kill_chain_ended)
	get_tree().node_added.connect(_on_tree_node_added)
	call_deferred("_bind_existing_players")


func _process(delta: float) -> void:
	_tick_priority_duck(delta)
	if get_tree().paused or not _low_health_active:
		return
	_low_health_timer -= delta
	if _low_health_timer > 0.0:
		return
	_low_health_timer = low_health_heartbeat_interval
	_play_centered(low_health_heartbeat_sound, 1.0, &"low_health_heartbeat", &"CombatCue", -10.0, 0.5)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_low_health_pulse()


func _on_damage_resolved(result: DamageResult) -> void:
	if result.ignore_reason == DamageResult.IgnoreReason.INVULNERABLE and result.target is PlayerController:
		_play_phase_avoid(result)
		return
	if result.fatal_damage_prevented and result.target is PlayerController:
		_play_circuit_breaker(result)
		return
	if result.perfect:
		var now := Time.get_ticks_msec() / 1000.0
		_perfect_chain = _perfect_chain + 1 if now - _last_perfect_time <= 1.2 else 1
		_last_perfect_time = now
		_play_guard_body(result, true)
		var stage := _perfect_guard_stage(_perfect_chain)
		var energy_pitch := 1.0 + (stage - 1) * 0.06
		var energy_volume := -3.5 + (stage - 1) * 0.5
		if perfect_guard_energy_sounds.is_empty():
			_play(perfect_guard_sound, energy_pitch, &"perfect")
		else:
			var energy := _pick_variant(&"perfect_guard_energy", perfect_guard_energy_sounds)
			_play_centered(energy, energy_pitch, &"perfect_energy", &"CombatCue", energy_volume)
		_duck_priority_mix()
	elif result.outcome == DamageResult.Outcome.BLOCKED:
		_play_guard_body(result, false)
	elif result.final_damage > 0 and result.target is PlayerController:
		var player := result.target as PlayerController
		_bind_player(player)
		if Time.get_ticks_usec() >= _death_priority_until_usec:
			_play_player_hurt(player, result)
	elif result.final_damage > 0 and result.target is EnemyController:
		_play_enemy_weapon_hit(result)


func _perfect_guard_stage(chain: int) -> int:
	return clampi(chain, 1, 5)


func _play_guard_body(result: DamageResult, perfect: bool) -> void:
	var position := _result_world_position(result)
	if block_sounds.is_empty():
		_play(block_sound, 1.0, &"perfect_body" if perfect else &"block")
		return
	var key := &"perfect_guard_body" if perfect else &"block_body"
	var stream := _pick_variant(key, block_sounds)
	var pitch := 0.84 if result.absorbed_damage > 0 and not perfect else 1.0
	_play_spatial(stream, position, key, -1.0, &"CombatCue", pitch, 0.5 if perfect else 0.0)


func _play_player_hurt(player: PlayerController, result: DamageResult) -> void:
	_stop_hit_voices()
	var damage := result.final_damage
	var heavy := _is_heavy_player_damage(player, damage)
	var cue_scale := _continuous_hurt_scale(result)
	var source_position := _hurt_source_position(result, player)
	var pitch := _hurt_pitch(result)
	if not player_hurt_sounds.is_empty():
		var stream := _pick_variant(&"player_hurt", player_hurt_sounds)
		_play_spatial(stream, source_position, &"player_hurt", -1.0, &"CombatCue", pitch, linear_to_db(cue_scale))
	else:
		_play(hit_sound, 1.0, &"hit")
	# A quieter centered layer keeps body impact readable even when the source is
	# at the edge of the stereo field. It deliberately contains no vocalization.
	_play_centered(hit_sound, pitch, &"player_hurt_body", &"CombatCue", -9.0 + linear_to_db(cue_scale), 0.0)
	if not heavy or heavy_damage_sounds.is_empty():
		return
	_duck_priority_mix(4.0)
	var heavy_stream := _pick_variant(&"heavy_player_damage", heavy_damage_sounds)
	_play_centered(heavy_stream, 1.0, &"heavy_player_damage", &"CombatCue", -2.0)


func _continuous_hurt_scale(result: DamageResult) -> float:
	if result.packet == null or not result.packet.is_continuous_damage:
		return 1.0
	var source_id := result.packet.source.get_instance_id() if is_instance_valid(result.packet.source) else 0
	var key := "%d:%s" % [source_id, String(result.packet.damage_type)]
	var now := Time.get_ticks_usec() / 1_000_000.0
	var scale := 0.34 if now - float(_continuous_hurt_at.get(key, -10.0)) < 0.85 else 1.0
	_continuous_hurt_at[key] = now
	return scale


func _hurt_source_position(result: DamageResult, player: PlayerController) -> Vector2:
	if result.packet == null:
		return player.global_position
	var direction := result.packet.source_position - player.global_position
	if direction.is_zero_approx() and not result.packet.travel_direction.is_zero_approx():
		direction = -result.packet.travel_direction
	return player.global_position + (direction.normalized() if not direction.is_zero_approx() else Vector2.ZERO) * 110.0


func _hurt_pitch(result: DamageResult) -> float:
	if result.packet == null:
		return 1.0
	if result.packet.damage_type == &"explosive" or result.packet.is_area_damage:
		return 0.88
	if result.packet.is_melee:
		return 0.95
	return 1.06 if result.packet.is_projectile else 1.0


func _play_phase_avoid(result: DamageResult) -> void:
	var stream := _pick_variant(&"phase_avoid", perfect_guard_energy_sounds) if not perfect_guard_energy_sounds.is_empty() else block_sound
	var player := result.target as PlayerController
	var position := _hurt_source_position(result, player) if player != null else _result_world_position(result)
	_play_spatial(stream, position, &"phase_avoid", 0.05, &"CombatCue", 1.15, -8.0)


func _play_circuit_breaker(result: DamageResult) -> void:
	_stop_hit_voices()
	_duck_priority_mix(5.0)
	var reset := _pick_variant(&"circuit_reset", perfect_guard_energy_sounds) if not perfect_guard_energy_sounds.is_empty() else block_sound
	_play_centered(reset, 0.76, &"circuit_reset", &"CombatCue", 1.5, 0.0)
	if not heavy_damage_sounds.is_empty():
		var cutoff := _pick_variant(&"circuit_cutoff", heavy_damage_sounds)
		_play_centered(cutoff, 0.9, &"circuit_cutoff", &"CombatCue", -5.0, 0.0)


func _is_heavy_player_damage(player: PlayerController, damage: int) -> bool:
	if player == null or player.health == null:
		return damage >= 2
	var critical_threshold := maxi(1, ceili(player.health.max_health * 0.34))
	return damage >= 2 or player.health.current_health <= critical_threshold


func _result_world_position(result: DamageResult) -> Vector2:
	return (result.target as Node2D).global_position if result.target is Node2D else Vector2.ZERO


func _play_enemy_weapon_hit(result: DamageResult) -> void:
	if result.packet == null or not is_instance_valid(result.target):
		return
	var weapon_id := result.packet.weapon_id
	var core_sounds := _weapon_hit_sounds(weapon_id)
	if core_sounds.is_empty():
		return
	_prune_hit_voices()
	if _active_hit_voices.size() >= max_hit_voices:
		return
	var now := Time.get_ticks_usec() / 1000000.0
	var merge_key := StringName("weapon_hit:%s" % weapon_id)
	if now - float(_last_played_at.get(merge_key, -10.0)) < hit_merge_window:
		return
	_last_played_at[merge_key] = now
	var pitch := _rng.randf_range(1.0 - hit_pitch_jitter, 1.0 + hit_pitch_jitter)
	var core := _pick_variant(merge_key, core_sounds)
	_play_hit_core(core, pitch)
	var enemy := result.target as EnemyController
	var material_sounds := _material_hit_sounds(enemy.profile)
	if not material_sounds.is_empty():
		var material_key := StringName("material_hit:%s" % int(enemy.profile.impact_material))
		var material := _pick_variant(material_key, material_sounds)
		_play_hit_material(material, enemy.global_position, pitch)


func _weapon_hit_sounds(weapon_id: StringName) -> Array[AudioStream]:
	match weapon_id:
		&"service_pistol":
			return service_pistol_hit_sounds
		&"scattergun":
			return scattergun_hit_sounds
		&"rail_cannon":
			return rail_cannon_hit_sounds
	var empty: Array[AudioStream] = []
	return empty


func _material_hit_sounds(profile: EnemyProfile) -> Array[AudioStream]:
	if profile != null:
		match profile.impact_material:
			EnemyProfile.ImpactMaterial.LIGHT_METAL:
				return light_metal_hit_sounds
			EnemyProfile.ImpactMaterial.HEAVY_METAL:
				return heavy_metal_hit_sounds
	var empty: Array[AudioStream] = []
	return empty


func _pick_variant(key: StringName, sounds: Array[AudioStream]) -> AudioStream:
	var bag: Array = _variant_bags.get(key, [])
	if bag.is_empty():
		for index in sounds.size():
			bag.append(index)
		for index in range(bag.size() - 1, 0, -1):
			var swap_index := _rng.randi_range(0, index)
			var value: Variant = bag[index]
			bag[index] = bag[swap_index]
			bag[swap_index] = value
	var selected := int(bag.pop_back())
	_variant_bags[key] = bag
	return sounds[selected]


func _play_hit_core(stream: AudioStream, pitch: float) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"CombatCue"
	player.pitch_scale = pitch
	player.volume_db = hit_core_volume_db + _rng.randf_range(-hit_volume_jitter_db, hit_volume_jitter_db)
	add_child(player)
	_active_hit_voices.append(player)
	player.finished.connect(_on_hit_voice_finished.bind(player), CONNECT_ONE_SHOT)
	player.play()


func _play_hit_material(stream: AudioStream, world_position: Vector2, pitch: float) -> void:
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.bus = &"CombatCue"
	player.pitch_scale = pitch
	player.volume_db = hit_material_volume_db + _rng.randf_range(-hit_volume_jitter_db, hit_volume_jitter_db)
	player.max_distance = 900.0
	player.attenuation = 0.65
	add_child(player)
	player.global_position = world_position
	player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)
	player.play()


func _on_hit_voice_finished(player: AudioStreamPlayer) -> void:
	_active_hit_voices.erase(player)
	player.queue_free()


func _prune_hit_voices() -> void:
	for index in range(_active_hit_voices.size() - 1, -1, -1):
		var player := _active_hit_voices[index]
		if not is_instance_valid(player) or not player.playing:
			_active_hit_voices.remove_at(index)
			if is_instance_valid(player):
				player.queue_free()


func _stop_hit_voices() -> void:
	for player in _active_hit_voices.duplicate():
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_active_hit_voices.clear()


func _on_tree_node_added(node: Node) -> void:
	if node is PlayerController:
		call_deferred("_bind_player", node)


func _bind_existing_players() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		if node is PlayerController:
			_bind_player(node)


func _bind_player(player: PlayerController) -> void:
	if not is_instance_valid(player) or player.health == null:
		return
	var player_id := player.get_instance_id()
	if _bound_player_ids.has(player_id):
		return
	_bound_player_ids[player_id] = true
	player.health_changed.connect(_on_player_health_changed.bind(player))
	player.player_died.connect(_on_player_died)
	_on_player_health_changed(player.health.current_health, player.health.max_health, 0, player)


func _on_player_health_changed(current: int, maximum: int, _delta: int, player: PlayerController) -> void:
	if not is_instance_valid(player) or current <= 0:
		_low_health_active = false
		return
	var critical_threshold := maxi(1, ceili(maximum * 0.34))
	var critical := current <= critical_threshold
	if critical and not _low_health_active:
		_low_health_active = true
		_low_health_timer = 0.85
		_play_centered(low_health_warning_sound, 1.0, &"low_health_warning", &"CombatCue", -3.0, 0.5)
	elif not critical:
		_low_health_active = false
		_low_health_timer = 0.0


func play_hotline_dial(variant: int = 0) -> void:
	if hotline_dial_sounds.is_empty():
		return
	var index := posmod(variant, hotline_dial_sounds.size())
	_play_ui(hotline_dial_sounds[index])


func play_hotline_connect() -> void:
	_play_ui(hotline_connect_sound)


func preview_combat_cue() -> void:
	var stream := _pick_variant(&"settings_preview", block_sounds) if not block_sounds.is_empty() else block_sound
	_play_centered(stream, 1.0, &"settings_preview", &"CombatCue", -4.0, 0.0)


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
	if cue == &"fire":
		var variants := _weapon_fire_sounds(weapon_id)
		if not variants.is_empty():
			var stream := _pick_variant(key, variants)
			var accent := weapon_id == &"rail_cannon"
			if accent:
				_duck_priority_mix()
			_play_spatial(
				stream,
				world_position,
				key,
				-1.0,
				&"SFX",
				_rng.randf_range(0.985, 1.015)
			)
			return
	var stream := weapon_cues.get(key, weapon_cues.get(String(key))) as AudioStream
	_play_spatial(stream, world_position, key)


func _weapon_fire_sounds(weapon_id: StringName) -> Array[AudioStream]:
	match weapon_id:
		&"service_pistol":
			return service_pistol_fire_sounds
		&"scattergun":
			return scattergun_fire_sounds
		&"rail_cannon":
			return rail_cannon_fire_sounds
	var empty: Array[AudioStream] = []
	return empty


func _on_entity_defeated(entity: Node) -> void:
	if Time.get_ticks_usec() < _death_priority_until_usec or not is_instance_valid(entity) or not entity is EnemyController:
		return
	var enemy := entity as EnemyController
	_play_spatial(enemy_death_sound, enemy.global_position, &"enemy_death")
	if _is_heavy_enemy(enemy) and not heavy_kill_sounds.is_empty():
		var weight := _pick_variant(&"heavy_kill", heavy_kill_sounds)
		_play_spatial(weight, enemy.global_position, &"heavy_kill_body", 0.04, &"CombatCue", 1.0, -4.0)


func _on_kill_chain_feedback(
	world_position: Vector2,
	stage: int,
	weapon_id: StringName,
	offscreen: bool,
	boss_final: bool,
	suppressed: bool
) -> void:
	if kill_confirm_sounds.is_empty():
		return
	var clamped_stage := clampi(stage, 1, CombatFeedbackManager.KILL_CHAIN_MAX_STAGE)
	var confirm := _pick_variant(&"kill_confirm", kill_confirm_sounds)
	_last_kill_chain_stream = confirm
	if boss_final:
		_play_centered(confirm, 0.96, &"boss_kill_chain_layer", &"CombatCue", -6.0, 0.0)
		if not heavy_kill_sounds.is_empty():
			var finale := _pick_variant(&"boss_final", heavy_kill_sounds)
			_play_centered(finale, 0.88, &"boss_final", &"CombatCue", 1.5, 0.0)
		_duck_priority_mix(6.0)
		return
	var pitch := 1.0 + (clamped_stage - 1) * 0.045 + _weapon_kill_pitch_offset(weapon_id)
	var volume := -1.5 + (clamped_stage - 1) * 0.55
	if suppressed:
		volume -= 8.0
	if offscreen:
		_play_spatial(confirm, world_position, &"kill_chain_offscreen", 0.0, &"CombatCue", pitch, volume - 2.0)
	else:
		_play_centered(confirm, pitch, &"kill_chain", &"CombatCue", volume, 0.0)
	if not suppressed:
		_play_weapon_kill_layer(weapon_id, pitch)
	if clamped_stage >= 3 and not suppressed and not heavy_kill_sounds.is_empty():
		var weight := _pick_variant(&"kill_chain_weight", heavy_kill_sounds)
		_play_centered(weight, 0.94 + clamped_stage * 0.015, &"kill_chain_weight", &"CombatCue", -7.0 + clamped_stage * 0.7, 0.0)
		_duck_priority_mix(3.0 + (clamped_stage - 3) * 0.5)


func _on_kill_chain_ended(stage: int) -> void:
	if _last_kill_chain_stream == null or stage < 2 or Time.get_ticks_usec() < _death_priority_until_usec:
		return
	_play_centered(_last_kill_chain_stream, 0.82, &"kill_chain_resolve", &"CombatCue", -9.0, 0.0)
	_last_kill_chain_stream = null


func _weapon_kill_pitch_offset(weapon_id: StringName) -> float:
	match weapon_id:
		&"scattergun":
			return -0.018
		&"rail_cannon":
			return 0.025
		&"baton", &"initial_baton":
			return -0.01
	return 0.0


func _play_weapon_kill_layer(weapon_id: StringName, pitch: float) -> void:
	var variants := _weapon_hit_sounds(weapon_id)
	if variants.is_empty():
		return
	var stream := _pick_variant(StringName("kill_weapon:%s" % weapon_id), variants)
	_play_centered(stream, pitch, StringName("kill_weapon:%s" % weapon_id), &"SFX", -10.0, 0.0)


func _on_combat_moment_requested(kind: StringName, world_position: Vector2) -> void:
	if Time.get_ticks_usec() < _death_priority_until_usec or kind not in [&"boss_phase", &"boss_break"] or heavy_kill_sounds.is_empty():
		return
	var stream := _pick_variant(kind, heavy_kill_sounds)
	var pitch := 0.92 if kind == &"boss_break" else 1.0
	var volume := -0.5 if kind == &"boss_break" else -2.5
	_play_spatial(stream, world_position, kind, 0.0, &"CombatCue", pitch, volume)
	_duck_priority_mix(5.0 if kind == &"boss_break" else 4.0)


func _on_player_died(_packet: DamagePacket) -> void:
	_death_priority_until_usec = Time.get_ticks_usec() + 1_000_000
	_low_health_active = false
	_low_health_timer = 0.0
	_last_kill_chain_stream = null
	_stop_transient_combat_audio()
	_duck_priority_mix(6.0)
	var death_stream := _pick_variant(&"player_death", heavy_damage_sounds) if not heavy_damage_sounds.is_empty() else hit_sound
	_play_centered(death_stream, 0.82, &"player_death", &"CombatCue", 1.0, 0.0)


func _stop_transient_combat_audio() -> void:
	_stop_hit_voices()
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
			child.stop()
			child.queue_free()


func _is_heavy_enemy(enemy: EnemyController) -> bool:
	return enemy != null and enemy.profile != null and enemy.profile.impact_material == EnemyProfile.ImpactMaterial.HEAVY_METAL


func _on_enemy_alerted(_enemy: Node, world_position: Vector2) -> void:
	_play_spatial(reinforcement_approach_sound, world_position, &"reinforcement", reinforcement_cooldown)


func _play_spatial(
	stream: AudioStream,
	world_position: Vector2,
	key: StringName,
	cooldown: float = -1.0,
	bus: StringName = &"SFX",
	pitch: float = 1.0,
	volume_db: float = 0.0
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
	player.bus = bus
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.max_distance = 900.0
	player.attenuation = 0.65
	player.global_position = world_position
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _play_centered(
	stream: AudioStream,
	pitch: float,
	key: StringName,
	bus: StringName = &"SFX",
	volume_db: float = 0.0,
	cooldown: float = -1.0
) -> void:
	if stream == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var minimum_delay := duplicate_cooldown if cooldown < 0.0 else cooldown
	if now - float(_last_played_at.get(key, -10.0)) < minimum_delay:
		return
	_last_played_at[key] = now
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.pitch_scale = pitch
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free, CONNECT_ONE_SHOT)
	player.play()


func _duck_priority_mix(depth_db: float = -1.0) -> void:
	var requested_depth := duck_depth_db if depth_db < 0.0 else depth_db
	if requested_depth <= 0.0:
		return
	if _duck_elapsed < 0.0:
		_duck_base_levels.clear()
		for bus_name: StringName in [&"SFX", &"Music", &"Dialogue"]:
			var bus_index := AudioServer.get_bus_index(bus_name)
			if bus_index >= 0:
				_duck_base_levels[bus_name] = AudioServer.get_bus_volume_db(bus_index)
	_duck_active_depth_db = maxf(_duck_active_depth_db, requested_depth)
	_duck_elapsed = 0.0
	for bus_name: StringName in _duck_base_levels:
		var bus_index := AudioServer.get_bus_index(bus_name)
		AudioServer.set_bus_volume_db(bus_index, float(_duck_base_levels[bus_name]) - _duck_depth_for_bus(bus_name))


func _tick_priority_duck(delta: float) -> void:
	if _duck_elapsed < 0.0:
		return
	_duck_elapsed += delta
	var recovery_progress := clampf(
		(_duck_elapsed - duck_hold_seconds) / maxf(duck_recovery_seconds, 0.001),
		0.0,
		1.0
	)
	for bus_name: StringName in _duck_base_levels:
		var bus_index := AudioServer.get_bus_index(bus_name)
		var base_db := float(_duck_base_levels[bus_name])
		AudioServer.set_bus_volume_db(bus_index, lerpf(base_db - _duck_depth_for_bus(bus_name), base_db, recovery_progress))
	if recovery_progress >= 1.0:
		_duck_elapsed = -1.0
		_duck_base_levels.clear()
		_duck_active_depth_db = 0.0


func _duck_depth_for_bus(bus_name: StringName) -> float:
	return minf(_duck_active_depth_db, 1.5) if bus_name == &"Dialogue" else _duck_active_depth_db


func _restore_ducked_buses() -> void:
	for bus_name: StringName in _duck_base_levels:
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index >= 0:
			AudioServer.set_bus_volume_db(bus_index, float(_duck_base_levels[bus_name]))
	_duck_base_levels.clear()
	_duck_elapsed = -1.0
	_duck_active_depth_db = 0.0


func _play_ui(stream: AudioStream) -> void:
	if stream == null:
		return
	var sound_manager := get_node_or_null("/root/SoundManager")
	if sound_manager != null:
		sound_manager.play_ui_sound(stream)


func _exit_tree() -> void:
	_restore_ducked_buses()
