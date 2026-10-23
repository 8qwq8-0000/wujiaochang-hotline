class_name EncounterPropPlacement
extends RefCounted

const BLAST_REACH := 92.0 # Leave a margin inside FuelPatch's 96 px explosion.
const CLEARANCE := 22.0
const POWER_CLEARANCE := 32.0 # Half the 64 px terminal artwork.
const MIN_ENEMY_DISTANCE := 32.0
const ENTRY := Vector2(74, 180)
const EXIT := Vector2(592, 180)
const ELEVATOR_EXIT := Vector2(606, 280)


static func choose_power_position(layout: CombatLayoutData, seed_value: int) -> Vector2:
	if layout.power_spawn_zones.is_empty():
		return layout.power_position
	var blockers: Array[Rect2] = []
	blockers.append_array(layout.covers)
	blockers.append_array(layout.windows)
	blockers.append_array(layout.clear_lanes)
	blockers.append_array(layout.navigation_obstacles)
	var candidates: Array[Vector2] = []
	for y in range(48, int(layout.room_size.y) - 38, 8):
		for x in range(48, int(layout.room_size.x) - 38, 8):
			var point := Vector2(x, y)
			var allowed := false
			for index in layout.power_spawn_zones:
				if index >= 0 and index < layout.zones.size() and layout.zones[index].grow(-POWER_CLEARANCE).has_point(point):
					allowed = true
					break
			if not allowed or not is_safe(point, layout.enemy_positions, blockers, layout.doors, Vector2(INF, INF), layout.room_size):
				continue
			var terminal_bounds := Rect2(point - Vector2(POWER_CLEARANCE, POWER_CLEARANCE), Vector2.ONE * POWER_CLEARANCE * 2)
			var footprint := power_footprint(point).grow(8)
			var obstructed := false
			for rect in layout.covers + layout.windows:
				obstructed = obstructed or terminal_bounds.intersects(rect)
			for lane in layout.clear_lanes:
				obstructed = obstructed or footprint.intersects(lane)
			for enemy in layout.enemy_positions:
				obstructed = obstructed or terminal_bounds.grow(8).has_point(enemy)
			if obstructed:
				continue
			var near_door := false
			for door in layout.doors:
				near_door = near_door or door_bounds(door, 40, 32).has_point(point) or door_bounds(door, 12, 8).intersects(footprint)
			if not near_door:
				candidates.append(point)
	if candidates.is_empty():
		push_error("No safe power station position in eligible zones: %s" % layout.id)
		return layout.power_position
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	return candidates[random.randi_range(0, candidates.size() - 1)]

static func power_footprint(point: Vector2) -> Rect2:
	# Upright artwork extends above the actual floor collision shape.
	return Rect2(point + Vector2(-32, 4), Vector2(64, 28))


static func choose_barrel_position(enemies: Array[Vector2], blockers: Array[Rect2], doors: Array[Vector4], power: Vector2, seed_value: int, fallback: Vector2, windows: Array[Rect2] = [], room_size := Vector2(640, 360)) -> Vector2:
	if enemies.is_empty():
		return fallback
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var anchors: Array[Vector2] = []
	anchors.append_array(enemies)
	for index in enemies.size():
		for other in range(index + 1, enemies.size()):
			if enemies[index].distance_to(enemies[other]) <= BLAST_REACH * 2:
				anchors.append((enemies[index] + enemies[other]) * 0.5)
	var candidates: Array[Vector2] = []
	for anchor in anchors:
		candidates.append(anchor)
		for attempt in 48:
			candidates.append(anchor + Vector2.from_angle(random.randf_range(0, TAU)) * random.randf_range(24, 64))
	var sight_blockers := blockers.duplicate()
	# Glass blocks walking, but does not shield actors from FuelPatch damage.
	for window in windows:
		sight_blockers.erase(window)
	for door in doors:
		sight_blockers.append(door_bounds(door, 3.0, 0.0))
	var best_count := 0
	var best_distance := INF
	var viable: Array[Vector2] = []
	var distances: Array[float] = []
	for point in candidates:
		if not is_safe(point, enemies, blockers, doors, power, room_size):
			continue
		var count := 0
		var distance := 0.0
		for enemy in enemies:
			var separation := point.distance_to(enemy)
			if separation <= BLAST_REACH and clear_segment(point, enemy, sight_blockers):
				count += 1
				distance += separation
		if count == 0 or count < best_count:
			continue
		if count > best_count:
			best_count = count
			best_distance = INF
			viable.clear()
			distances.clear()
		best_distance = minf(best_distance, distance)
		viable.append(point)
		distances.append(distance)
	# Randomize only among similarly close positions around the best group.
	var finalists: Array[Vector2] = []
	for index in viable.size():
		if distances[index] <= best_distance + 24.0:
			finalists.append(viable[index])
	if not finalists.is_empty():
		return finalists[random.randi_range(0, finalists.size() - 1)]
	if is_safe(fallback, enemies, blockers, doors, power, room_size):
		return fallback
	# A dense room may have no viable enemy-adjacent anchor left. Search the
	# walkable footprint deterministically rather than overlap a previous box.
	for y in range(48, int(room_size.y) - 38, 24):
		for x in range(48, int(room_size.x) - 38, 24):
			var point := Vector2(x, y)
			if is_safe(point, enemies, blockers, doors, power, room_size):
				return point
	return fallback


static func is_safe(point: Vector2, enemies: Array[Vector2], blockers: Array[Rect2], doors: Array[Vector4], power: Vector2, room_size := Vector2(640, 360)) -> bool:
	if not Rect2(Vector2(38, 38), room_size - Vector2(76, 76)).has_point(point):
		return false
	var scale_factor := room_size / Vector2(640, 360)
	if point.distance_to(ENTRY * scale_factor) < 112 or point.distance_to(EXIT * scale_factor) < 52 or point.distance_to(power) < 64:
		return false
	# The right-hand passage and final elevator occupy different positions.
	if point.distance_to(ELEVATOR_EXIT * scale_factor) < 64:
		return false
	for rect in blockers:
		if rect.grow(CLEARANCE).has_point(point):
			return false
	for door in doors:
		if door_bounds(door, 27.0, 16.0).has_point(point):
			return false
	for enemy in enemies:
		if point.distance_to(enemy) < MIN_ENEMY_DISTANCE:
			return false
	return true


static func door_bounds(door: Vector4, depth: float, margin: float) -> Rect2:
	var half_width := door.w * 0.5 + margin
	var extent := Vector2(depth, half_width) if absf(sin(door.z)) < 0.5 else Vector2(half_width, depth)
	return Rect2(Vector2(door.x, door.y) - extent, extent * 2)


static func clear_segment(from: Vector2, to: Vector2, blockers: Array[Rect2]) -> bool:
	for rect in blockers:
		if rect.has_point(from) or rect.has_point(to):
			return false
		var outline := CombatLayoutData._outline(rect)
		for index in 4:
			if Geometry2D.segment_intersects_segment(from, to, outline[index], outline[(index + 1) % 4]) != null:
				return false
	return true
