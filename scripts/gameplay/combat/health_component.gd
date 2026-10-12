class_name HealthComponent
extends Node

signal health_changed(current: int, maximum: int, delta: int)
signal damaged(amount: int, packet: DamagePacket)
signal repaired(amount: int)
signal died(packet: DamagePacket)

@export_range(1, 1000, 1) var max_health: int = 3
var current_health: int


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
	if amount <= 0 or is_dead():
		return 0
	var previous := current_health
	current_health = maxi(current_health - amount, 0)
	var applied := previous - current_health
	damaged.emit(applied, packet)
	health_changed.emit(current_health, max_health, -applied)
	if current_health == 0:
		died.emit(packet)
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


func is_dead() -> bool:
	return current_health <= 0
