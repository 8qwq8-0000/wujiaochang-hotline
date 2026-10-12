class_name FloorAssembler
extends Node2D

signal floor_assembled(rooms: Array[Node])
signal floor_cleared

const DEFAULT_ROOM := preload("res://scenes/levels/rooms/prototype_combat_room.tscn")

@export_range(1, 8, 1) var room_count: int = 1
@export var room_spacing: Vector2 = Vector2(680.0, 0.0)
@export var room_pool: Array[RoomTemplateData] = []

var generated_rooms: Array[Node] = []
var _rooms_remaining: int = 0


func _ready() -> void:
	assemble()


func assemble() -> void:
	for old_room in generated_rooms:
		if is_instance_valid(old_room):
			old_room.queue_free()
	generated_rooms.clear()
	var random := RandomNumberGenerator.new()
	var run_manager := get_node_or_null("/root/RunManager")
	var seed_value: int = run_manager.run_seed if run_manager != null and run_manager.run_seed != 0 else 1
	random.seed = seed_value
	var floor_number: int = run_manager.floor_index + 1 if run_manager != null else 1
	for index in room_count:
		var packed := _choose_room(random, floor_number)
		var room := packed.instantiate()
		add_child(room)
		room.position = room_spacing * index
		if room.has_signal("room_cleared"):
			room.room_cleared.connect(_on_room_cleared.bind(room))
		generated_rooms.append(room)
	_rooms_remaining = generated_rooms.size()
	floor_assembled.emit(generated_rooms)


func choose_weighted_index(weights: PackedFloat32Array, roll: float) -> int:
	var total := 0.0
	for weight in weights:
		total += maxf(weight, 0.0)
	if total <= 0.0:
		return -1
	var cursor := clampf(roll, 0.0, 0.999999) * total
	for index in weights.size():
		cursor -= maxf(weights[index], 0.0)
		if cursor < 0.0:
			return index
	return weights.size() - 1


func _choose_room(random: RandomNumberGenerator, floor_number: int) -> PackedScene:
	var candidates: Array[RoomTemplateData] = []
	var weights := PackedFloat32Array()
	for data in room_pool:
		if data != null and data.is_available_for_floor(floor_number):
			candidates.append(data)
			weights.append(data.weight)
	if candidates.is_empty():
		return DEFAULT_ROOM
	var index := choose_weighted_index(weights, random.randf())
	return candidates[index].scene


func _on_room_cleared(_room: Node) -> void:
	_rooms_remaining = maxi(_rooms_remaining - 1, 0)
	if _rooms_remaining > 0:
		return
	floor_cleared.emit()
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_floor_cleared()
