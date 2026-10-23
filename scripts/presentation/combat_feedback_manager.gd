class_name CombatFeedbackManager
extends Node

signal kill_chain_feedback(world_position: Vector2, stage: int, weapon_id: StringName, offscreen: bool, boss_final: bool, suppressed: bool)
signal kill_chain_ended(stage: int)

## Centralizes combat timing and camera feedback. Damage, collision and real
## knockback remain gameplay-owned; this node only changes presentation.
const MERGE_WINDOW_USEC := 80_000
const LOCAL_HOLD_SECONDS := 0.025
const GLOBAL_TIME_SCALE := 0.16
const KILL_MERGE_WINDOW_USEC := 80_000
const KILL_FEEDBACK_DELAY_USEC := 45_000
const KILL_CHAIN_TIMEOUT_USEC := 1_650_000
const KILL_CHAIN_MAX_STAGE := 5
const PLAYER_HURT_PRIORITY_USEC := 180_000

var _slow_window_started_usec := 0
var _slow_until_usec := 0
var _strongest_duration_usec := 0
var _saved_time_scale := 1.0
var _time_scale_owned := false
var _kill_chain_count := 0
var _kill_chain_deadline_usec := 0
var _pending_kill: Dictionary = {}
var _last_player_hurt_usec := -1_000_000
var _bound_player_ids: Dictionary = {}
var _death_cleanup_at_usec := 0
var _feedback_groups: Dictionary = {}
var _continuous_player_hurt_at: Dictionary = {}
var _camera_zoom_tween: Tween
var _camera_zoom_base := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var events := get_node_or_null("/root/CombatEvents")
	if events == null:
		return
	events.damage_resolved.connect(_on_damage_resolved)
	events.weapon_cue_requested.connect(_on_weapon_cue_requested)
	events.room_cleared.connect(func(_room: Node) -> void: _reset_kill_chain(false))
	events.floor_cleared.connect(func() -> void: _reset_kill_chain(false))
	events.combat_moment_requested.connect(_on_combat_moment_requested)
	get_tree().node_added.connect(_on_tree_node_added)
	call_deferred("_bind_existing_players")
	var scene_flow := get_node_or_null("../SceneFlow")
	if scene_flow != null and scene_flow.has_signal("scene_swapped"):
		scene_flow.scene_swapped.connect(func(_scene: Node, _payload: Dictionary) -> void: _reset_kill_chain(false))


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _time_scale_owned and now >= _slow_until_usec:
		_restore_time_scale()
	if not _pending_kill.is_empty() and now >= int(_pending_kill.get("emit_at", 0)):
		_emit_pending_kill()
	if _kill_chain_count > 0 and _pending_kill.is_empty() and now >= _kill_chain_deadline_usec:
		_reset_kill_chain(true)
	if _death_cleanup_at_usec > 0 and now >= _death_cleanup_at_usec:
		_death_cleanup_at_usec = 0
		var player := get_tree().get_first_node_in_group(&"player")
		if is_instance_valid(player) and player.has_method("clear_camera_shake"):
			player.clear_camera_shake()


func _exit_tree() -> void:
	_restore_time_scale()


