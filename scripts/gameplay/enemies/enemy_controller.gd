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
}

const PROJECTILE_SCENE := preload("res://scenes/combat/projectile.tscn")

@export var profile: EnemyProfile
@export var initial_facing := Vector2.LEFT
var facing := Vector2.LEFT
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
var _stagger_remaining: float = 0.0
var _target: Node2D
var _windup_remaining := 0.0
var _attack_direction := Vector2.RIGHT
var _warning_audio: AudioStreamPlayer
const ATTACK_WARNING := preload("res://assets/audio/sfx/enemy_ui/enemy_attack.wav")

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D
@onready var health: HealthComponent = $HealthComponent
@onready var hurt_box: HurtBox2DComponent = $HurtBox


func _ready() -> void:
	add_to_group("enemies")
	hurt_box.faction = CombatFaction.Id.ENEMY
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	facing = initial_facing.normalized() if not initial_facing.is_zero_approx() else Vector2.LEFT
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.noise_emitted.connect(_on_noise)
	if profile == null:
		profile = preload("res://resources/enemies/melee_pressure.tres")
	apply_profile(profile)
	_patrol_anchor = global_position
	_patrol_wait_remaining = profile.patrol_pause_seconds
	_warning_audio = AudioStreamPlayer.new()
	_warning_audio.stream = ATTACK_WARNING
	_warning_audio.volume_db = -16.0
	add_child(_warning_audio)
	queue_redraw()


func apply_profile(value: EnemyProfile) -> void:
	profile = value
	if is_node_ready():
		health.configure_max_health(profile.max_health)
		queue_redraw()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_attack_cooldown_remaining = maxf(_attack_cooldown_remaining - delta, 0.0)
	if _stagger_remaining > 0.0:
		_stagger_remaining -= delta
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
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
		velocity = Vector2.ZERO
		queue_redraw()
		return
	var sees_target := can_see_target()
	if sees_target:
		_alert_to(_target.global_position, true)
	elif _alerted:
		_memory_remaining = maxf(_memory_remaining - delta, 0.0)
		if _memory_remaining <= 0.0:
			_forget_target()
	if not _alerted:
		_windup_remaining = 0.0
		_tick_patrol(delta)
		queue_redraw()
		return
	if state == State.WINDUP:
		_windup_remaining -= delta
		velocity = Vector2.ZERO
		if _windup_remaining <= 0.0:
			state = State.ATTACK
			if _has_line_of_sight():
				perform_attack()
			else:
				_attack_cooldown_remaining = profile.attack_cooldown
		queue_redraw()
		return
	var distance := global_position.distance_to(_target.global_position)
	if not sees_target:
		state = State.CHASE
		velocity = _direction_to_position(_last_known_position) * profile.move_speed if global_position.distance_to(_last_known_position) > 12.0 else Vector2.ZERO
	elif should_retreat(distance):
		state = State.CHASE
		velocity = -global_position.direction_to(_target.global_position) * profile.move_speed
	elif distance <= profile.attack_range:
		state = State.ATTACK
		velocity = velocity.move_toward(Vector2.ZERO, 1000.0 * delta)
		if _attack_cooldown_remaining <= 0.0:
			state = State.WINDUP
			_windup_remaining = profile.attack_windup
			_attack_direction = global_position.direction_to(_target.global_position)
			if DisplayServer.get_name() != "headless":
				_warning_audio.play()
	else:
		state = State.CHASE
		velocity = _direction_to_target() * profile.move_speed
	if sees_target:
		facing = global_position.direction_to(_target.global_position)
	elif not velocity.is_zero_approx():
		facing = velocity.normalized()
	move_and_slide()
	queue_redraw()


func should_retreat(distance: float) -> bool:
	return profile.role == EnemyProfile.Role.RANGED_SIGHTLINE and distance < profile.attack_range * 0.65


func _has_line_of_sight() -> bool:
	if not is_instance_valid(_target):
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, _target.global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _direction_to_target() -> Vector2:
	return _direction_to_position(_target.global_position)


func _direction_to_position(destination: Vector2) -> Vector2:
	var navigation_map := navigation_agent.get_navigation_map()
	if navigation_map.is_valid() and NavigationServer2D.map_get_iteration_id(navigation_map) > 0:
		# Set the destination before checking completion; the initial path is empty.
		navigation_agent.target_position = destination
		var next_position := navigation_agent.get_next_path_position()
		if not navigation_agent.is_navigation_finished() and not next_position.is_equal_approx(global_position):
			return global_position.direction_to(next_position)
	return global_position.direction_to(destination) if _clear_path_to(destination) else Vector2.ZERO


func perform_attack() -> void:
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
	packet.knockback = direction * (160.0 if profile.role == EnemyProfile.Role.HEAVY_ANCHOR else 90.0)
	packet.stagger_seconds = 0.8
	packet.is_melee = true
	target_hurt_box.receive_hit(packet)


