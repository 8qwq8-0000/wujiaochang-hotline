extends Node2D

## Static scenery only. A separate RNG never advances combat or loot rolls.
const TEXTURE := preload("res://assets/art/effects/blood/floor_stain_v1.png")
var decals: Array[Dictionary] = []

func _ready() -> void:
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)
	var room := get_parent() as CombatRoom
	if room == null or room.layout == null:
		return
	var run := get_node_or_null("/root/RunManager")
	var random := RandomNumberGenerator.new()
	random.seed = hash(["floor_blood", run.run_seed if run != null else 1, run.floor_index if run != null else 0, room.area_index, room.layout.id])
	var wanted := random.randi_range(3, 5)
	for attempt in 400:
		if decals.size() >= wanted:
			break
		var width := random.randf_range(42, 78)
		var radius := width * 0.65
		var point := Vector2(random.randf_range(32 + radius, room.ROOM_SIZE.x - 32 - radius), random.randf_range(32 + radius, room.ROOM_SIZE.y - 32 - radius))
		if not _is_clear(room, point, radius):
			continue
		decals.append({"position": point, "width": width, "rotation": random.randf_range(-0.3, 0.3), "flip": random.randf() < 0.5, "alpha": random.randf_range(0.7, 0.9)})
	queue_redraw()

func _is_clear(room: CombatRoom, point: Vector2, radius: float) -> bool:
	var bounds := Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2)
	for rect in room.layout.covers + room.layout.windows:
		if rect.grow(8).intersects(bounds):
			return false
	for door in room.layout.doors:
		if EncounterPropPlacement.door_bounds(door, 24, 24).intersects(bounds):
			return false
	for child in room.get_children():
		if child is PowerBox or child is FuelBarrel or child is ExitElevator:
			if point.distance_to(child.position) < radius + 40:
				return false
	for doorway in [Vector2(16, room.ROOM_SIZE.y * 0.5), Vector2(room.ROOM_SIZE.x - 16, room.ROOM_SIZE.y * 0.5)]:
		if point.distance_to(doorway) < radius + 56:
			return false
	for decal in decals:
		if point.distance_to(decal.position) < radius + float(decal.width) * 0.5 + 12:
			return false
	return true

func _draw() -> void:
	for decal in decals:
		var width: float = decal.width
		var size := Vector2(width, width * TEXTURE.get_height() / TEXTURE.get_width())
		draw_set_transform(decal.position, decal.rotation, Vector2(-1 if decal.flip else 1, 1))
		draw_texture_rect(TEXTURE, Rect2(-size * 0.5, size), false, Color(0.8, 0.75, 0.75, decal.alpha), false)
	draw_set_transform(Vector2.ZERO)