func _on_damage_resolved(result: DamageResult) -> void:
	if result == null or not is_instance_valid(result.target):
		return
	var direction := _impact_direction(result)
	if result.outcome in [DamageResult.Outcome.PERFECT_BLOCKED, DamageResult.Outcome.REFLECTED]:
		_request_global_slow(0.06)
		_request_camera_shake(direction, 0.55)
		_play_reactions(result, direction, 0.7)
		return
	if result.fatal_damage_prevented and result.target is PlayerController:
		_last_player_hurt_usec = Time.get_ticks_usec()
		_request_global_slow(0.085)
		_request_camera_zoom(1.0)
		_request_camera_shake(direction, 0.9)
		return
	if result.outcome != DamageResult.Outcome.DAMAGED or result.final_damage <= 0:
		return
	var weapon_id := result.packet.weapon_id if result.packet != null else &""
	var target_is_player := result.target is PlayerController
	if target_is_player:
		_last_player_hurt_usec = Time.get_ticks_usec()
		if _is_repeated_continuous_hurt(result):
			return
	var qualifies_kill := result.target_defeated and _qualifies_player_kill(result)
	if not target_is_player and _is_secondary_feedback_group(result):
		if qualifies_kill:
			_register_player_kill(result)
		return
	var target_is_heavy := result.target is EnemyController and (result.target as EnemyController).profile != null and (result.target as EnemyController).profile.role == EnemyProfile.Role.HEAVY_ANCHOR
	var strong_event := weapon_id == &"rail_cannon" or (result.target_defeated and target_is_heavy) or (target_is_player and result.final_damage >= 2)
	if strong_event:
		_request_global_slow(0.075 if target_is_heavy or target_is_player else 0.065)
	else:
		_hold_visual(result.target, LOCAL_HOLD_SECONDS)
		if result.packet != null:
			_hold_visual(result.packet.source, LOCAL_HOLD_SECONDS)
	var reaction_strength := 1.0 if strong_event else (0.72 if weapon_id == &"scattergun" else 0.48)
	_play_reactions(result, direction, reaction_strength)
	_request_camera_shake(direction, reaction_strength * (0.85 if target_is_player else 0.42))
	if qualifies_kill:
		_register_player_kill(result)


func _is_secondary_feedback_group(result: DamageResult) -> bool:
	if result.packet == null or result.packet.feedback_group_id <= 0 or not is_instance_valid(result.packet.source):
		return false
	var now := Time.get_ticks_usec()
	var key := "%d:%d" % [result.packet.source.get_instance_id(), result.packet.feedback_group_id]
	var previous := int(_feedback_groups.get(key, -1_000_000))
	_feedback_groups[key] = now
	for existing_key in _feedback_groups.keys():
		if now - int(_feedback_groups[existing_key]) > 1_000_000:
			_feedback_groups.erase(existing_key)
	return now - previous <= MERGE_WINDOW_USEC


func _is_repeated_continuous_hurt(result: DamageResult) -> bool:
	if result.packet == null or not result.packet.is_continuous_damage:
		return false
	var now := Time.get_ticks_usec()
	var source_id := result.packet.source.get_instance_id() if is_instance_valid(result.packet.source) else 0
	var key := "%d:%s" % [source_id, String(result.packet.damage_type)]
	var previous := int(_continuous_player_hurt_at.get(key, -10_000_000))
	_continuous_player_hurt_at[key] = now
	return now - previous < 850_000


func _qualifies_player_kill(result: DamageResult) -> bool:
	if result == null or not result.target_defeated or result.packet == null:
		return false
	if result.packet.source_faction != CombatFaction.Id.PLAYER or not result.packet.source is PlayerController:
		return false
	return result.target is EnemyController or (is_instance_valid(result.target) and result.target.is_in_group(&"bosses"))


