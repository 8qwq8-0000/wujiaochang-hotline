extends Node2D

## Sparse deterministic scenery, generated once. Never touches gameplay RNG.
const DEBRIS := preload("res://assets/art/effects/bomb/debris_sheet_v1.png")
var details: Array[Dictionary] = []
var _textures: Dictionary = {}

func _ready() -> void:
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)
	var room := get_parent() as CombatRoom
	if room == null or room.layout == null:
		return
	var run := get_node_or_null("/root/RunManager")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["floor_clutter_v1", run.run_seed if run else 1, run.floor_index if run else 0, room.area_index, room.layout.id])
	for kind in ["blood", "stone", "metal", "door"]:
		var wanted := 3 if kind == "blood" else rng.randi_range(10, 14)
		var made := 0
		for attempt in 700:
			if made >= wanted:
				break
			var size := rng.randf_range(24, 42) if kind == "blood" else rng.randf_range(8, 18)
			var point := Vector2(rng.randf_range(40, room.ROOM_SIZE.x - 40), rng.randf_range(40, room.ROOM_SIZE.y - 40)).round()
			if not is_clear(room, point, size * 0.65 + 4):
				continue
			details.append({"kind": kind, "position": point, "size": size, "rotation": rng.randf_range(-PI,PI), "variant": rng.randi_range(0,15), "alpha": rng.randf_range(0.55,0.8), "cluster": rng.randi_range(2,4)})
			made += 1
	queue_redraw()

func is_clear(room: CombatRoom, point: Vector2, radius: float) -> bool:
	var box := Rect2(point - Vector2.ONE * radius, Vector2.ONE * radius * 2)
	if not Rect2(Vector2(24,24), room.ROOM_SIZE - Vector2(48,48)).encloses(box):
		return false
	for blocker in room.layout.covers + room.layout.windows + room.layout.navigation_obstacles + room.small_obstacles:
		if blocker.grow(6).intersects(box):
			return false
	for door in room.layout.doors:
		if EncounterPropPlacement.door_bounds(door, 30, 24).intersects(box):
			return false
	for lane in room.layout.clear_lanes:
		if lane.grow(6).intersects(box):
			return false
	for object in room.get_children():
		if object is PowerBox or object is FuelBarrel or object is ExitElevator:
			if point.distance_to(object.position) < radius + 46:
				return false
	for entry in [Vector2(24, room.ROOM_SIZE.y * 0.5), Vector2(room.ROOM_SIZE.x - 24, room.ROOM_SIZE.y * 0.5)]:
		if point.distance_to(entry) < radius + 60:
			return false
	for enemy in room.layout.enemy_positions:
		if point.distance_to(enemy) < radius + 22:
			return false
	for detail in details:
		if point.distance_to(detail.position) < radius + detail.size * 0.65 + 12:
			return false
	var blood := room.get_node_or_null("FloorBloodDecals")
	if blood != null:
		for stain in blood.decals:
			if point.distance_to(stain.position) < radius + stain.width * 0.65 + 6:
				return false
	return true

func _texture(kind: String, variant: int) -> Texture2D:
	var key := "%s:%d" % [kind, variant]
	if _textures.has(key):
		return _textures[key]
	var source: Texture2D
	var region: Rect2
	if kind == "blood":
		source = load("res://assets/art/effects/death_blood_spray_v1/stain_%02d.png" % variant)
		region = Rect2(source.get_image().get_used_rect())
	elif kind == "metal":
		source = DEBRIS
		var cell := source.get_size() / Vector2(4,2)
		var index: int = [2,4,5,7][variant % 4]
		var origin := Vector2(index % 4, index / 4) * cell
		var crop := Rect2i(origin, cell)
		region = Rect2(source.get_image().get_region(crop).get_used_rect())
		region.position += origin
	else:
		source = CombatArchitecture.door_texture(false)
		var dimensions := source.get_size()
		region = Rect2(Vector2(0, dimensions.y * (0.15 + (variant % 6) * 0.1)), Vector2(dimensions.x, dimensions.y * 0.06))
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = region
	_textures[key] = atlas
	return atlas

func _draw() -> void:
	for detail in details:
		draw_set_transform(detail.position, detail.rotation)
		var width: float = detail.size
		if detail.kind == "stone":
			for index in detail.cluster:
				var at := Vector2(index * 3 - 4, (index % 2) * 3 - 1)
				var points := PackedVector2Array([at + Vector2(-3,0), at + Vector2(-1,-2), at + Vector2(2,-1), at + Vector2(3,1), at + Vector2(0,3), at + Vector2(-2,2)])
				draw_colored_polygon(points, Color("3f4c53") if index % 2 else Color("536067"))
				draw_line(at + Vector2(-1,-2), at + Vector2(2,-1), Color("758086"),1,false)
		else:
			var texture := _texture(detail.kind, detail.variant)
			var dimensions := texture.get_size()
			var size := dimensions * width / maxf(dimensions.x,dimensions.y)
			var color := Color(0.8,0.74,0.74,detail.alpha) if detail.kind == "blood" else Color(0.6,0.66,0.7,detail.alpha)
			# Flatten scrap into the floor plane so it cannot read as standing loot.
			if detail.kind != "blood":
				size.y *= 0.65
			draw_texture_rect(texture,Rect2(-size * 0.5,size),false,color)
	draw_set_transform(Vector2.ZERO)
