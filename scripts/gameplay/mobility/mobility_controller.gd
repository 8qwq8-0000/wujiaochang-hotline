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
	_ability_active_remaining = maxf(_ability_active_remaining - delta, 0.0)
	var locomotion_velocity := body.velocity - external_velocity
	var next_velocity := _current_mode.calculate_velocity(input_vector, locomotion_velocity, facing, delta)
	body.velocity = next_velocity * _current_mode.terrain_speed_multiplier(terrain_tag) + external_velocity
	body.move_and_slide()
	ability_cooldown_changed.emit(ability_cooldown_remaining, _current_mode.ability_cooldown)


func activate_ability(body: CharacterBody2D, facing: Vector2) -> bool:
	if _current_mode.ability_cooldown <= 0.0 or ability_cooldown_remaining > 0.0:
		return false
	body.velocity = _current_mode.ability_velocity(facing, body.velocity)
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


func _index_for_id(id: StringName) -> int:
	for index in modes.size():
		if modes[index].id == id:
			return index
	return -1
