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
}

const PROJECTILE_SCENE := preload("res://scenes/combat/projectile.tscn")

@export var profile: EnemyProfile
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
	if profile == null:
		profile = preload("res://resources/enemies/melee_pressure.tres")
	apply_profile(profile)
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
	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(_target) or (_target is PlayerController and _target.health.is_dead()):
		state = State.IDLE
		_windup_remaining = 0.0
		velocity = Vector2.ZERO
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
	if distance > profile.awareness_range:
		state = State.IDLE
		velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
	elif should_retreat(distance):
		state = State.CHASE
		velocity = -global_position.direction_to(_target.global_position) * profile.move_speed
	elif distance <= profile.attack_range and _has_line_of_sight():
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
	var navigation_map := navigation_agent.get_navigation_map()
	if navigation_map.is_valid() and NavigationServer2D.map_get_iteration_id(navigation_map) > 0:
		# Set the destination before checking completion; the initial path is empty.
		navigation_agent.target_position = _target.global_position
		var next_position := navigation_agent.get_next_path_position()
		if not navigation_agent.is_navigation_finished() and not next_position.is_equal_approx(global_position):
			return global_position.direction_to(next_position)
	return global_position.direction_to(_target.global_position) if _has_line_of_sight() else Vector2.ZERO


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
	var color := profile.body_color if profile != null else Color.RED
	draw_circle(Vector2.ZERO, 11.0, color)
	draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 24, color.lightened(0.35), 2.0)
	if profile != null and profile.role == EnemyProfile.Role.RANGED_SIGHTLINE:
		draw_line(Vector2.ZERO, Vector2(17.0, 0.0), Color.WHITE, 2.0)
	elif profile != null and profile.role == EnemyProfile.Role.HEAVY_ANCHOR:
		draw_rect(Rect2(-8.0, -8.0, 16.0, 16.0), color.darkened(0.25), false, 3.0)

	if state == State.WINDUP:
		var progress := 1.0 - _windup_remaining / profile.attack_windup
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU * progress, 32, Color(1.0, 0.85, 0.25), 3.0)
		draw_line(Vector2.ZERO, _attack_direction * profile.attack_range, Color(1.0, 0.7, 0.15, 0.6), 2.0)


func _exit_tree() -> void:
	if is_instance_valid(_warning_audio):
		_warning_audio.stop()