func apply_stagger(seconds: float) -> void:
	if state == State.DEAD:
		return
	state = State.STAGGERED
	_windup_remaining = 0.0
	_attack_cooldown_remaining = profile.attack_cooldown
	_stagger_remaining = maxf(_stagger_remaining, seconds)
	velocity = Vector2.ZERO


func apply_knockback(force: Vector2) -> void:
	velocity += force


func _on_died(_packet: DamagePacket) -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	defeated.emit(self, mandatory)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_defeat(self)
	queue_free()


func _draw() -> void:
	if _alerted and state != State.DEAD:
		draw_circle(Vector2(0, -22), 3.0, Color(1.0, 0.8, 0.2))
	var color := profile.body_color if profile != null else Color.RED
	draw_circle(Vector2.ZERO, 11.0, color)
	draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, color.lightened(0.35), 2.0)
	# One shared direction line: the ranged weapon also follows this heading.
	draw_line(Vector2.ZERO, facing * 17.0, Color.WHITE, 2.0)
	if profile != null and profile.role == EnemyProfile.Role.HEAVY_ANCHOR:
		draw_rect(Rect2(-8.0, -8.0, 16.0, 16.0), color.darkened(0.25), false, 3.0)

	if state == State.WINDUP:
		var progress := 1.0 - _windup_remaining / profile.attack_windup
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU * progress, 32, Color(1.0, 0.85, 0.25), 3.0)
		draw_line(Vector2.ZERO, _attack_direction * profile.attack_range, Color(1.0, 0.7, 0.15, 0.6), 2.0)


func _exit_tree() -> void:
	if is_instance_valid(_warning_audio):
		_warning_audio.stop()


func is_alerted() -> bool:
	return _alerted


func can_see_target() -> bool:
	if not is_instance_valid(_target) or not _same_room(_target):
		return false
	var offset := _target.global_position - global_position
	if offset.length() > profile.awareness_range:
		return false
	if not offset.is_zero_approx() and facing.dot(offset.normalized()) < cos(deg_to_rad(profile.vision_angle_degrees * 0.5)):
		return false
	return _has_line_of_sight()


func _clear_path_to(location: Vector2) -> bool:
	var ray := PhysicsRayQueryParameters2D.create(global_position, location, 1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


func _same_room(actor: Node) -> bool:
	return is_instance_valid(actor) and actor.is_inside_tree() and CombatProjectile.room_for_actor(self) == CombatProjectile.room_for_actor(actor)


func _alert_to(location: Vector2, broadcast: bool) -> void:
	if state == State.DEAD or health.is_dead():
		return
	var newly_alerted := not _alerted
	_alerted = true
	_last_known_position = location
	_memory_remaining = profile.alert_memory_seconds
	if state not in [State.WINDUP, State.STAGGERED]:
		state = State.CHASE
	if newly_alerted and broadcast:
		for ally in get_tree().get_nodes_in_group("enemies"):
			if ally != self and ally is EnemyController and _same_room(ally):
				if global_position.distance_to(ally.global_position) <= profile.ally_alert_range and _clear_path_to(ally.global_position):
					# Received alarms never rebroadcast, preventing a map-wide chain.
					ally._alert_to(location, false)
	queue_redraw()


func _on_noise(source: Node, origin: Vector2, radius: float) -> void:
	if state == State.DEAD or get_tree().paused or not _same_room(source):
		return
	if source is PlayerController and source.health.is_dead():
		return
	var effective_range := minf(radius, profile.hearing_range)
	if not _clear_path_to(origin):
		effective_range *= profile.blocked_sound_multiplier
	if global_position.distance_to(origin) <= effective_range:
		_alert_to(origin, true)


func _on_damaged(_amount: int, packet: DamagePacket) -> void:
	if state == State.DEAD or health.is_dead():
		return
	if is_instance_valid(packet.source) and _same_room(packet.source):
		_alert_to(packet.source_position, true)


func _forget_target() -> void:
	if _alerted:
		_returning_to_patrol = true
		_patrol_wait_remaining = profile.patrol_pause_seconds
		_patrol_blocked_seconds = 0.0
	_alerted = false
	_memory_remaining = 0.0
	state = State.IDLE


func _tick_patrol(delta: float) -> void:
	state = State.IDLE
	velocity = Vector2.ZERO
	if not profile.patrol_enabled:
		return
	if not _patrol_axis_initialized:
		_patrol_axis = _choose_patrol_axis()
		_patrol_axis_initialized = true
	if _patrol_wait_remaining > 0.0:
		_patrol_wait_remaining = maxf(_patrol_wait_remaining - delta, 0.0)
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
	velocity = direction * speed
	if not direction.is_zero_approx():
		facing = direction
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
	velocity = Vector2.ZERO


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