func _register_player_kill(result: DamageResult) -> void:
	var now := Time.get_ticks_usec()
	if _kill_chain_count > 0 and now >= _kill_chain_deadline_usec:
		_reset_kill_chain(true)
	_kill_chain_count += 1
	_kill_chain_deadline_usec = now + KILL_CHAIN_TIMEOUT_USEC
	var target := result.target as Node2D
	var boss_final := target.is_in_group(&"bosses")
	var heavy := target is EnemyController and (target as EnemyController).profile != null and (target as EnemyController).profile.role == EnemyProfile.Role.HEAVY_ANCHOR
	var entry := {
		"world_position": target.global_position,
		"stage": mini(_kill_chain_count, KILL_CHAIN_MAX_STAGE),
		"weapon_id": result.packet.weapon_id,
		"offscreen": _is_offscreen(target),
		"boss_final": boss_final,
		"heavy": heavy,
		"started_at": now,
		"emit_at": now + KILL_FEEDBACK_DELAY_USEC,
	}
	if _pending_kill.is_empty() or now - int(_pending_kill.get("started_at", 0)) > KILL_MERGE_WINDOW_USEC:
		if not _pending_kill.is_empty():
			_emit_pending_kill()
		_pending_kill = entry
		return
	# Dense kills share one cue. The newest stage carries the escalation while
	# boss/heavy priority and any on-screen occurrence are retained.
	entry.boss_final = bool(entry.boss_final) or bool(_pending_kill.get("boss_final", false))
	entry.heavy = bool(entry.heavy) or bool(_pending_kill.get("heavy", false))
	entry.offscreen = bool(entry.offscreen) and bool(_pending_kill.get("offscreen", true))
	entry.started_at = _pending_kill.get("started_at", now)
	entry.emit_at = int(entry.started_at) + KILL_MERGE_WINDOW_USEC
	_pending_kill = entry


func _emit_pending_kill() -> void:
	if _pending_kill.is_empty():
		return
	var now := Time.get_ticks_usec()
	var suppressed := now - _last_player_hurt_usec <= PLAYER_HURT_PRIORITY_USEC
	var position: Vector2 = _pending_kill.get("world_position", Vector2.ZERO)
	var stage := int(_pending_kill.get("stage", 1))
	var offscreen := bool(_pending_kill.get("offscreen", false))
	var boss_final := bool(_pending_kill.get("boss_final", false))
	if boss_final:
		_request_global_slow(0.08)
		_request_camera_zoom(0.9)
		if not suppressed:
			_request_camera_shake(Vector2.ZERO, 0.9)
	elif not offscreen and not suppressed:
		_request_camera_shake(Vector2.ZERO, 0.12 + 0.045 * stage)
	kill_chain_feedback.emit(position, stage, _pending_kill.get("weapon_id", &""), offscreen, boss_final, suppressed)
	_pending_kill.clear()


func _reset_kill_chain(play_tail: bool) -> void:
	var previous_stage := mini(_kill_chain_count, KILL_CHAIN_MAX_STAGE)
	_kill_chain_count = 0
	_kill_chain_deadline_usec = 0
	_pending_kill.clear()
	if play_tail and previous_stage >= 2:
		kill_chain_ended.emit(previous_stage)


func _is_offscreen(target: Node2D) -> bool:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return false
	var size := get_viewport().get_visible_rect().size / camera.zoom
	var visible_world := Rect2(camera.get_screen_center_position() - size * 0.5, size).grow(24.0)
	return not visible_world.has_point(target.global_position)


func _on_tree_node_added(node: Node) -> void:
	if node is PlayerController:
		call_deferred("_bind_player", node)


func _bind_existing_players() -> void:
	for node in get_tree().get_nodes_in_group(&"player"):
		if node is PlayerController:
			_bind_player(node)


func _bind_player(player: PlayerController) -> void:
	if not is_instance_valid(player) or _bound_player_ids.has(player.get_instance_id()):
		return
	_bound_player_ids[player.get_instance_id()] = true
	player.player_died.connect(_on_player_died)


func _on_player_died(_packet: DamagePacket) -> void:
	_reset_kill_chain(false)
	_restore_time_scale()
	_request_global_slow(0.08)
	_request_camera_shake(Vector2.ZERO, 1.0)
	_death_cleanup_at_usec = Time.get_ticks_usec() + 180_000


func _on_combat_moment_requested(kind: StringName, _world_position: Vector2) -> void:
	match kind:
		&"boss_phase":
			_request_global_slow(0.06)
			_request_camera_shake(Vector2.ZERO, 0.55)
		&"boss_break":
			_request_global_slow(0.075)
			_request_camera_shake(Vector2.ZERO, 0.72)


