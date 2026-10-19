class_name EnemyController
extends CharacterBody2D

signal defeated(enemy: EnemyController, mandatory: bool)

enum State {
	IDLE,
	CHASE,
	ATTACK,
	STAGGERED,
	DEAD,
	WINDUP,
	PATROL,
	RETURN_TO_PATROL,
	INVESTIGATE,
	SELF_DESTRUCT,
}

const PROJECTILE_SCENE := preload("res://scenes/combat/projectile.tscn")
const NAVIGATION_REFRESH_SECONDS := 0.1
const NAVIGATION_REFRESH_DISTANCE := 8.0
const NAVIGATION_STUCK_SECONDS := 0.75
const NAVIGATION_RECOVERY_SECONDS := 0.55
const NAVIGATION_RETRY_PAUSE_SECONDS := 0.35
const RETREAT_REFRESH_SECONDS := 0.2
const RETREAT_SIDE_DISTANCE := 36.0
const TACTICAL_DESTINATION_SECONDS := 0.3
const FOOTSTEP_NOISE_THRESHOLD := 80.0
const FOOTSTEP_UPDATE_SECONDS := 0.4
const INVESTIGATION_SEARCH_SECONDS := 1.5
const ALERT_BROADCAST_SECONDS := 0.5
const ALERT_BROADCAST_DISTANCE := 48.0
const DEFAULT_VIEWPORT_SIZE := Vector2(640.0, 360.0)

@export var profile: EnemyProfile
@export var initial_facing := Vector2.LEFT
var facing := Vector2.LEFT
var death_motion_direction := Vector2.ZERO
var death_impact_direction := Vector2.ZERO
var _alerted := false
var _memory_remaining := 0.0
var _last_known_position := Vector2.ZERO
var _patrol_anchor := Vector2.ZERO
var _patrol_axis := Vector2.RIGHT
var _patrol_axis_initialized := false
var _patrol_index := 0
var _patrol_wait_remaining := 0.0
var _patrol_blocked_seconds := 0.0
var _returning_to_patrol := false
var mandatory: bool = true
var state: State = State.IDLE
var _attack_cooldown_remaining: float = 0.0
var stationary_test_target := false
var _stagger_remaining: float = 0.0
var _target: Node2D
var _windup_remaining := 0.0
var _attack_direction := Vector2.RIGHT
var _warning_audio: AudioStreamPlayer
var _navigation_refresh_remaining := 0.0
var _last_navigation_target := Vector2(INF, INF)
var _last_requested_destination := Vector2(INF, INF)
var _motion_sample_position := Vector2.ZERO
var _expected_navigation_motion := false
var _navigation_stuck_seconds := 0.0
var _navigation_retry_pause := 0.0
var _recovery_target := Vector2(INF, INF)
var _recovery_remaining := 0.0
var _recovery_side := 1.0
var _avoidance_move_pending := false
var _last_frame_movement := 0.0
var _retreat_target := Vector2(INF, INF)
var _retreat_player_position := Vector2(INF, INF)
var _retreat_refresh_remaining := 0.0
var tactical_brain := EnemyTacticalBrain.new()
var current_tactical_intent: EnemyTacticalBrain.Intent = EnemyTacticalBrain.Intent.APPROACH
var _tactical_side := 1.0
var _tactical_destination := Vector2(INF, INF)
var _tactical_destination_remaining := 0.0
var _tactical_target_sample := Vector2(INF, INF)
var _investigating := false
var _investigation_target := Vector2(INF, INF)
var _investigation_search_remaining := 0.0
var _footstep_update_remaining := 0.0
var _alert_broadcast_remaining := 0.0
var _last_alert_broadcast_position := Vector2(INF, INF)
var _precharge_active := false
var _precharge_remaining := 0.0
var _attack_precharged := false
var _initial_precharge_consumed := false
var _self_destruct_remaining := 0.0
var _defeat_finalized := false
var shield_charges := 0
var _shield_hit_flash_remaining := 0.0
const ATTACK_WARNING := preload("res://assets/audio/sfx/enemy_ui/enemy_attack.wav")

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var health: HealthComponent = $HealthComponent
@onready var hurt_box: HurtBox2DComponent = $HurtBox
@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	add_to_group("enemies")
	hurt_box.faction = CombatFaction.Id.ENEMY
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	facing = initial_facing.normalized() if not initial_facing.is_zero_approx() else Vector2.LEFT
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.noise_emitted.connect(_on_noise)
		events.movement_noise_emitted.connect(_on_movement_noise)
	if profile == null:
		profile = preload("res://resources/enemies/melee_pressure.tres")
	# Spawn order gives nearby groups a stable, evenly split side preference.
	# It is only a preference: path validation can still choose the other side.
	_tactical_side = -1.0 if get_tree().get_nodes_in_group("enemies").size() % 2 == 0 else 1.0
	apply_profile(profile)
	navigation_agent.velocity_computed.connect(_on_navigation_velocity_computed)
	_patrol_anchor = global_position
	_motion_sample_position = global_position
	_patrol_wait_remaining = profile.patrol_pause_seconds
	_warning_audio = AudioStreamPlayer.new()
	_warning_audio.stream = ATTACK_WARNING
	_warning_audio.volume_db = -16.0
	add_child(_warning_audio)
	queue_redraw()


func apply_profile(value: EnemyProfile) -> void:
	profile = value
	if profile != null:
		tactical_brain.configure(profile.decision_interval, _tactical_side)
		shield_charges = 1 if profile.role == EnemyProfile.Role.HEAVY_ANCHOR else 0
	if is_node_ready():
		health.configure_max_health(profile.max_health)
		_configure_sprite()
		queue_redraw()


