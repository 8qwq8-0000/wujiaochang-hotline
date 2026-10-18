class_name MobilityController
extends Node

signal mode_changed(index: int, mode: MobilityMode)
signal ability_activated(mode: MobilityMode)
signal ability_cooldown_changed(remaining: float, total: float)

const WALK_MODE := preload("res://resources/mobility/walk.tres")
const DEBUG_MODES := [
	WALK_MODE,
	preload("res://resources/mobility/wheel.tres"),
	preload("res://resources/mobility/quadruped.tres"),
	preload("res://resources/mobility/flight.tres"),
]

var modes: Array[MobilityMode] = []
var current_index: int = 0
var ability_cooldown_remaining: float = 0.0
var terrain_tag: StringName = &"normal"
var debug_loadout_enabled: bool = false
var _current_mode: MobilityMode = WALK_MODE
var _ability_active_remaining: float = 0.0
var _ram_direction := Vector2.ZERO
var _ram_hits: Dictionary = {}


func _ready() -> void:
	for mode in DEBUG_MODES:
		modes.append(mode)
	mode_changed.emit(current_index, _current_mode)


func configure(default_mode: MobilityMode, enable_debug_loadout: bool) -> void:
	debug_loadout_enabled = enable_debug_loadout
	equip_mode(default_mode if default_mode != null else WALK_MODE)


func tick(
	body: CharacterBody2D,
	input_vector: Vector2,
	facing: Vector2,
	delta: float,
	external_velocity: Vector2 = Vector2.ZERO
) -> void:
	ability_cooldown_remaining = maxf(ability_cooldown_remaining - delta, 0.0)
	var locomotion_velocity := body.velocity - external_velocity
	var next_velocity := _current_mode.calculate_velocity(input_vector, locomotion_velocity, facing, delta)
	var ramming := _current_mode is WheelMobilityMode and is_ability_active()
	if ramming:
		# Keep the charge direction and speed for its actual active window.
		next_velocity = _ram_direction * _current_mode.ability_impulse * minf(_ability_active_remaining / maxf(delta, 0.000001), 1.0)
	var start := body.global_position
	body.velocity = next_velocity * _current_mode.terrain_speed_multiplier(terrain_tag) + external_velocity
	body.move_and_slide()
	if ramming:
		_perform_ram(body, start)
		for index in body.get_slide_collision_count():
			if body.get_slide_collision(index).get_normal().dot(_ram_direction) < -0.1:
				_ability_active_remaining = 0.0
				body.velocity = Vector2.ZERO
				break
	_ability_active_remaining = maxf(_ability_active_remaining - delta, 0.0)
	if _ability_active_remaining < 0.000001:
		_ability_active_remaining = 0.0
	if ramming and not is_ability_active():
		body.velocity = body.velocity.limit_length(_current_mode.max_speed)
	ability_cooldown_changed.emit(ability_cooldown_remaining, _current_mode.ability_cooldown)


func activate_ability(body: CharacterBody2D, facing: Vector2, input_vector: Vector2 = Vector2.ZERO) -> bool:
	if _current_mode.ability_cooldown <= 0.0 or ability_cooldown_remaining > 0.0:
		return false
	var heading := facing
	if _current_mode is WheelMobilityMode and not input_vector.is_zero_approx():
		heading = input_vector
	_ram_direction = heading.normalized() if not heading.is_zero_approx() else Vector2.RIGHT
	_ram_hits.clear()
	body.velocity = _current_mode.ability_velocity(_ram_direction, body.velocity)
	ability_cooldown_remaining = _current_mode.ability_cooldown
	_ability_active_remaining = _current_mode.ability_active_seconds
	ability_activated.emit(_current_mode)
	return true


func equip_mode(mode: MobilityMode) -> void:
	_current_mode = mode if mode != null else WALK_MODE
	current_index = _index_for_id(_current_mode.id)
	reset_transient_state()
	mode_changed.emit(current_index, _current_mode)


func equip_mode_by_id(id: StringName) -> bool:
	for mode in modes:
		if mode.id == id:
			equip_mode(mode)
			return true
	return false


func unequip_mode() -> void:
	equip_mode(WALK_MODE)


func set_mode(index: int) -> void:
	if not debug_loadout_enabled or index < 0 or index >= modes.size():
		return
	equip_mode(modes[index])


func get_current_mode() -> MobilityMode:
	return _current_mode


func get_knockback_multiplier() -> float:
	return _current_mode.knockback_multiplier


func can_cross_low_obstacle() -> bool:
	return _current_mode.crosses_low_obstacles


func can_attack() -> bool:
	return _ability_active_remaining <= 0.0 or not _current_mode.locks_attack


func can_guard() -> bool:
	return _ability_active_remaining <= 0.0 or not _current_mode.locks_guard


func reset_transient_state() -> void:
	ability_cooldown_remaining = 0.0
	_ability_active_remaining = 0.0
	_ram_direction = Vector2.ZERO
	_ram_hits.clear()


func _index_for_id(id: StringName) -> int:
	for index in modes.size():
		if modes[index].id == id:
			return index
	return -1


func set_equipped_mode(mode: MobilityMode) -> void:
	equip_mode(mode)


func is_ability_active() -> bool:
	return _ability_active_remaining > 0.0


func provides_invulnerability() -> bool:
	var wheel := _current_mode as WheelMobilityMode
	if wheel == null or not is_ability_active():
		return false
	var elapsed := wheel.ability_active_seconds - _ability_active_remaining
	return elapsed < wheel.ram_invulnerability_seconds - 0.000001


func _perform_ram(body: CharacterBody2D, start: Vector2) -> void:
	var mode := _current_mode as WheelMobilityMode
	var end := body.global_position
	var shape := CapsuleShape2D.new()
	shape.radius = mode.ram_radius
	shape.height = start.distance_to(end) + 2.0 * mode.ram_radius
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
		var enemy := hurt.actor
		var id := enemy.get_instance_id()
		if _ram_hits.has(id):
			continue
		# The contact radius must not damage enemies through a wall.
		var sight := PhysicsRayQueryParameters2D.create(start, enemy.global_position, 1)
		if not space.intersect_ray(sight).is_empty():
			continue
		_ram_hits[id] = true
		var packet := DamagePacket.new()
		packet.base_damage = mode.ram_damage
		packet.source = body
		packet.source_faction = CombatFaction.Id.PLAYER
		packet.source_position = start
		packet.travel_direction = _ram_direction
		packet.stagger_seconds = mode.ram_stagger_seconds
		packet.is_melee = true
		var result := hurt.receive_hit(packet)
		if result.final_damage > 0 and not result.target_defeated and enemy.has_method("apply_stagger"):
			enemy.apply_stagger(mode.ram_stagger_seconds)
