class_name RoomTemplateData
extends Resource

@export var id: StringName = &"room"
@export var scene: PackedScene
@export_range(0.01, 100.0, 0.01) var weight: float = 1.0
@export_range(1, 99, 1) var minimum_floor: int = 1
@export_range(1, 99, 1) var maximum_floor: int = 99
@export var tags: PackedStringArray = []


func is_available_for_floor(floor_index: int) -> bool:
	return scene != null and floor_index >= minimum_floor and floor_index <= maximum_floor