func _configure_sprite() -> void:
	if not is_instance_valid(sprite) or profile == null:
		return
	var key := "ranged" if profile.role == EnemyProfile.Role.RANGED_SIGHTLINE else "melee"
	var texture := WorkshopArt.asset(key)
	var size := texture.get_size()
	var visual_scale := minf(38.0 / size.x, 38.0 / size.y)
	sprite.texture = texture
	sprite.scale = Vector2.ONE * visual_scale
	# The source art is centered, while the actor origin stays at its feet.
	sprite.position = Vector2(0.0, 10.0 - size.y * visual_scale * 0.5)
	_sync_sprite_state()


func _sync_sprite_state() -> void:
	if not is_instance_valid(sprite):
		return
	sprite.flip_h = facing.x > 0.1
	sprite.modulate = Color(1.7, 1.5, 1.2) if (
		state == State.SELF_DESTRUCT and int(_self_destruct_remaining * 16.0) % 2 == 0
	) else Color.WHITE


func _process(delta: float) -> void:
	_sync_sprite_state()
	if _shield_hit_flash_remaining > 0.0:
		_shield_hit_flash_remaining = maxf(_shield_hit_flash_remaining - delta, 0.0)
		queue_redraw()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if state == State.SELF_DESTRUCT:
		_tick_self_destruct(delta)
		return
	_tick_navigation_state(delta)
	_attack_cooldown_remaining = maxf(_attack_cooldown_remaining - delta, 0.0)
	if _stagger_remaining > 0.0:
		_cancel_precharge()
		_stagger_remaining -= delta
		_cancel_avoidance_move()
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		return
	if stationary_test_target:
		if state == State.STAGGERED:
			state = State.IDLE
		velocity = Vector2.ZERO
		queue_redraw()
		return
	if not is_instance_valid(_target) or not _same_room(_target):
		_target = null
		for candidate in get_tree().get_nodes_in_group("player"):
			if candidate is Node2D and _same_room(candidate):
				_target = candidate
				break
	if not is_instance_valid(_target):
		_forget_target()
		_windup_remaining = 0.0
		_tick_patrol(delta)
		queue_redraw()
		return
	if _target is PlayerController and _target.health.is_dead():
		_forget_target()
		_windup_remaining = 0.0
		_stop_navigation_motion()
		queue_redraw()
		return
	var sees_target := can_see_target()
	if sees_target:
		_cancel_investigation()
		_alert_to(_target.global_position, true)
		_ensure_precharge()
	elif _alerted:
		_cancel_precharge()
		_memory_remaining = maxf(_memory_remaining - delta, 0.0)
		if _memory_remaining <= 0.0:
			_forget_target()
	else:
		_cancel_precharge()
	if not sees_target and _investigating and not _alerted:
		_windup_remaining = 0.0
		_tick_investigation(delta)
		queue_redraw()
		return
	if not _alerted:
		_windup_remaining = 0.0
		_tick_patrol(delta)
		queue_redraw()
		return
	_tick_precharge(delta, sees_target)
	if state == State.WINDUP:
		_windup_remaining -= delta
		_stop_navigation_motion()
		if _windup_remaining <= 0.0:
			state = State.ATTACK
			if _has_line_of_sight():
				perform_attack()
			else:
				_attack_cooldown_remaining = profile.attack_cooldown
		queue_redraw()
		return
	var distance := global_position.distance_to(_target.global_position)
	var desired_velocity := Vector2.ZERO
	if not sees_target:
		state = State.CHASE
		desired_velocity = _direction_to_position(_last_known_position) * profile.move_speed if global_position.distance_to(_last_known_position) > 12.0 else Vector2.ZERO
	else:
		current_tactical_intent = _choose_tactical_intent(distance, delta)
		match current_tactical_intent:
			EnemyTacticalBrain.Intent.RETREAT:
				state = State.CHASE
				desired_velocity = _direction_to_retreat_position() * profile.move_speed
			EnemyTacticalBrain.Intent.FLANK_LEFT, EnemyTacticalBrain.Intent.FLANK_RIGHT:
				state = State.CHASE
				desired_velocity = _direction_to_tactical_destination(current_tactical_intent) * profile.move_speed
			EnemyTacticalBrain.Intent.STRAFE_LEFT, EnemyTacticalBrain.Intent.STRAFE_RIGHT:
				state = State.CHASE
				desired_velocity = _direction_to_tactical_destination(current_tactical_intent) * profile.move_speed * 0.8
			EnemyTacticalBrain.Intent.INTERCEPT:
				state = State.CHASE
				desired_velocity = _direction_to_position(_predicted_target_position()) * profile.move_speed
			EnemyTacticalBrain.Intent.HOLD_AND_ATTACK:
				state = State.ATTACK
				desired_velocity = velocity.move_toward(Vector2.ZERO, 1000.0 * delta)
				if distance <= profile.attack_range and _attack_cooldown_remaining <= 0.0 and _attack_precharged:
					_attack_direction = global_position.direction_to(_target.global_position)
					perform_attack()
				elif distance <= profile.attack_range and _attack_cooldown_remaining <= 0.0 and not _precharge_active:
					state = State.WINDUP
					_windup_remaining = profile.attack_windup
					_attack_direction = global_position.direction_to(_target.global_position)
					if DisplayServer.get_name() != "headless":
						_warning_audio.play()
			_:
				state = State.CHASE
				desired_velocity = _direction_to_target() * profile.move_speed
	if sees_target:
		facing = global_position.direction_to(_target.global_position)
	elif not desired_velocity.is_zero_approx():
		facing = desired_velocity.normalized()
	if state == State.WINDUP:
		_stop_navigation_motion()
	else:
		_submit_navigation_velocity(desired_velocity)
	queue_redraw()


func should_retreat(distance: float) -> bool:
	return profile.role == EnemyProfile.Role.RANGED_SIGHTLINE and distance < profile.attack_range * 0.65


