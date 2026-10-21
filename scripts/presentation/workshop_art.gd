class_name WorkshopArt
extends Node2D

## Runtime rendering only: colliders, navigation, objectives and doors stay authored.
const ROOT := "res://assets/art/environment/workshop/"
const REGIONS := {
	"floor": Rect2(0,0,1254,1254),
	"wall": Rect2(35,253,2102,220),
	"machine": Rect2(171,218,1220,583),
	"crate": Rect2(326,241,660,717),
	"console": Rect2(244,209,1285,486),
	"melee": Rect2(307,336,606,578),
	"ranged": Rect2(332,229,529,845),
}
static var _cache: Dictionary = {}
const VISUAL_SEAM_OVERLAP := 2.0
var layout: CombatLayoutData
var floor_pass := false
var left_open := false
var right_open := false

static func asset(key: String) -> Texture2D:
	if not _cache.has(key):
		var texture := AtlasTexture.new()
		texture.atlas = load("res://assets/art/environment/warehouse/floor.png" if key == "floor" else ROOT + key + ".png")
		texture.region = REGIONS[key]
		_cache[key] = texture
	return _cache[key]

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not floor_pass and layout != null:
		y_sort_enabled = true
		rebuild_scenery()
	queue_redraw()

func _draw() -> void:
	if layout == null:
		return
	if floor_pass:
		_draw_floor()
		return
	for window in layout.windows:
		draw_rect(window.grow(2),Color("111e28"))
		draw_rect(window,Color("70dbed"))
		for y in range(int(window.position.y)+4,int(window.end.y),8):
			draw_line(Vector2(window.position.x,y),Vector2(window.end.x,y),Color("c5f8ff"),1)

static func draw_floor_tiles(canvas: CanvasItem, bounds: Rect2) -> void:
	# Match the warehouse source, complete 32-pixel tiles and quiet tint.
	var texture := asset("floor")
	for y in range(int(bounds.position.y), int(bounds.end.y), 32):
		for x in range(int(bounds.position.x), int(bounds.end.x), 32):
			var size := Vector2(minf(32, bounds.end.x - x), minf(32, bounds.end.y - y))
			canvas.draw_texture_rect_region(texture, Rect2(Vector2(x, y), size), Rect2(Vector2.ZERO, texture.get_size() * size / 32.0), Color(0.74, 0.78, 0.82))

func _draw_floor() -> void:
	var size := layout.room_size
	draw_rect(Rect2(Vector2.ZERO, size),Color("101a23"))
	draw_floor_tiles(self, Rect2(Vector2(16, 16), size - Vector2(32, 32)))
	var tints := [Color(0.03,0.18,0.24,0.17),Color(0.08,0.14,0.21,0.10),Color(0.20,0.19,0.08,0.14),Color(0.05,0.1,0.16,0.09),Color(0.12,0.21,0.15,0.16),Color(0.23,0.17,0.08,0.14)]
	for index in layout.zones.size():
		draw_rect(layout.zones[index],tints[index%tints.size()])
	for rect in layout.covers:
		draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size + Vector2(3, 3)), Color(0, 0, 0, 0.25))
	for step in range(5):
		draw_rect(Rect2(16, 16 + step * 2, size.x - 32, 2), Color(0, 0, 0, 0.15 * (1.0 - step / 5.0)))
	for index in mini(6,layout.covers.size()):
		var rect := layout.covers[index]
		if minf(rect.size.x,rect.size.y)>6.1:
			_hazard(rect.grow(5))
	for door in layout.doors:
		var point := Vector2(door.x,door.y)
		for radius in range(44,2,-2):
			draw_circle(point,float(radius),Color(0.95,0.59,0.15,0.006))

func rebuild_scenery() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var size := layout.room_size
	_add_wall(Rect2(0, -12, size.x, 28), "north")
	_add_wall(Rect2(0, size.y - 16, size.x, 20), "south")
	var opening_size := 96.0
	var segment := (size.y - opening_size) * 0.5
	for right: bool in [false, true]:
		var x := size.x - 16.0 if right else 0.0
		var direction := "east" if right else "west"
		if right_open if right else left_open:
			_add_wall(Rect2(x, 16, 16, segment - 16), direction)
			_add_wall(Rect2(x, size.y - segment, 16, segment - 16), direction)
		else:
			_add_wall(Rect2(x, 16, 16, size.y - 32), direction)
	for definition in [["nw", Vector2(0, -12)], ["ne", Vector2(size.x - 18, -12)], ["sw", Vector2(0, size.y - 20)], ["se", Vector2(size.x - 18, size.y - 20)]]:
		var piece := CombatSceneryPiece.new()
		piece.corner = definition[0]
		piece.position = definition[1] + Vector2(0, 28)
		piece.footprint = Rect2(0, -28, 18, 28)
		add_child(piece)
	for index in layout.covers.size():
		var rect := layout.covers[index]
		if minf(rect.size.x, rect.size.y) <= CombatLayoutData.STRUCTURAL_PARTITION_MAX_THICKNESS * CombatRoom.ROOM_SCALE:
			if rect.size.y > rect.size.x:
				_add_wall(Rect2(rect.position - Vector2(0, 12), rect.size + Vector2(0, 12)), "west")
			else:
				_add_wall(Rect2(rect.position - Vector2(0, 16), rect.size + Vector2(0, 16)), "north")
		else:
			var piece := CombatSceneryPiece.new()
			piece.prop = "crate"
			if layout.id == &"loading_workshop":
				piece.prop = "machine" if index == 2 else ("console" if index == 1 else "crate")
			elif index in [0, 2]:
				piece.prop = "console"
			var room := get_parent() as CombatRoom
			if room != null and rect in room.small_obstacles:
				var variant := room.small_obstacles.find(rect) % 3
				piece.prop = "crate" if variant == 0 else ("console" if variant == 1 else "machine")
			piece.position = Vector2(rect.get_center().x, rect.end.y)
			piece.footprint = Rect2(Vector2(-rect.size.x * 0.5, -rect.size.y), rect.size)
			add_child(piece)

func _add_wall(rect: Rect2, direction: String) -> void:
	var piece := CombatSceneryPiece.new()
	piece.direction = direction
	piece.position = Vector2(rect.get_center().x, rect.end.y)
	piece.footprint = Rect2(Vector2(-rect.size.x * 0.5, -rect.size.y), rect.size)
	add_child(piece)

func _hazard(rect: Rect2) -> void:
	draw_rect(rect,Color("171d22"),false,2)
	for x in range(int(rect.position.x),int(rect.end.x)-3,6):
		draw_line(Vector2(x,rect.position.y),Vector2(x+3,rect.position.y),Color("a57e30"),2)
		draw_line(Vector2(x,rect.end.y),Vector2(x+3,rect.end.y),Color("a57e30"),2)
