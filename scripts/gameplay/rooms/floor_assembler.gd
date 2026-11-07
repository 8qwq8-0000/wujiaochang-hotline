class_name FloorAssembler
extends Node2D

signal floor_assembled(rooms: Array[Node])
signal floor_cleared

const DEFAULT_ROOM := preload("res://scenes/levels/rooms/prototype_combat_room.tscn")

@export_range(1, 8, 1) var room_count: int = 1
@export var sequential_progression := false
@export_range(0.0, 1.0, 0.01) var enemy_drop_chance := 0.30
@export_range(0.0, 1.0, 0.01) var cyberware_drop_chance := 0.18
@export var room_spacing: Vector2 = Vector2(1000.0, 0.0)
@export var room_pool: Array[RoomTemplateData] = []
@export_range(0.0, 256.0, 1.0) var room_camera_north_extension := 0.0

var _chosen_scene_paths := {}
var generated_rooms: Array[Node] = []
var _rooms_remaining: int = 0
var active_area_index := 0
var passages: Array[CombatPassage] = []
var _cleared_ids := {}
var _dropped_cyberware_counts := {}
var _pending_drop_positions: Array[Dictionary] = []
var _loot_rng := RandomNumberGenerator.new()
var _drop_chance_rng := RandomNumberGenerator.new()


func _ready() -> void:
	var events := get_node_or_null("/root/CombatEvents")
	if events != null and not events.entity_defeated.is_connected(_on_entity_defeated):
		events.entity_defeated.connect(_on_entity_defeated)
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
	_dropped_cyberware_counts.clear()
	_pending_drop_positions.clear()
	active_area_index = 0
	_chosen_scene_paths.clear()
	var random := RandomNumberGenerator.new()
	var run_manager := get_node_or_null("/root/RunManager")
	var seed_value: int = run_manager.run_seed if run_manager != null and run_manager.run_seed != 0 else 1
	random.seed = seed_value + 15485863 * (run_manager.floor_index if run_manager != null else 0)
	_loot_rng.seed = seed_value + 7919 * (run_manager.floor_index + 1 if run_manager != null else 1)
	_drop_chance_rng.seed = _loot_rng.seed + 104729
	var floor_number: int = run_manager.floor_index + 1 if run_manager != null else 1
	var difficulty_step := floor_number - 1 if floor_number >= 1 and floor_number <= 3 else 0
	for index in room_count:
		var packed := _choose_room(random, floor_number)
		var room := packed.instantiate()
		room.position = room_spacing * index
		if room is CombatRoom:
			room.get_node("EnemySpawner").health_bonus = difficulty_step
			room.get_node("EnemySpawner").melee_speed_multiplier = 1.0 + 0.1 * difficulty_step
			room.signal_emitter_enabled = difficulty_step >= 1
			room.extra_enemy_count = difficulty_step
			room.camera_north_extension = room_camera_north_extension
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
		passage.position = generated_rooms[index].position + Vector2(CombatRoom.ROOM_SIZE.x - 16.0, CombatRoom.ROOM_SIZE.y * 0.5)
		passage.length = generated_rooms[index + 1].position.x - generated_rooms[index].position.x - (CombatRoom.ROOM_SIZE.x - 32.0)
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
	var equipment_hit := _drop_chance_rng.randf() < enemy_drop_chance
	var cyberware_hit := _drop_chance_rng.randf() < cyberware_drop_chance
	if not equipment_hit and not cyberware_hit:
		return
	var run := get_node_or_null("/root/RunManager")
	var owned_counts := _dropped_cyberware_counts.duplicate()
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if player != null:
		var library_counts := player.cyberware.circuit.get_library_counts()
		for module_id in library_counts:
			owned_counts[module_id] = int(owned_counts.get(module_id, 0)) + int(library_counts[module_id])
	var floor_number: int = run.floor_index + 1 if run != null else 1
	if equipment_hit:
		var equipment := ComponentRolls.floor_equipment_drop(floor_number, _loot_rng)
		_spawn_enemy_drop.call_deferred(room, _reserve_drop_position(room, death_position), equipment, enemy.get_instance_id())
		room.reward_count += 1
	if cyberware_hit:
		var cyberware := ComponentRolls.guaranteed_cyberware_drop(floor_number, _loot_rng, owned_counts)
		for module_id in ComponentRolls.cyberware_modules(cyberware):
			_dropped_cyberware_counts[module_id] = int(_dropped_cyberware_counts.get(module_id, 0)) + 1
		_spawn_enemy_drop.call_deferred(room, _reserve_drop_position(room, death_position), cyberware, enemy.get_instance_id())
		room.reward_count += 1


