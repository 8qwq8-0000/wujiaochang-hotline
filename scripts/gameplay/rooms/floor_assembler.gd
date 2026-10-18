class_name FloorAssembler
extends Node2D

signal floor_assembled(rooms: Array[Node])
signal floor_cleared

const DEFAULT_ROOM := preload("res://scenes/levels/rooms/prototype_combat_room.tscn")

@export_range(1, 8, 1) var room_count: int = 1
@export var sequential_progression := false
@export var room_spacing: Vector2 = Vector2(680.0, 0.0)
@export var room_pool: Array[RoomTemplateData] = []

var generated_rooms: Array[Node] = []
var _rooms_remaining: int = 0
var active_area_index := 0
var passages: Array[CombatPassage] = []
var _cleared_ids := {}
var _guarantee_granted := false
var _loot_rng := RandomNumberGenerator.new()


func _ready() -> void:
	assemble()


func assemble() -> void:
	for old_room in generated_rooms:
		if is_instance_valid(old_room):
			old_room.queue_free()
	generated_rooms.clear()
	for passage in passages:
		passage.queue_free()
	passages.clear()
	_cleared_ids.clear()
	_guarantee_granted = false
	active_area_index = 0
	var random := RandomNumberGenerator.new()
	var run_manager := get_node_or_null("/root/RunManager")
	var seed_value: int = run_manager.run_seed if run_manager != null and run_manager.run_seed != 0 else 1
	random.seed = seed_value
	_loot_rng.seed = seed_value + 7919 * (run_manager.floor_index + 1 if run_manager != null else 1)
	var floor_number: int = run_manager.floor_index + 1 if run_manager != null else 1
	for index in room_count:
		var packed := _choose_room(random, floor_number)
		var room := packed.instantiate()
		room.position = room_spacing * index
		if sequential_progression and room is CombatRoom:
			room.configure_stage(index, room_count)
		add_child(room)
		if sequential_progression and room is CombatRoom:
			room.spawner.required_remaining_changed.connect(func(_remaining: int) -> void: _refresh_objectives())
		if room.has_signal("room_cleared"):
			room.room_cleared.connect(_on_room_cleared.bind(room))
		generated_rooms.append(room)
	_rooms_remaining = generated_rooms.size()
	if sequential_progression:
		_build_passages()
		call_deferred("_begin_sequence")
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
	if _cleared_ids.has(_room.get_instance_id()):
		return
	_cleared_ids[_room.get_instance_id()] = true
	if not _guarantee_granted and _room is CombatRoom:
		_guarantee_granted = true
		var run := get_node_or_null("/root/RunManager")
		_room.spawn_floor_guarantee(ComponentRolls.floor_drop(run.floor_index + 1 if run != null else 1, _loot_rng))
	_rooms_remaining = maxi(_rooms_remaining - 1, 0)
	if sequential_progression:
		var index := generated_rooms.find(_room)
		if index >= 0 and index < passages.size():
			passages[index].unlock()
		_refresh_objectives()
	if _rooms_remaining > 0:
		return
	if sequential_progression:
		generated_rooms.back().exit_elevator.set_enabled(true)
	floor_cleared.emit()
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_floor_cleared()


func _build_passages() -> void:
	for index in range(generated_rooms.size() - 1):
		generated_rooms[index].open_side("Right")
		generated_rooms[index + 1].open_side("Left")
		var passage := CombatPassage.new()
		passage.position = generated_rooms[index].position + Vector2(624, 180)
		passage.length = generated_rooms[index + 1].position.x - generated_rooms[index].position.x - 608
		add_child(passage)
		passages.append(passage)
	for index in generated_rooms.size():
		if index < generated_rooms.size() - 1:
			generated_rooms[index].exit_elevator.hide()


func _begin_sequence() -> void:
	if generated_rooms.is_empty():
		return
	generated_rooms[0].activate()
	_refresh_objectives()


func _physics_process(_delta: float) -> void:
	if not sequential_progression or active_area_index + 1 >= generated_rooms.size():
		return
	if not generated_rooms[active_area_index].cleared:
		return
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if player == null or player.health.is_dead():
		return
	var next: CombatRoom = generated_rooms[active_area_index + 1]
	if next.contains_world_point(player.global_position):
		active_area_index += 1
		next.activate()
		_refresh_objectives()


func _refresh_objectives() -> void:
	if not sequential_progression or generated_rooms.is_empty():
		return
	var remaining := 0
	for area in generated_rooms:
		remaining += area.spawner.remaining_objectives()
	get_node("/root/RunManager").set_mandatory_enemy_count(remaining)
	var current: CombatRoom = generated_rooms[active_area_index]
	get_node("/root/CombatEvents").combat_area_progress.emit(active_area_index + 1, generated_rooms.size(), current.spawner.remaining_objectives(), current.cleared)