func _choose_tactical_intent(distance: float, delta: float) -> EnemyTacticalBrain.Intent:
	if not profile.tactical_enabled:
		if should_retreat(distance):
			return EnemyTacticalBrain.Intent.RETREAT
		return EnemyTacticalBrain.Intent.HOLD_AND_ATTACK if distance <= profile.attack_range else EnemyTacticalBrain.Intent.APPROACH
	# Safety and attack windows are edge-triggered and must not wait for the
	# regular decision interval. The interval only stabilizes repositioning.
	if should_retreat(distance):
		return EnemyTacticalBrain.Intent.RETREAT
	if distance <= profile.attack_range:
		if profile.role != EnemyProfile.Role.RANGED_SIGHTLINE or _attack_cooldown_remaining <= 0.0:
			return EnemyTacticalBrain.Intent.HOLD_AND_ATTACK
	var snapshot := {
		"role": profile.role,
		"distance": distance,
		"attack_range": profile.attack_range,
		"cooldown_remaining": _attack_cooldown_remaining,
		"nearby_allies": _nearby_alerted_allies(),
	}
	return tactical_brain.tick(delta, snapshot)


func _nearby_alerted_allies() -> int:
	var count := 0
	var radius := maxf(profile.ally_alert_range, 96.0)
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if (
			candidate != self
			and candidate is EnemyController
			and candidate.state not in [State.DEAD, State.SELF_DESTRUCT]
			and candidate._alerted
			and _same_room(candidate)
			and global_position.distance_to(candidate.global_position) <= radius
		):
			count += 1
	return count


func _ensure_precharge() -> void:
	if state in [State.WINDUP, State.STAGGERED, State.DEAD, State.SELF_DESTRUCT] or _precharge_active or _attack_precharged:
		return
	var settings: Node = get_node_or_null("/root/GameSettings")
	var continuous: bool = settings != null and bool(settings.continuous_precharge)
	if _initial_precharge_consumed and not continuous:
		return
	_precharge_active = true
	_precharge_remaining = profile.attack_windup
	if DisplayServer.get_name() != "headless":
		_warning_audio.play()


func _tick_precharge(delta: float, sees_target: bool) -> void:
	if not sees_target:
		_cancel_precharge()
		return
	if not _precharge_active:
		return
	_precharge_remaining = maxf(_precharge_remaining - delta, 0.0)
	if _precharge_remaining <= 0.0:
		_precharge_active = false
		_attack_precharged = true


func _cancel_precharge() -> void:
	_precharge_active = false
	_precharge_remaining = 0.0
	_attack_precharged = false


func _direction_to_tactical_destination(intent: EnemyTacticalBrain.Intent) -> Vector2:
	if not is_instance_valid(_target):
		return Vector2.ZERO
	if (
		_tactical_destination.x == INF
		or _tactical_destination_remaining <= 0.0
		or _tactical_target_sample.distance_to(_target.global_position) > NAVIGATION_REFRESH_DISTANCE
		or global_position.distance_to(_tactical_destination) <= 6.0
	):
		_tactical_destination = _select_tactical_destination(intent)
		_tactical_destination_remaining = TACTICAL_DESTINATION_SECONDS
		_tactical_target_sample = _target.global_position
	if _tactical_destination.x == INF:
		return _direction_to_target()
	return _direction_to_position(_tactical_destination)


func _select_tactical_destination(intent: EnemyTacticalBrain.Intent) -> Vector2:
	var radial := _target.global_position.direction_to(global_position)
	if radial.is_zero_approx():
		radial = -facing if not facing.is_zero_approx() else Vector2.LEFT
	var preferred_sign := -1.0 if intent in [EnemyTacticalBrain.Intent.FLANK_LEFT, EnemyTacticalBrain.Intent.STRAFE_LEFT] else 1.0
	var angle_degrees := profile.flank_angle_degrees
	var orbit_radius := maxf(profile.flank_radius, profile.attack_range * 1.35)
	var require_sight := false
	if intent in [EnemyTacticalBrain.Intent.STRAFE_LEFT, EnemyTacticalBrain.Intent.STRAFE_RIGHT]:
		angle_degrees = profile.strafe_angle_degrees
		orbit_radius = clampf(
			global_position.distance_to(_target.global_position),
			profile.attack_range * 0.72,
			profile.attack_range * 0.94
		)
		require_sight = true
	for sign_value: float in [preferred_sign, -preferred_sign]:
		var desired := _target.global_position + radial.rotated(deg_to_rad(angle_degrees * sign_value)) * orbit_radius
		var candidate := _snap_to_reachable_navigation(desired)
		if candidate.x == INF:
			continue
		if require_sight and not _clear_segment(candidate, _target.global_position):
			continue
		return candidate
	return Vector2(INF, INF)


func _snap_to_reachable_navigation(desired: Vector2) -> Vector2:
	var navigation_map := navigation_agent.get_navigation_map()
	if not navigation_map.is_valid() or NavigationServer2D.map_get_iteration_id(navigation_map) <= 0:
		return desired if _clear_path_to(desired) else Vector2(INF, INF)
	var candidate := NavigationServer2D.map_get_closest_point(navigation_map, desired)
	if candidate.distance_to(desired) > navigation_agent.radius * 1.5:
		return Vector2(INF, INF)
	var path := NavigationServer2D.map_get_path(navigation_map, global_position, candidate, true)
	return candidate if path.size() >= 2 else Vector2(INF, INF)


func _predicted_target_position() -> Vector2:
	if not is_instance_valid(_target):
		return global_position
	var predicted := _target.global_position
	if _target is CharacterBody2D and profile.target_prediction_seconds > 0.0:
		var lead := (_target as CharacterBody2D).velocity * profile.target_prediction_seconds
		predicted += lead.limit_length(48.0)
	return predicted


