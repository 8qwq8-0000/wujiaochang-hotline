class_name FloorAssembler
extends Node2D

signal floor_assembled(rooms: Array[Node])
signal floor_cleared

const DEFAULT_ROOM := preload("res://scenes/levels/rooms/prototype_combat_room.tscn")

@export_range(1, 8, 1) var room_count: int = 1
@export var sequential_progression := false
@export_range(0.0, 1.0, 0.01) var enemy_drop_chance := 0.20
@export var room_spacing: Vector2 = Vector2(680.0, 0.0)
@export var room_pool: Array[RoomTemplateData] = []

var _chosen_scene_paths := {}
var generated_rooms: Array[Node] = []
var _rooms_remaining: int = 0
var active_area_index := 0
var passages: Array[CombatPassage] = []
var _cleared_ids := {}
var _guaranteed_areas := {}
var _loot_rng := RandomNumberGenerator.new()
var _drop_chance_rng := RandomNumberGenerator.new()


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
	_guaranteed_areas.clear()
	active_area_index = 0
	_chosen_scene_paths.clear()
	var random := RandomNumberGenerator.new()
	var run_manager := get_node_or_null("/root/RunManager")
	var seed_value: int = run_manager.run_seed if run_manager != null and run_manager.run_seed != 0 else 1
	random.seed = seed_value + 15485863 * (run_manager.floor_index if run_manager != null else 0)
	_loot_rng.seed = seed_value + 7919 * (run_manager.floor_index + 1 if run_manager != null else 1)
	_drop_chance_rng.seed = _loot_rng.seed + 104729
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
	if candidates.is_empty():
		return DEFAULT_ROOM
	# Keep authored rooms, but avoid repeating a scene within the floor while
	# unused eligible templates remain. Small custom pools still have a fallback.
	var unused: Array[RoomTemplateData] = []
	for data in candidates:
		if not _chosen_scene_paths.has(data.scene.resource_path):
			unused.append(data)
	if not unused.is_empty():
		candidates = unused
	weights.clear()
	for data in candidates:
		weights.append(data.weight)
	var index := choose_weighted_index(weights, random.randf())
	var selected := candidates[index].scene
	_chosen_scene_paths[selected.resource_path] = true
	return selected


func _on_room_cleared(_room: Node) -> void:
	if _cleared_ids.has(_room.get_instance_id()):
		return
	_cleared_ids[_room.get_instance_id()] = true
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
		passages[active_area_index].seal_return()
		active_area_index += 1
		get_node("/root/CombatEvents").publish_notice(&"return_path_closed", "后方通道已封闭", Color("e6bc73"))
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


func try_enemy_drop(enemy: EnemyController, room: CombatRoom, death_position: Vector2) -> void:
	if room not in generated_rooms or enemy.state != EnemyController.State.DEAD or enemy.has_meta("floor_loot_processed"):
		return
	enemy.set_meta("floor_loot_processed", true)
	# Each area fulfils its own minimum if its previous death rolls all missed.
	# EnemySpawner resolves objectives before CombatEvents publishes the death.
	var area_id := room.get_instance_id()
	var forced := not _guaranteed_areas.has(area_id) and room.cleared
	if not forced and _drop_chance_rng.randf() >= enemy_drop_chance:
		return
	var first_drop := not _guaranteed_areas.has(area_id)
	_guaranteed_areas[area_id] = true
	if first_drop:
		room.reward_count += 1
	var run := get_node_or_null("/root/RunManager")
	var item := ComponentRolls.floor_drop(run.floor_index + 1 if run != null else 1, _loot_rng)
	_spawn_enemy_drop.call_deferred(room, death_position, item, first_drop, enemy.get_instance_id())


func _spawn_enemy_drop(room: CombatRoom, death_position: Vector2, item: InventoryItem, first_drop: bool, enemy_id: int) -> void:
	if not is_instance_valid(room) or room.is_queued_for_deletion() or not room.is_inside_tree():
		return
	var pickup: ComponentPickup = load("res://scenes/items/component_pickup.tscn").instantiate()
	pickup.component_id = item.get_prototype().get_prototype_id()
	pickup.rolled_item = item
	pickup.set_meta("enemy_drop", enemy_id)
	if first_drop:
		pickup.set_meta("area_guarantee", true)
	room.add_child(pickup)
	pickup.global_position = death_position
