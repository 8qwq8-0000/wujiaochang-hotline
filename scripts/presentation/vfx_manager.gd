class_name VFXManager
extends Node2D

const EFFECT_SCENE := preload("res://scenes/presentation/effect_flash.tscn")
const DAMAGE_NUMBER_SCENE := preload("res://scenes/presentation/damage_number.tscn")

@export_range(1, 256, 1) var total_effect_budget: int = 64
@export_range(1, 128, 1) var prewarm_count: int = 12

var _available: Array[EffectFlash] = []
var _active: Array[EffectFlash] = []
var _available_numbers: Array[DamageNumber] = []
var _active_numbers: Array[DamageNumber] = []


func _ready() -> void:
	for _index in prewarm_count:
		_available.append(_create_effect())
		_available_numbers.append(_create_damage_number())
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.damage_resolved.connect(_on_damage_resolved)


func spawn_flash(world_position: Vector2, color: Color, radius: float, duration: float = 0.18) -> void:
	var effect: EffectFlash
	if not _available.is_empty():
		effect = _available.pop_back()
	elif _active.size() < total_effect_budget:
		effect = _create_effect()
	else:
		effect = _active.pop_front()
	_active.append(effect)
	effect.play(world_position, color, radius, duration)


func _create_effect() -> EffectFlash:
	var effect: EffectFlash = EFFECT_SCENE.instantiate()
	add_child(effect)
	effect.visible = false
	effect.set_process(false)
	effect.finished.connect(_release_effect)
	return effect


func _create_damage_number() -> DamageNumber:
	var number: DamageNumber = DAMAGE_NUMBER_SCENE.instantiate()
	add_child(number)
	number.visible = false
	number.set_process(false)
	number.finished.connect(_release_damage_number)
	return number


func _release_effect(effect: EffectFlash) -> void:
	_active.erase(effect)
	if not _available.has(effect):
		_available.append(effect)


func _spawn_damage_number(world_position: Vector2, amount: int) -> void:
	var number: DamageNumber
	if not _available_numbers.is_empty():
		number = _available_numbers.pop_back()
	elif _active_numbers.size() < total_effect_budget:
		number = _create_damage_number()
	else:
		number = _active_numbers.pop_front()
	_active_numbers.append(number)
	number.play(world_position, amount, Color(1.0, 0.92, 0.72))


func _release_damage_number(number: DamageNumber) -> void:
	_active_numbers.erase(number)
	if not _available_numbers.has(number):
		_available_numbers.append(number)


func _on_damage_resolved(result: DamageResult) -> void:
	if not is_instance_valid(result.target):
		return
	var target := result.target as Node2D
	match result.outcome:
		DamageResult.Outcome.REFLECTED, DamageResult.Outcome.PERFECT_BLOCKED:
			spawn_flash(target.global_position, Color(1.0, 0.75, 0.15), 21.0, 0.24)
		DamageResult.Outcome.BLOCKED:
			spawn_flash(target.global_position, Color(0.25, 0.8, 1.0), 15.0)
		DamageResult.Outcome.DAMAGED:
			spawn_flash(target.global_position, Color(1.0, 0.25, 0.2), 11.0, 0.14)
			_spawn_damage_number(target.global_position, result.final_damage)
