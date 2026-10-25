class_name HeatComponent
extends Node

signal heat_changed(current: float, maximum: float)
signal overheated
signal recovered

@export_range(1.0, 1000.0, 1.0) var max_heat: float = 100.0
@export_range(0.0, 1000.0, 1.0) var dissipation_per_second: float = 12.0
@export_range(0.0, 1.0, 0.01) var recovery_ratio: float = 0.35

var current_heat: float = 0.0
var is_overheated: bool = false
var cooling_multiplier := 1.0
var equipment_capacity_bonus := 0.0
var equipment_cooling_bonus := 0.0
var persona_cooling_bonus := 0.0
var overflow_enabled := false

func effective_max() -> float:
	return max_heat * (1.0 + equipment_capacity_bonus)


func _physics_process(delta: float) -> void:
	if current_heat <= 0.0:
		return
	set_heat(current_heat - dissipation_per_second * cooling_multiplier * (1.0 + equipment_cooling_bonus) * (1.0 + persona_cooling_bonus) * delta)
	if is_overheated and current_heat <= effective_max() * recovery_ratio:
		is_overheated = false
		recovered.emit()


func try_add_heat(amount: float) -> bool:
	if is_overheated:
		return false
	set_heat(current_heat + maxf(amount, 0.0))
	if current_heat >= effective_max():
		is_overheated = true
		overheated.emit()
	return true


func add_overflow_heat(amount: float) -> bool:
	overflow_enabled = true
	var was_overheated := is_overheated
	set_heat(current_heat + maxf(amount, 0.0))
	if current_heat >= effective_max():
		is_overheated = true
		if not was_overheated:
			overheated.emit()
	return true


func set_overflow_enabled(enabled: bool) -> void:
	overflow_enabled = enabled
	set_heat(current_heat)


func reduce_heat(amount: float) -> void:
	set_heat(current_heat - maxf(amount, 0.0))
	if is_overheated and current_heat <= effective_max() * recovery_ratio:
		is_overheated = false
		recovered.emit()


func set_heat(value: float) -> void:
	var storage_max := effective_max() * (2.0 if overflow_enabled or current_heat > effective_max() else 1.0)
	current_heat = clampf(value, 0.0, storage_max)
	if current_heat <= effective_max() and not overflow_enabled:
		current_heat = minf(current_heat, effective_max())
	heat_changed.emit(current_heat, effective_max())
