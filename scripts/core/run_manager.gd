extends Node

signal run_started(seed: int)
signal scene_payload_changed(payload: Dictionary)
signal mandatory_enemy_count_changed(remaining: int)

var run_seed: int = 0
var floor_index: int = 0
var scene_payload: Dictionary = {}
var mandatory_enemies_remaining: int = 0


func begin_run(seed_value: int = 0) -> void:
	run_seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	floor_index = 0
	mandatory_enemies_remaining = 0
	run_started.emit(run_seed)


func set_scene_payload(value: Dictionary) -> void:
	scene_payload = value.duplicate(true)
	scene_payload_changed.emit(scene_payload)


func consume_scene_payload() -> Dictionary:
	var payload := scene_payload.duplicate(true)
	scene_payload.clear()
	return payload


func set_mandatory_enemy_count(value: int) -> void:
	mandatory_enemies_remaining = maxi(value, 0)
	mandatory_enemy_count_changed.emit(mandatory_enemies_remaining)


func notify_mandatory_enemy_defeated() -> void:
	set_mandatory_enemy_count(mandatory_enemies_remaining - 1)