func get_tactical_intent() -> EnemyTacticalBrain.Intent:
	return current_tactical_intent


func _has_line_of_sight() -> bool:
	if not is_instance_valid(_target):
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, _target.global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _direction_to_target() -> Vector2:
	return _direction_to_position(_target.global_position)


func _direction_to_position(destination: Vector2) -> Vector2:
	_last_requested_destination = destination
	if _navigation_retry_pause > 0.0:
		return Vector2.ZERO
	var effective_destination := destination
	if _recovery_target.x != INF:
		if global_position.distance_to(_recovery_target) <= 6.0:
			_clear_navigation_recovery()
		else:
			effective_destination = _recovery_target
	var navigation_map := navigation_agent.get_navigation_map()
	if navigation_map.is_valid() and NavigationServer2D.map_get_iteration_id(navigation_map) > 0:
		if (
			_last_navigation_target.x == INF
			or _last_navigation_target.distance_to(effective_destination) > NAVIGATION_REFRESH_DISTANCE
			or _navigation_refresh_remaining <= 0.0
		):
			navigation_agent.target_position = effective_destination
			_last_navigation_target = effective_destination
			_navigation_refresh_remaining = NAVIGATION_REFRESH_SECONDS
		var next_position := navigation_agent.get_next_path_position()
		if not navigation_agent.is_navigation_finished() and not next_position.is_equal_approx(global_position):
			return global_position.direction_to(next_position)
	return global_position.direction_to(effective_destination) if _clear_path_to(effective_destination) else Vector2.ZERO


func _direction_to_retreat_position() -> Vector2:
	if not is_instance_valid(_target):
		return Vector2.ZERO
	if (
		_retreat_target.x == INF
		or _retreat_refresh_remaining <= 0.0
		or _retreat_player_position.distance_to(_target.global_position) > NAVIGATION_REFRESH_DISTANCE
		or global_position.distance_to(_retreat_target) <= 6.0
	):
		_retreat_target = _select_retreat_destination(_target.global_position)
		_retreat_player_position = _target.global_position
		_retreat_refresh_remaining = RETREAT_REFRESH_SECONDS
	if _retreat_target.x == INF:
		return Vector2.ZERO
	return _direction_to_position(_retreat_target)


func _select_retreat_destination(threat_position: Vector2) -> Vector2:
	var navigation_map := navigation_agent.get_navigation_map()
	var away := threat_position.direction_to(global_position)
	if away.is_zero_approx():
		away = facing if not facing.is_zero_approx() else Vector2.RIGHT
	var retreat_angles := [0.0, -30.0, 30.0, -60.0, 60.0, -90.0, 90.0]
	if not navigation_map.is_valid() or NavigationServer2D.map_get_iteration_id(navigation_map) <= 0:
		return _select_direct_retreat_destination(threat_position, away, retreat_angles)
	var best_with_sight := Vector2(INF, INF)
	var best_with_sight_score := -INF
	var best_fallback := Vector2(INF, INF)
	var best_fallback_score := -INF
	# Wider side steps let a cornered shooter slide along cover when every
	# backward candidate is occupied, without moving closer to the threat.
	for degrees: float in retreat_angles:
		var desired := global_position + away.rotated(deg_to_rad(degrees)) * RETREAT_SIDE_DISTANCE
		var candidate := NavigationServer2D.map_get_closest_point(navigation_map, desired)
		# A large snap means the desired point was too close to, or beyond, a wall.
		if candidate.distance_to(desired) > navigation_agent.radius:
			continue
		var path := NavigationServer2D.map_get_path(navigation_map, global_position, candidate, true)
		if path.size() < 2 or candidate.distance_to(global_position) <= 8.0:
			continue
		var score := candidate.distance_to(threat_position) - _path_length(path) * 0.1
		if score > best_fallback_score:
			best_fallback = candidate
			best_fallback_score = score
		if _clear_segment(candidate, threat_position) and score > best_with_sight_score:
			best_with_sight = candidate
			best_with_sight_score = score
	if best_with_sight.x != INF:
		return best_with_sight
	if best_fallback.x != INF:
		return best_fallback
	# Navigation can briefly be unavailable or stale immediately after a room
	# load/teleport. A short ray-tested side step keeps the shooter responsive
	# until the next scheduled navigation refresh.
	return _select_direct_retreat_destination(threat_position, away, retreat_angles)


func _select_direct_retreat_destination(threat_position: Vector2, away: Vector2, retreat_angles: Array) -> Vector2:
	var best_direct := Vector2(INF, INF)
	var best_direct_distance := threat_position.distance_to(global_position)
	for step_distance: float in [RETREAT_SIDE_DISTANCE, 24.0, 16.0]:
		for degrees: float in retreat_angles:
			var desired := global_position + away.rotated(deg_to_rad(degrees)) * step_distance
			var next_distance := desired.distance_to(threat_position)
			if _clear_path_to(desired) and next_distance > best_direct_distance:
				best_direct = desired
				best_direct_distance = next_distance
	return best_direct


func _path_length(path: PackedVector2Array) -> float:
	var total := 0.0
	for index in range(1, path.size()):
		total += path[index - 1].distance_to(path[index])
	return total