func _on_weapon_cue_requested(weapon_id: StringName, cue: StringName, _world_position: Vector2) -> void:
	if cue != &"fire" and cue != &"swing":
		return
	var strength := 0.14
	if weapon_id == &"scattergun":
		strength = 0.34
	elif weapon_id == &"rail_cannon":
		strength = 0.62
		_request_global_slow(0.055)
	_request_camera_shake(Vector2.ZERO, strength)
	var player := get_tree().get_first_node_in_group(&"player")
	if is_instance_valid(player) and player is PlayerController:
		(player as PlayerController).visuals.play_recoil((player as PlayerController).aim_direction, strength)


func _request_global_slow(seconds: float) -> void:
	var now := Time.get_ticks_usec()
	var duration_usec := int(seconds * 1_000_000.0)
	if now - _slow_window_started_usec > MERGE_WINDOW_USEC:
		_slow_window_started_usec = now
		_strongest_duration_usec = duration_usec
	else:
		_strongest_duration_usec = maxi(_strongest_duration_usec, duration_usec)
	_slow_until_usec = _slow_window_started_usec + _strongest_duration_usec
	if _slow_until_usec <= now:
		return
	if not _time_scale_owned:
		_saved_time_scale = Engine.time_scale
		_time_scale_owned = true
	Engine.time_scale = minf(_saved_time_scale, GLOBAL_TIME_SCALE)


func _restore_time_scale() -> void:
	if not _time_scale_owned:
		return
	Engine.time_scale = _saved_time_scale
	_time_scale_owned = false


func _hold_visual(actor: Variant, seconds: float) -> void:
	if not is_instance_valid(actor):
		return
	var visual_node := _visual_for(actor)
	if is_instance_valid(visual_node) and visual_node.has_method("hold_impact"):
		visual_node.hold_impact(seconds)


func _play_reactions(result: DamageResult, direction: Vector2, strength: float) -> void:
	var target_visual := _visual_for(result.target)
	if is_instance_valid(target_visual) and target_visual.has_method("play_hit_reaction"):
		target_visual.play_hit_reaction(direction, strength)
	if result.packet == null or not is_instance_valid(result.packet.source):
		return
	var source_visual := _visual_for(result.packet.source)
	if is_instance_valid(source_visual) and source_visual.has_method("play_recoil"):
		source_visual.play_recoil(direction, strength * 0.55)


func _visual_for(actor: Variant) -> Node:
	if actor is PlayerController:
		return (actor as PlayerController).visuals
	if actor is EnemyController:
		return (actor as EnemyController).visuals
	return actor as Node


func _request_camera_shake(direction: Vector2, strength: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if is_instance_valid(player) and player.has_method("add_camera_trauma"):
		player.add_camera_trauma(direction, strength)


func _request_camera_zoom(strength: float) -> void:
	var motion_strength := clampf(float(PlayerConfig.get_config(&"UISettings", &"CameraShakeStrength", 1.0)), 0.0, 1.0)
	if motion_strength <= 0.0:
		return
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	if _camera_zoom_tween != null and _camera_zoom_tween.is_valid():
		_camera_zoom_tween.kill()
		if not _camera_zoom_base.is_zero_approx():
			camera.zoom = _camera_zoom_base
	_camera_zoom_base = camera.zoom
	var pulse := 1.0 + 0.035 * clampf(strength, 0.0, 1.0) * motion_strength
	camera.zoom = _camera_zoom_base * pulse
	_camera_zoom_tween = create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_camera_zoom_tween.tween_property(camera, "zoom", _camera_zoom_base, 0.16)


func _impact_direction(result: DamageResult) -> Vector2:
	if result.packet != null:
		if not result.packet.travel_direction.is_zero_approx():
			return result.packet.travel_direction.normalized()
		if not result.packet.knockback.is_zero_approx():
			return result.packet.knockback.normalized()
	return Vector2.RIGHT
