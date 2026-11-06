extends Control

var circuit_owner_id := 0
var slot_count := 3
var slot_width := 52.0
var edge_padding := 8.0
var preview_requested: Callable
var drop_requested: Callable
var cancel_requested: Callable


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _target_at(local_position: Vector2) -> int:
	return clampi(floori((local_position.x - edge_padding) / slot_width), 0, slot_count - 1)


func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	var valid := data is Dictionary and StringName(data.get("type", "")) == &"cyberware_circuit_module" and int(data.get("owner_id", -1)) == circuit_owner_id
	if not valid:
		return false
	var source_index := int(data.get("source_index", -1))
	if source_index < 0 or source_index >= slot_count:
		return false
	if preview_requested.is_valid():
		preview_requested.call(source_index, _target_at(at_position))
	return true


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position, data):
		return
	var source_index := int(data.get("source_index", -1))
	var target_index := _target_at(at_position)
	if source_index == target_index:
		if cancel_requested.is_valid():
			cancel_requested.call()
	elif drop_requested.is_valid():
		drop_requested.call(source_index, target_index)