func _clear_segment(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _tick_navigation_state(delta: float) -> void:
	_navigation_refresh_remaining = maxf(_navigation_refresh_remaining - delta, 0.0)
	_retreat_refresh_remaining = maxf(_retreat_refresh_remaining - delta, 0.0)
	_tactical_destination_remaining = maxf(_tactical_destination_remaining - delta, 0.0)
	_footstep_update_remaining = maxf(_footstep_update_remaining - delta, 0.0)
	_alert_broadcast_remaining = maxf(_alert_broadcast_remaining - delta, 0.0)
	_navigation_retry_pause = maxf(_navigation_retry_pause - delta, 0.0)
	_recovery_remaining = maxf(_recovery_remaining - delta, 0.0)
	if _recovery_target.x != INF and _recovery_remaining <= 0.0:
		_clear_navigation_recovery()
	_last_frame_movement = global_position.distance_to(_motion_sample_position)
	if _expected_navigation_motion:
		if _last_frame_movement < 0.15:
			_navigation_stuck_seconds += delta
		else:
			_navigation_stuck_seconds = 0.0
	elif _navigation_retry_pause <= 0.0:
		_navigation_stuck_seconds = 0.0
	_motion_sample_position = global_position
	_expected_navigation_motion = false
	if (
		_navigation_stuck_seconds >= NAVIGATION_STUCK_SECONDS
		and _navigation_retry_pause <= 0.0
		and _last_requested_destination.x != INF
		and state in [State.CHASE, State.RETURN_TO_PATROL]
	):
		_begin_navigation_recovery(_last_requested_destination)


func _begin_navigation_recovery(destination: Vector2) -> void:
	_navigation_stuck_seconds = 0.0
	var navigation_map := navigation_agent.get_navigation_map()
	if not navigation_map.is_valid() or NavigationServer2D.map_get_iteration_id(navigation_map) <= 0:
		_navigation_retry_pause = NAVIGATION_RETRY_PAUSE_SECONDS
		return
	var forward := global_position.direction_to(destination)
	if forward.is_zero_approx():
		forward = facing if not facing.is_zero_approx() else Vector2.RIGHT
	var side := Vector2(-forward.y, forward.x)
	for sign_value: float in [_recovery_side, -_recovery_side]:
		var desired: Vector2 = global_position + forward * 12.0 + side * 28.0 * sign_value
		var candidate := NavigationServer2D.map_get_closest_point(navigation_map, desired)
		if candidate.distance_to(desired) > navigation_agent.radius:
			continue
		var path := NavigationServer2D.map_get_path(navigation_map, global_position, candidate, true)
		if path.size() < 2 or candidate.distance_to(global_position) <= 6.0:
			continue
		_recovery_target = candidate
		_recovery_remaining = NAVIGATION_RECOVERY_SECONDS
		_recovery_side = -sign_value
		_invalidate_navigation_path()
		return
	_navigation_retry_pause = NAVIGATION_RETRY_PAUSE_SECONDS
	_recovery_side *= -1.0


func _clear_navigation_recovery() -> void:
	_recovery_target = Vector2(INF, INF)
	_recovery_remaining = 0.0
	_invalidate_navigation_path()


func _invalidate_navigation_path() -> void:
	_last_navigation_target = Vector2(INF, INF)
	_navigation_refresh_remaining = 0.0


func _submit_navigation_velocity(desired_velocity: Vector2) -> void:
	velocity = desired_velocity
	_expected_navigation_motion = not desired_velocity.is_zero_approx()
	if desired_velocity.is_zero_approx():
		_stop_navigation_motion()
		return
	var navigation_map := navigation_agent.get_navigation_map()
	if (
		navigation_agent.avoidance_enabled
		and _is_on_navigation_map(navigation_map)
	):
		_avoidance_move_pending = true
		navigation_agent.velocity = desired_velocity
		return
	_avoidance_move_pending = false
	move_and_slide()


func _is_on_navigation_map(navigation_map: RID) -> bool:
	if not navigation_map.is_valid() or NavigationServer2D.map_get_iteration_id(navigation_map) <= 0:
		return false
	var closest := NavigationServer2D.map_get_closest_point(navigation_map, global_position)
	return closest.distance_to(global_position) <= navigation_agent.radius * 2.0


func _on_navigation_velocity_computed(safe_velocity: Vector2) -> void:
	if not _avoidance_move_pending:
		return
	_avoidance_move_pending = false
	if state in [State.DEAD, State.SELF_DESTRUCT, State.WINDUP, State.STAGGERED]:
		return
	velocity = safe_velocity
	move_and_slide()


func _cancel_avoidance_move() -> void:
	_avoidance_move_pending = false
	_expected_navigation_motion = false
	if navigation_agent.avoidance_enabled:
		navigation_agent.velocity = Vector2.ZERO


func _stop_navigation_motion() -> void:
	_cancel_avoidance_move()
	velocity = Vector2.ZERO


func perform_attack() -> void:
	_initial_precharge_consumed = true
	_cancel_precharge()
	_attack_cooldown_remaining = profile.attack_cooldown
	var direction := _attack_direction
	if not is_instance_valid(_target):
		return
	if profile.role == EnemyProfile.Role.RANGED_SIGHTLINE:
		var projectile: CombatProjectile = PROJECTILE_SCENE.instantiate()
		CombatProjectile.room_for_actor(self).add_child(projectile)
		projectile.global_position = global_position + direction * 16.0
		projectile.setup(self, CombatFaction.Id.ENEMY, direction, profile.damage, 310.0)
		return
	# Melee can be avoided during the telegraph and never hits through cover.
	if global_position.distance_to(_target.global_position) > profile.attack_range or not _has_line_of_sight():
		return
	if direction.dot(global_position.direction_to(_target.global_position)) < 0.5:
		return
	var target_hurt_box := _target.get_node_or_null("HurtBox")
	if target_hurt_box == null:
		return
	var packet := DamagePacket.new()
	packet.base_damage = profile.damage
	packet.source = self
	packet.source_faction = CombatFaction.Id.ENEMY
	packet.source_position = global_position
	packet.travel_direction = direction
	packet.knockback = direction * profile.attack_knockback
	packet.stagger_seconds = 0.8
	packet.is_melee = true
	target_hurt_box.receive_hit(packet)


func apply_stagger(seconds: float) -> void:
	if state in [State.DEAD, State.SELF_DESTRUCT]:
		return
	_cancel_precharge()
	state = State.STAGGERED
	_windup_remaining = 0.0
	_attack_cooldown_remaining = profile.attack_cooldown
	_stagger_remaining = maxf(_stagger_remaining, seconds)
	_cancel_avoidance_move()
	velocity = Vector2.ZERO
	queue_redraw()


func apply_knockback(force: Vector2) -> void:
	velocity += force


func _on_died(packet: DamagePacket) -> void:
	if state in [State.DEAD, State.SELF_DESTRUCT] or _defeat_finalized:
		return
	death_motion_direction = velocity.normalized() if not velocity.is_zero_approx() else Vector2.ZERO
	if packet != null:
		if not packet.travel_direction.is_zero_approx():
			death_impact_direction = packet.travel_direction.normalized()
		elif not packet.knockback.is_zero_approx():
			death_impact_direction = packet.knockback.normalized()
	_cancel_precharge()
	_cancel_investigation()
	if profile.self_destruct_enabled:
		state = State.SELF_DESTRUCT
		_self_destruct_remaining = profile.self_destruct_delay
		_stop_navigation_motion()
		queue_redraw()
		return
	_finalize_defeat()


func _tick_self_destruct(delta: float) -> void:
	_stop_navigation_motion()
	_self_destruct_remaining = maxf(_self_destruct_remaining - delta, 0.0)
	queue_redraw()
	if _self_destruct_remaining <= 0.0:
		_explode_and_finalize()


func _explode_and_finalize() -> void:
	var radius := profile.attack_range
	for actor in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("enemies"):
		if actor == self or not actor is Node2D or not is_instance_valid(actor) or not _same_room(actor):
			continue
		var target := actor as Node2D
		var offset := target.global_position - global_position
		if offset.length() > radius or not _clear_segment(global_position, target.global_position):
			continue
		var target_hurt_box := target.get_node_or_null("HurtBox") as HurtBox2DComponent
		if target_hurt_box == null:
			continue
		var direction := offset.normalized() if not offset.is_zero_approx() else Vector2.RIGHT
		var packet := DamagePacket.new()
		packet.base_damage = profile.self_destruct_damage
		packet.source = self
		packet.source_faction = CombatFaction.Id.ENEMY
		packet.damage_type = &"explosive"
		packet.source_position = global_position
		packet.travel_direction = direction
		packet.knockback = direction * profile.self_destruct_knockback
		packet.blockable = false
		packet.is_area_damage = true
		target_hurt_box.receive_hit(packet)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_noise(self, global_position, profile.self_destruct_noise_radius)
		events.request_effect(global_position, Color(1.0, 0.9, 0.65), profile.attack_range * 0.45, 0.1)
		events.request_effect(global_position, Color(1.0, 0.25, 0.08), profile.attack_range, 0.28)
	_finalize_defeat()


func _finalize_defeat() -> void:
	if _defeat_finalized:
		return
	_defeat_finalized = true
	state = State.DEAD
	_stop_navigation_motion()
	defeated.emit(self, mandatory)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_defeat(self)
	queue_free()


func _draw() -> void:
	if _alerted and state not in [State.DEAD, State.SELF_DESTRUCT]:
		draw_circle(Vector2(0, -22), 3.0, Color(1.0, 0.8, 0.2))
	var color := profile.body_color if profile != null else Color.RED
	if state == State.SELF_DESTRUCT and int(_self_destruct_remaining * 16.0) % 2 == 0:
		color = Color.WHITE
	draw_set_transform(Vector2(0, 7), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 11, Color(0, 0, 0, 0.32))
	draw_set_transform(Vector2.ZERO)
	draw_line(Vector2(0, 7), Vector2(0, 7) + facing * 13, Color(0.65, 0.9, 1, 0.45), 1)
	if profile != null and profile.role == EnemyProfile.Role.HEAVY_ANCHOR:
		draw_rect(Rect2(-8.0, -8.0, 16.0, 16.0), color.darkened(0.25), false, 3.0)
		_draw_heavy_shield()

	if state == State.WINDUP:
		var progress := 1.0 - _windup_remaining / profile.attack_windup
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU * progress, 32, Color(1.0, 0.85, 0.25), 3.0)
		draw_line(Vector2.ZERO, _attack_direction * profile.attack_range, Color(1.0, 0.7, 0.15, 0.6), 2.0)
	elif _precharge_active or _attack_precharged:
		var progress := 1.0 if _attack_precharged else 1.0 - _precharge_remaining / profile.attack_windup
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU * progress, 32, Color(1.0, 0.85, 0.25), 3.0)
	if state == State.SELF_DESTRUCT:
		var remaining_ratio := _self_destruct_remaining / maxf(profile.self_destruct_delay, 0.01)
		draw_arc(Vector2.ZERO, profile.attack_range, -PI * 0.5, -PI * 0.5 + TAU * remaining_ratio, 40, Color(1.0, 0.25, 0.1), 3.0)


