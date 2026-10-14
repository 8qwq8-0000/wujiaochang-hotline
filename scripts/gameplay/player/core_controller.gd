class_name CoreController
extends Node

signal core_changed(core_id: StringName)
signal circuit_breaker_triggered

const CIRCUIT_BREAKER_ID := &"circuit_breaker"

@export var default_core_id: StringName = CIRCUIT_BREAKER_ID
@export var circuit_breaker_armed: bool = true

var equipped_core_id: StringName
var circuit_breaker_used: bool = false


func _ready() -> void:
	equipped_core_id = default_core_id
	core_changed.emit(equipped_core_id)


func equip_core(core_id: StringName, breaker_armed: bool = false) -> void:
	equipped_core_id = core_id
	circuit_breaker_armed = breaker_armed
	circuit_breaker_used = false
	core_changed.emit(equipped_core_id)


func try_prevent_fatal_damage() -> bool:
	if equipped_core_id != CIRCUIT_BREAKER_ID or not circuit_breaker_armed or circuit_breaker_used:
		return false
	circuit_breaker_used = true
	circuit_breaker_triggered.emit()
	return true


func export_state() -> Dictionary:
	return {
		"core_id": String(equipped_core_id),
		"circuit_breaker_armed": circuit_breaker_armed,
		"circuit_breaker_used": circuit_breaker_used,
	}


func import_state(state: Dictionary) -> void:
	equipped_core_id = StringName(state.get("core_id", String(default_core_id)))
	circuit_breaker_armed = bool(state.get("circuit_breaker_armed", circuit_breaker_armed))
	circuit_breaker_used = bool(state.get("circuit_breaker_used", false))
	core_changed.emit(equipped_core_id)
