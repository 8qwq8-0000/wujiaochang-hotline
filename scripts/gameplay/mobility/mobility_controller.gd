class_name MobilityController
extends Node

signal mode_changed(index: int, mode: MobilityMode)
signal ability_activated(mode: MobilityMode)
signal ability_cooldown_changed(remaining: float, total: float)

const DEFAULT_MODES := [
	preload("res://resources/mobility/walk.tres"),
	preload("res://resources/mobility/wheel.tres"),
	preload("res://resources/mobility/quadruped.tres"),
	preload("res://resources/mobility/flight.tres"),
]

var modes: Array[MobilityMode] = []
var current_index: int = 0
var ability_cooldown_remaining: float = 0.0
var terrain_tag: StringName = &"normal"


func _ready() -> void:
	for mode in DEFAULT_MODES:
		modes.append(mode)
	mode_changed.emit(current_index, get_current_mode())


func tick(body: CharacterBody2D, input_vector: Vector2, facing: Vector2, delta: float) -> void:
	var mode := get_current_mode()
	ability_cooldown_remaining = maxf(ability_cooldown_remaining - delta, 0.0)
	var next_velocity := mode.calculate_velocity(input_vector, body.velocity, facing, delta)
	body.velocity = next_velocity * mode.terrain_speed_multiplier(terrain_tag)
	body.move_and_slide()
	ability_cooldown_changed.emit(ability_cooldown_remaining, mode.ability_cooldown)


func activate_ability(body: CharacterBody2D, facing: Vector2) -> bool:
	var mode := get_current_mode()
	if mode.ability_cooldown <= 0.0 or ability_cooldown_remaining > 0.0:
		return false
	body.velocity = mode.ability_velocity(facing, body.velocity)
	ability_cooldown_remaining = mode.ability_cooldown
	ability_activated.emit(mode)
	return true


func set_mode(index: int) -> void:
	if index < 0 or index >= modes.size() or index == current_index:
		return
	current_index = index
	ability_cooldown_remaining = 0.0
	mode_changed.emit(current_index, get_current_mode())


func get_current_mode() -> MobilityMode:
	return modes[current_index]


func get_knockback_multiplier() -> float:
	return get_current_mode().knockback_multiplier


func can_cross_low_obstacle() -> bool:
	return get_current_mode().crosses_low_obstacles