func _exit_tree() -> void:
	_cancel_avoidance_move()
	if is_instance_valid(_warning_audio):
		_warning_audio.stop()


func is_alerted() -> bool:
	return _alerted


func can_see_target() -> bool:
	if not is_instance_valid(_target) or not _same_room(_target):
		return false
	var offset := _target.global_position - global_position
	var viewport_size := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", DEFAULT_VIEWPORT_SIZE.x)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", DEFAULT_VIEWPORT_SIZE.y))
	)
	var settings: Node = get_node_or_null("/root/GameSettings")
	var visual_scale: float = float(settings.get_visual_range_scale()) if settings != null and settings.has_method("get_visual_range_scale") else 1.0
	var half_extents := viewport_size * 0.5 * visual_scale
	if absf(offset.x) > half_extents.x or absf(offset.y) > half_extents.y:
		return false
	# The legacy range remains a useful profile/test limiter. Runtime profiles
	# set it above the viewport diagonal, so the rectangle is the real cap.
	if offset.length() > profile.awareness_range:
		return false
	if not offset.is_zero_approx() and facing.dot(offset.normalized()) < cos(deg_to_rad(profile.vision_angle_degrees * 0.5)):
		return false
	return _has_line_of_sight()


func _clear_path_to(location: Vector2) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(global_position, location, 1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


func _same_room(actor: Node) -> bool:
	if not is_instance_valid(actor) or not actor.is_inside_tree() or CombatProjectile.room_for_actor(self) != CombatProjectile.room_for_actor(actor):
		return false
	var area := EnvironmentArea.for_actor(self)
	if area is CombatRoom and area.sequence_managed:
		return EnvironmentArea.for_actor(actor) == area
	return true


func _alert_to(location: Vector2, broadcast: bool) -> void:
	if state in [State.DEAD, State.SELF_DESTRUCT] or health.is_dead():
		return
	var newly_alerted := not _alerted
	if newly_alerted:
		_clear_navigation_recovery()
		_retreat_target = Vector2(INF, INF)
		_clear_tactical_destination()
		tactical_brain.force_rethink()
		_initial_precharge_consumed = false
	_cancel_investigation()
	_alerted = true
	_last_known_position = location
	_memory_remaining = profile.alert_memory_seconds
	if state not in [State.WINDUP, State.STAGGERED]:
		state = State.CHASE
	if newly_alerted and broadcast:
		_broadcast_confirmed_alert(location)
	elif broadcast and _alert_broadcast_remaining <= 0.0 and (
		_last_alert_broadcast_position.x == INF
		or _last_alert_broadcast_position.distance_to(location) >= ALERT_BROADCAST_DISTANCE
	):
		_broadcast_confirmed_alert(location)
	queue_redraw()


func _broadcast_confirmed_alert(location: Vector2) -> void:
	_alert_broadcast_remaining = ALERT_BROADCAST_SECONDS
	_last_alert_broadcast_position = location
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_enemy_alert(self, location)
	var settings: Node = get_node_or_null("/root/GameSettings")
	var response_distance: float = float(settings.get_alert_response_distance()) if settings != null else 320.0
	for ally in get_tree().get_nodes_in_group("enemies"):
		if (
			ally != self
			and ally is EnemyController
			and ally.state not in [State.DEAD, State.SELF_DESTRUCT]
			and _same_room(ally)
			and global_position.distance_to(ally.global_position) <= response_distance
		):
			# Shared alarms carry only this confirmed snapshot and never rebroadcast.
			ally._alert_to(location, false)


func _on_noise(source: Node, origin: Vector2, radius: float) -> void:
	# An alerted enemy can be the source of a door-break or combat noise. That
	# sound is useful to nearby allies, but must not overwrite its own last known
	# player position with the noise origin and make it chase back to the door.
	if source == self or state in [State.DEAD, State.SELF_DESTRUCT] or get_tree().paused or not _same_room(source):
		return
	if source is PlayerController and source.health.is_dead():
		return
	var settings: Node = get_node_or_null("/root/GameSettings")
	var hearing_limit: float = float(settings.get_hearing_range_limit()) if settings != null and settings.has_method("get_hearing_range_limit") else INF
	var effective_range := minf(minf(radius, profile.hearing_range), hearing_limit)
	if not _clear_path_to(origin):
		effective_range *= profile.blocked_sound_multiplier
	if global_position.distance_to(origin) <= effective_range:
		_begin_investigation(origin)


func _on_movement_noise(source: Node, origin: Vector2, radius: float) -> void:
	if (
		source == self
		or profile.role != EnemyProfile.Role.RANGED_SIGHTLINE
		or radius <= FOOTSTEP_NOISE_THRESHOLD
		or _footstep_update_remaining > 0.0
		or state in [State.DEAD, State.SELF_DESTRUCT]
		or get_tree().paused
		or not _same_room(source)
	):
		return
	if source is PlayerController and source.health.is_dead():
		return
	var settings: Node = get_node_or_null("/root/GameSettings")
	var hearing_limit: float = float(settings.get_hearing_range_limit()) if settings != null and settings.has_method("get_hearing_range_limit") else INF
	var effective_range := minf(minf(radius, profile.hearing_range), hearing_limit)
	if not _clear_path_to(origin):
		effective_range *= profile.blocked_sound_multiplier
	if global_position.distance_to(origin) <= effective_range:
		_footstep_update_remaining = FOOTSTEP_UPDATE_SECONDS
		_begin_investigation(origin)


func _begin_investigation(location: Vector2) -> void:
	if _alerted:
		_last_known_position = location
		_memory_remaining = profile.alert_memory_seconds
		return
	_investigating = true
	_investigation_target = location
	_investigation_search_remaining = INVESTIGATION_SEARCH_SECONDS
	# Hearing records the source immediately, but must not cancel an attack
	# warning or a control effect that is already in progress.
	if state not in [State.WINDUP, State.STAGGERED]:
		state = State.INVESTIGATE


func _tick_investigation(delta: float) -> void:
	state = State.INVESTIGATE
	if global_position.distance_to(_investigation_target) > 12.0:
		var direction := _direction_to_position(_investigation_target)
		if not direction.is_zero_approx():
			facing = direction
		_submit_navigation_velocity(direction * profile.move_speed)
		return
	_stop_navigation_motion()
	_investigation_search_remaining = maxf(_investigation_search_remaining - delta, 0.0)
	if _investigation_search_remaining <= 0.0:
		_cancel_investigation()
		_returning_to_patrol = true
		_patrol_wait_remaining = profile.patrol_pause_seconds
		state = State.IDLE


func _cancel_investigation() -> void:
	_investigating = false
	_investigation_target = Vector2(INF, INF)
	_investigation_search_remaining = 0.0


func _on_damaged(_amount: int, packet: DamagePacket) -> void:
	if state in [State.DEAD, State.SELF_DESTRUCT] or health.is_dead():
		return
	if is_instance_valid(packet.source) and _same_room(packet.source):
		_alert_to(packet.source_position, false)


func try_absorb_hit(_packet: DamagePacket) -> bool:
	if shield_charges <= 0 or profile == null or profile.role != EnemyProfile.Role.HEAVY_ANCHOR:
		return false
	shield_charges -= 1
	_shield_hit_flash_remaining = 0.16
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.request_effect(global_position, Color(0.35, 0.88, 1.0), 24.0, 0.16)
	queue_redraw()
	return true


func _draw_heavy_shield() -> void:
	if shield_charges <= 0 and _shield_hit_flash_remaining <= 0.0:
		return
	var points := PackedVector2Array()
	for index in 6:
		points.append(Vector2.RIGHT.rotated(PI / 6.0 + TAU * float(index) / 6.0) * 20.0)
	points.append(points[0])
	var alpha := 0.52 if shield_charges > 0 else clampf(_shield_hit_flash_remaining / 0.16, 0.0, 1.0)
	var shield_color := Color(0.28, 0.82, 1.0, alpha)
	if shield_charges > 0:
		draw_polyline(points, shield_color, 1.5, true)
	else:
		for index in 6:
			if index % 2 == 0:
				draw_line(points[index], points[index + 1].lerp(points[index], 0.35), shield_color, 2.0)


func _forget_target() -> void:
	if _alerted:
		_returning_to_patrol = true
		_patrol_wait_remaining = profile.patrol_pause_seconds
		_patrol_blocked_seconds = 0.0
	_alerted = false
	_memory_remaining = 0.0
	_clear_navigation_recovery()
	_retreat_target = Vector2(INF, INF)
	_cancel_precharge()
	_cancel_investigation()
	_clear_tactical_destination()
	tactical_brain.force_rethink()
	current_tactical_intent = EnemyTacticalBrain.Intent.APPROACH
	_initial_precharge_consumed = false
	_last_alert_broadcast_position = Vector2(INF, INF)
	state = State.IDLE


func _clear_tactical_destination() -> void:
	_tactical_destination = Vector2(INF, INF)
	_tactical_destination_remaining = 0.0
	_tactical_target_sample = Vector2(INF, INF)


func _tick_patrol(delta: float) -> void:
	state = State.IDLE
	if not profile.patrol_enabled:
		_stop_navigation_motion()
		return
	if not _patrol_axis_initialized:
		_patrol_axis = _choose_patrol_axis()
		_patrol_axis_initialized = true
	if _patrol_wait_remaining > 0.0:
		_patrol_wait_remaining = maxf(_patrol_wait_remaining - delta, 0.0)
		_stop_navigation_motion()
		return
	var offset := global_position - _patrol_anchor
	if offset.length() > profile.patrol_distance + 4.0 or absf(offset.cross(_patrol_axis)) > 2.0:
		_returning_to_patrol = true
	var sign_value := 1.0 if _patrol_index == 0 else -1.0
	var destination := _patrol_anchor if _returning_to_patrol else _patrol_anchor + _patrol_axis * profile.patrol_distance * sign_value
	if global_position.distance_to(destination) <= 5.0:
		_returning_to_patrol = false
		_finish_patrol_leg()
		return
	var direction := _direction_to_position(destination) if _returning_to_patrol else _patrol_axis * sign_value
	var speed := profile.move_speed * profile.patrol_speed_ratio
	var next_position := global_position + direction * speed * delta
	# Patrol follows one fixed axis; only returning from chase uses navigation.
	if not _returning_to_patrol and next_position.distance_to(_patrol_anchor) > profile.patrol_distance + 4.0:
		_finish_patrol_leg()
		return
	state = State.RETURN_TO_PATROL if _returning_to_patrol else State.PATROL
	var desired_velocity := direction * speed
	if not direction.is_zero_approx():
		facing = direction
	# Patrol already has authored endpoint and wall-block recovery. Keeping it on
	# direct movement avoids RVO suppressing low-speed motion near navmesh edges;
	# combat chase and retreat still use soft avoidance.
	_cancel_avoidance_move()
	velocity = desired_velocity
	var previous := global_position
	move_and_slide()
	_patrol_blocked_seconds = _patrol_blocked_seconds + delta if global_position.distance_to(previous) < 0.05 else 0.0
	if _patrol_blocked_seconds >= profile.patrol_blocked_timeout:
		# Skip blocked endpoints; a return path is retried after a short pause.
		_finish_patrol_leg()


func _finish_patrol_leg() -> void:
	_patrol_index = 1 - _patrol_index
	_patrol_wait_remaining = profile.patrol_pause_seconds
	_patrol_blocked_seconds = 0.0
	state = State.IDLE
	_stop_navigation_motion()


func _choose_patrol_axis() -> Vector2:
	if profile.patrol_axis == EnemyProfile.PatrolAxis.HORIZONTAL:
		return Vector2.RIGHT
	if profile.patrol_axis == EnemyProfile.PatrolAxis.VERTICAL:
		return Vector2.DOWN
	var nearest_distance := INF
	var axis := Vector2.RIGHT
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var ray := PhysicsRayQueryParameters2D.create(_patrol_anchor, _patrol_anchor + direction * 256.0, 1)
		var hit := get_world_2d().direct_space_state.intersect_ray(ray)
		if hit.is_empty():
			continue
		var distance := _patrol_anchor.distance_to(hit.position)
		if distance < nearest_distance:
			nearest_distance = distance
			# A wall normal points across the wall; patrol is tangent to it.
			var normal: Vector2 = hit.normal
			axis = Vector2.RIGHT if absf(normal.y) > absf(normal.x) else Vector2.DOWN
	return axis
