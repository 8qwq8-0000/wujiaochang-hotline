class_name CircuitBreakerComponent
extends Node

signal equipped_changed(equipped: bool)
signal circuit_breaker_triggered

const CIRCUIT_BREAKER_ID := &"circuit_breaker"

@export var equipped: bool = true

var circuit_breaker_used: bool = false


func set_equipped(value: bool) -> void:
	if equipped == value:
		return
	equipped = value
	equipped_changed.emit(equipped)


func try_prevent_fatal_damage() -> bool:
	if not equipped or circuit_breaker_used:
		return false
	circuit_breaker_used = true
	circuit_breaker_triggered.emit()
	return true


func reset_for_new_run() -> void:
	circuit_breaker_used = false


func export_state() -> Dictionary:
	return {
		"equipped": equipped,
		"circuit_breaker_used": circuit_breaker_used,
	}


func import_state(state: Dictionary) -> void:
	# Compatibility with run-state snapshots created by the former CoreController.
	var next_equipped := bool(state.get("equipped", state.get("circuit_breaker_armed", equipped)))
	if state.has("core_id"):
		next_equipped = StringName(state.get("core_id", "")) == CIRCUIT_BREAKER_ID and next_equipped
	equipped = next_equipped
	circuit_breaker_used = bool(state.get("circuit_breaker_used", false))
	equipped_changed.emit(equipped)
