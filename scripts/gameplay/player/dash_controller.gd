class_name DashController
extends Node

signal dash_started(direction: Vector2)
signal dash_ended(cancelled: bool)
signal cooldown_changed(remaining: float, total: float)

const DEFAULT_CONFIG := preload("res://resources/player/default_dash_config.tres")

@export var config: DashConfigData = DEFAULT_CONFIG

var cooldown_remaining := 0.0
var terrain_tag: StringName = &"normal"
var equipment_speed_bonus := 0.0
var active_effect_kind: StringName = &"dash"
var _active_remaining := 0.0
var _direction := Vector2.ZERO
var _hits: Dictionary = {}
var _cancelled := false
var _scripted_destination := Vector2.ZERO
var _scripted := false


func tick(
	body: CharacterBody2D,
	input_vector: Vector2,
	facing: Vector2,
	delta: float,
	external_velocity: Vector2 = Vector2.ZERO
) -> void:
	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
	if is_dashing():
		_tick_dash(body, delta)
	else:
		var locomotion := body.velocity - external_velocity
		var desired := input_vector.normalized() * config.walk_speed * (1.0 + equipment_speed_bonus)
		var rate := config.braking if input_vector.is_zero_approx() or locomotion.dot(input_vector) < 0.0 else config.acceleration
		body.velocity = locomotion.move_toward(desired, rate * delta) * _terrain_multiplier() + external_velocity
		body.move_and_slide()
	cooldown_changed.emit(cooldown_remaining, config.dash_cooldown)


func start_dash(
	body: CharacterBody2D,
	facing: Vector2,
	input_vector: Vector2 = Vector2.ZERO,
	effect_kind: StringName = &"dash"
) -> bool:
	if is_dashing() or cooldown_remaining > 0.0:
		return false
	var heading := input_vector if not input_vector.is_zero_approx() else facing
	_direction = heading.normalized() if not heading.is_zero_approx() else Vector2.RIGHT
	_active_remaining = config.dash_duration
	cooldown_remaining = config.dash_cooldown
	_hits.clear()
	_cancelled = false
	active_effect_kind = effect_kind
	body.velocity = _direction * config.dash_speed * (1.0 + equipment_speed_bonus)
	dash_started.emit(_direction)
	return true


func start_scripted_dash(body: CharacterBody2D, destination: Vector2, effect_kind: StringName) -> bool:
	if is_dashing():
		return false
	var motion := destination - body.global_position
	if motion.length() <= 1.0:
		return false
	_direction = motion.normalized()
	_scripted_destination = destination
	_scripted = true
	_active_remaining = motion.length() / maxf(config.dash_speed * (1.0 + equipment_speed_bonus), 1.0)
	_hits.clear()
	_cancelled = false
	active_effect_kind = effect_kind
	body.velocity = _direction * config.dash_speed * (1.0 + equipment_speed_bonus)
	dash_started.emit(_direction)
	return true


func cancel_dash(cancelled: bool = true) -> void:
	if not is_dashing():
		return
	_cancelled = cancelled
	_finish_dash()


func reset_transient_state() -> void:
	var was_active := is_dashing()
	cooldown_remaining = 0.0
	_active_remaining = 0.0
	_hits.clear()
	_cancelled = was_active
	if was_active:
		dash_ended.emit(true)
	_direction = Vector2.ZERO
	active_effect_kind = &"dash"
	_cancelled = false
	_scripted = false


func is_dashing() -> bool:
	return _active_remaining > 0.0


func provides_invulnerability() -> bool:
	if not is_dashing():
		return false
	var elapsed := config.dash_duration - _active_remaining
	return elapsed < config.invulnerability_seconds - 0.000001


func can_attack() -> bool:
	return true


func can_guard() -> bool:
	return true


func get_knockback_multiplier() -> float:
	return 1.0


func get_active_direction() -> Vector2:
	return _direction


func _tick_dash(body: CharacterBody2D, delta: float) -> void:
	var step := minf(delta, _active_remaining)
	var start := body.global_position
	body.velocity = _direction * config.dash_speed * (1.0 + equipment_speed_bonus)
	body.move_and_slide()
	if _scripted and body.get_slide_collision_count() == 0 and body.global_position.distance_to(_scripted_destination) <= config.dash_speed * (1.0 + equipment_speed_bonus) * delta + 1.0:
		body.global_position = _scripted_destination
		_active_remaining = 0.0
	_perform_collision_sweep(body, start)
	for index in body.get_slide_collision_count():
		if body.get_slide_collision(index).get_normal().dot(_direction) < -0.1:
			_cancelled = true
			_active_remaining = 0.0
			body.velocity = Vector2.ZERO
			break
	_active_remaining = maxf(_active_remaining - step, 0.0)
	if not is_dashing():
		body.velocity = body.velocity.limit_length(config.walk_speed * (1.0 + equipment_speed_bonus))
		_finish_dash()


func _finish_dash() -> void:
	var cancelled := _cancelled
	_active_remaining = 0.0
	_hits.clear()
	_cancelled = false
	_scripted = false
	dash_ended.emit(cancelled)
	_direction = Vector2.ZERO
	active_effect_kind = &"dash"


func _perform_collision_sweep(body: CharacterBody2D, start: Vector2) -> void:
	var end := body.global_position
	var distance := start.distance_to(end)
	var shape := CapsuleShape2D.new()
	shape.radius = config.collision_radius
	shape.height = distance + 2.0 * config.collision_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D((end - start).angle() - PI / 2.0, (start + end) * 0.5)
	query.collision_mask = 16
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var space := body.get_world_2d().direct_space_state
	for hit in space.intersect_shape(query, 64):
		var hurt := hit.collider as HurtBox2DComponent
		if hurt == null or hurt.faction != CombatFaction.Id.ENEMY or not is_instance_valid(hurt.actor):
			continue
		var target := hurt.actor
		var id := target.get_instance_id()
		if _hits.has(id):
			continue
		var sight := PhysicsRayQueryParameters2D.create(start, target.global_position, 1)
		if not space.intersect_ray(sight).is_empty():
			continue
		_hits[id] = true
		var packet := DamagePacket.new()
		packet.base_damage = config.collision_damage
		packet.source = body
		packet.source_faction = CombatFaction.Id.PLAYER
		packet.source_position = start
		packet.travel_direction = _direction
		packet.stagger_seconds = config.collision_stagger_seconds
		packet.is_melee = true
		var result := hurt.receive_hit(packet)
		if result.final_damage > 0 and not result.target_defeated and target.has_method("apply_stagger"):
			target.apply_stagger(config.collision_stagger_seconds)


func _terrain_multiplier() -> float:
	return 0.7 if terrain_tag in [&"mud", &"rubble"] else 1.0
