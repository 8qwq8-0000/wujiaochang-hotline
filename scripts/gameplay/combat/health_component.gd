class_name HealthComponent
extends Node

signal health_changed(current: int, maximum: int, delta: int)
signal damaged(amount: int, packet: DamagePacket)
signal repaired(amount: int)
signal died(packet: DamagePacket)
signal fatal_damage_prevented(packet: DamagePacket)

@export_range(1, 1000, 1) var max_health: int = 3
var current_health: int
var fatal_damage_interceptor: Callable
var last_fatal_damage_prevented := false
var _damage_depth := 0
var resolving_damage: bool:
	get:
		return _damage_depth > 0


func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health, 0)


func configure_max_health(value: int, refill: bool = true) -> void:
	max_health = maxi(value, 1)
	if refill:
		current_health = max_health
	else:
		current_health = mini(current_health, max_health)
	health_changed.emit(current_health, max_health, 0)


func apply_damage(amount: int, packet: DamagePacket) -> int:
	last_fatal_damage_prevented = false
	if amount <= 0 or is_dead():
		return 0
	_damage_depth += 1
	var previous := current_health
	var would_be_fatal := amount >= current_health
	var prevented := false
	if would_be_fatal and fatal_damage_interceptor.is_valid():
		prevented = bool(fatal_damage_interceptor.call(amount, packet))
	last_fatal_damage_prevented = prevented
	current_health = 1 if prevented else maxi(current_health - amount, 0)
	var applied := previous - current_health
	if applied > 0:
		damaged.emit(applied, packet)
	health_changed.emit(current_health, max_health, -applied)
	if prevented:
		fatal_damage_prevented.emit(packet)
	if current_health == 0:
		died.emit(packet)
	_damage_depth -= 1
	return applied


func repair(amount: int) -> int:
	if amount <= 0 or is_dead():
		return 0
	var previous := current_health
	current_health = mini(current_health + amount, max_health)
	var applied := current_health - previous
	if applied > 0:
		repaired.emit(applied)
		health_changed.emit(current_health, max_health, applied)
	return applied


func set_current_health(value: int) -> void:
	current_health = clampi(value, 0, max_health)
	health_changed.emit(current_health, max_health, 0)


func is_dead() -> bool:
	return current_health <= 0