func _reserve_drop_position(room: CombatRoom, origin: Vector2) -> Vector2:
	var occupied: Array[Vector2] = []
	for child in room.get_children():
		if child is ComponentPickup and not child.is_queued_for_deletion():
			occupied.append(child.global_position)
	for pending in _pending_drop_positions:
		if int(pending.room_id) == room.get_instance_id():
			occupied.append(Vector2(pending.position))
	var room_bounds := Rect2(Vector2.ONE * 24.0, CombatRoom.ROOM_SIZE - Vector2.ONE * 48.0)
	for radius in [0.0, 56.0, 84.0, 112.0, 140.0, 168.0, 196.0]:
		for step in 8:
			var angle := TAU * float(step) / 8.0
			var candidate: Vector2 = origin + Vector2.RIGHT.rotated(angle) * float(radius)
			if not _drop_position_reachable(room, candidate, room_bounds):
				continue
			var clear := true
			for position in occupied:
				if candidate.distance_to(position) < 54.0:
					clear = false
					break
			if clear:
				_pending_drop_positions.append({"room_id": room.get_instance_id(), "position": candidate})
				return candidate
	var fallback_candidates: Array[Vector2] = []
	for x in range(24, int(CombatRoom.ROOM_SIZE.x) - 24, 24):
		for y in range(24, int(CombatRoom.ROOM_SIZE.y) - 24, 24):
			fallback_candidates.append(room.to_global(Vector2(x, y)))
	fallback_candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.distance_squared_to(origin) < b.distance_squared_to(origin))
	for candidate in fallback_candidates:
		if not _drop_position_reachable(room, candidate, room_bounds):
			continue
		var clear := true
		for position in occupied:
			if candidate.distance_to(position) < 54.0:
				clear = false
				break
		if clear:
			_pending_drop_positions.append({"room_id": room.get_instance_id(), "position": candidate})
			return candidate
	push_error("No reachable pickup position in combat room %s" % room.name)
	return origin


func _drop_position_reachable(room: CombatRoom, candidate: Vector2, bounds: Rect2) -> bool:
	if not bounds.has_point(room.to_local(candidate)):
		return false
	var shape := CircleShape2D.new()
	shape.radius = 18.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, candidate)
	query.collision_mask = 1
	if not room.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	var navigation := room.get_node_or_null("NavigationRegion2D") as NavigationRegion2D
	if navigation == null or navigation.navigation_polygon == null:
		return true
	var map := navigation.get_navigation_map()
	var closest := NavigationServer2D.map_get_closest_point(map, candidate)
	if closest.distance_to(candidate) > 16.0:
		return false
	var anchor := room.to_global(CombatRoom.ROOM_SIZE * 0.5)
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	if player != null and room.contains_world_point(player.global_position):
		anchor = player.global_position
	var path := NavigationServer2D.map_get_path(map, anchor, candidate, true)
	return not path.is_empty() and path[-1].distance_to(candidate) <= 16.0


func _on_entity_defeated(entity: Node) -> void:
	if not entity is EnemyController or entity.state != EnemyController.State.DEAD:
		return
	var owner_node := entity.get_parent()
	while owner_node != null and not owner_node is CombatRoom:
		owner_node = owner_node.get_parent()
	var room := owner_node as CombatRoom
	if room == null or room.get_parent() != self:
		return
	try_enemy_drop(entity, room, entity.global_position)


func _spawn_enemy_drop(room: CombatRoom, death_position: Vector2, item: InventoryItem, enemy_id: int) -> void:
	if not is_instance_valid(room):
		return
	for index in range(_pending_drop_positions.size() - 1, -1, -1):
		var pending: Dictionary = _pending_drop_positions[index]
		if int(pending.room_id) == room.get_instance_id() and Vector2(pending.position) == death_position:
			_pending_drop_positions.remove_at(index)
			break
	if not is_instance_valid(room) or room.is_queued_for_deletion() or not room.is_inside_tree():
		return
	var pickup: ComponentPickup = load("res://scenes/items/component_pickup.tscn").instantiate()
	pickup.component_id = item.get_prototype().get_prototype_id()
	pickup.rolled_item = item
	pickup.set_meta("enemy_drop", enemy_id)
	room.add_child(pickup)
	pickup.global_position = death_position
