class_name HeatComponent
extends Node

signal heat_changed(current: float, maximum: float)
signal overheated
signal recovered

@export_range(1.0, 1000.0, 1.0) var max_heat: float = 100.0
@export_range(0.0, 1000.0, 1.0) var dissipation_per_second: float = 24.0
@export_range(0.0, 1.0, 0.01) var recovery_ratio: float = 0.35

var current_heat: float = 0.0
var is_overheated: bool = false


func _physics_process(delta: float) -> void:
	if current_heat <= 0.0:
		return
	set_heat(current_heat - dissipation_per_second * delta)
	if is_overheated and current_heat <= max_heat * recovery_ratio:
		is_overheated = false
		recovered.emit()


func try_add_heat(amount: float) -> bool:
	if is_overheated:
		return false
	set_heat(current_heat + maxf(amount, 0.0))
	if current_heat >= max_heat:
		is_overheated = true
		overheated.emit()
	return true


func reduce_heat(amount: float) -> void:
	set_heat(current_heat - maxf(amount, 0.0))
	if is_overheated and current_heat <= max_heat * recovery_ratio:
		is_overheated = false
		recovered.emit()


func set_heat(value: float) -> void:
	current_heat = clampf(value, 0.0, max_heat)
	heat_changed.emit(current_heat, max_heat)
