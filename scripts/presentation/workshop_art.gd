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
const PUMP := preload("res://assets/art/environment/industrial_maps/open_pump_skid.png")
const GRATE := preload("res://assets/art/environment/industrial_maps/trench_grate.png")
const SCANNER_BELT := preload("res://assets/art/environment/industrial_maps/parcel_inspection_line.png")
const BELT := preload("res://assets/art/environment/industrial_maps/roller_belt_module.png")
const CHUTE := preload("res://assets/art/environment/industrial_maps/parcel_diverter.png")
# These props follow the authored cover order for each room.
const PUMP_SERVICE_FIXTURES := [
	preload("res://assets/art/environment/industrial_maps/hose_reel.png"),
	preload("res://assets/art/environment/industrial_maps/covered_spare_pump.png"),
	preload("res://assets/art/environment/industrial_maps/mechanic_tool_chest.png"),
	preload("res://assets/art/environment/industrial_maps/gas_cylinder_pair.png"),
]
const SORTING_SHELF := preload("res://assets/art/environment/industrial_maps/parcel_staging_shelf.png")
const SORTING_CAGE := preload("res://assets/art/environment/industrial_maps/rolling_parcel_cage.png")
const SORTING_SCALE := preload("res://assets/art/environment/industrial_maps/parcel_scale.png")
const SORTING_WALL_FAN := preload("res://assets/art/environment/industrial_maps/sorting_wall_fan.png")
const SORTING_WALL_CONTROL := preload("res://assets/art/environment/industrial_maps/sorting_wall_control.png")
const PUMP_WALL_PIPE_INDICES := [8, 9]
const WALL_PIPES := preload("res://assets/art/environment/industrial_maps/wall_pipe_run.png")
const PARCEL_CAGE := preload("res://assets/art/environment/industrial_maps/parcel_cage.png")
const WET_DRAIN := preload("res://assets/art/environment/industrial_maps/wet_drain.png")
static var _cache: Dictionary = {}
const VISUAL_SEAM_OVERLAP := 2.0
var layout: CombatLayoutData
var floor_pass := false
var left_open := false
var right_open := false

static func asset(key: String) -> Texture2D:
	if not _cache.has(key):
		var texture := AtlasTexture.new()
		var root := "res://assets/art/environment/warehouse/" if key == "floor" else ROOT
		texture.atlas = load(root + key + ".png")
		texture.region = REGIONS[key]
		_cache[key] = texture
	return _cache[key]

func _ready() -> void:
	# Smooth the repeated floor only; actors and hard-surface props retain
	# discrete edges through their own nearest-filtered render nodes.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if floor_pass and layout != null and layout.id == &"loading_workshop" else CanvasItem.TEXTURE_FILTER_NEAREST
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
	if layout.id == &"freight_atrium":
		_draw_freight_markings()
	elif layout.id == &"dual_track_depot":
		_draw_depot_markings()
	elif layout.id == &"underground_pump_station":
		_draw_pump_station_markings()
	elif layout.id == &"urban_sorting_center":
		_draw_sorting_markings()
	for index in layout.covers.size():
		if layout.id == &"underground_pump_station" and index in PUMP_WALL_PIPE_INDICES:
			continue
		var rect := layout.covers[index]
		draw_rect(Rect2(rect.position + Vector2(2, 3), rect.size + Vector2(3, 3)), Color(0, 0, 0, 0.25))
	if layout.id == &"underground_pump_station":
		_draw_pump_wall_pipes()
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
		if layout.id == &"underground_pump_station" and index in PUMP_WALL_PIPE_INDICES:
			continue
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
			elif layout.id == &"freight_atrium":
				piece.prop = "machine" if index in [1, 3] else ("console" if index in [0, 4, 10] else "crate")
			elif layout.id == &"dual_track_depot":
				piece.prop = "machine" if index in [1, 4, 6, 10] else ("console" if index in [2, 5, 8, 11] else "crate")
			elif layout.id == &"underground_pump_station" and index < 2:
				piece.fixture = PUMP
				piece.flip_fixture = index == 1
			elif layout.id == &"underground_pump_station" and index in [2, 3]:
				piece.prop = "console"
			elif layout.id == &"underground_pump_station" and index >= 10 and index < 10 + PUMP_SERVICE_FIXTURES.size():
				piece.fixture = PUMP_SERVICE_FIXTURES[index - 10]
			elif layout.id == &"urban_sorting_center" and index < 3:
				piece.fixture = [SCANNER_BELT, BELT, CHUTE][index]
			elif layout.id == &"urban_sorting_center" and index in [3, 4, 9]:
				piece.fixture = SORTING_SHELF
			elif layout.id == &"urban_sorting_center" and index == 10:
				piece.fixture = SORTING_CAGE
			elif layout.id == &"urban_sorting_center" and index == 11:
				piece.fixture = SORTING_SCALE
			elif layout.id == &"urban_sorting_center" and index in [6, 7, 8]:
				piece.fixture = PARCEL_CAGE
				piece.flip_fixture = index == 7
			elif index in [0, 2]:
				piece.prop = "console"
			var room := get_parent() as CombatRoom
			if room != null and rect in room.small_obstacles:
				var variant := room.small_obstacles.find(rect) % 3
				piece.prop = "crate" if variant == 0 else ("console" if variant == 1 else "machine")
			piece.position = Vector2(rect.get_center().x, rect.end.y)
			piece.footprint = Rect2(Vector2(-rect.size.x * 0.5, -rect.size.y), rect.size)
			add_child(piece)
	if layout.id == &"loading_workshop":
		_add_workshop_light(Vector2(175, 410), Color("68c7dc"), 0.25)
		_add_workshop_light(Vector2(770, 155), Color("ffc27a"), 0.19)

func _add_workshop_light(at: Vector2, tint: Color, energy: float) -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var mask := GradientTexture2D.new()
	mask.width = 128
	mask.height = 128
	mask.gradient = gradient
	mask.fill = GradientTexture2D.FILL_RADIAL
	mask.fill_from = Vector2(0.5, 0.5)
	mask.fill_to = Vector2(1.0, 0.5)
	var light := PointLight2D.new()
	light.name = "WorkshopPracticalLight"
	light.position = at
	light.texture = mask
	light.texture_scale = 3.5
	light.color = tint
	light.energy = energy
	light.blend_mode = Light2D.BLEND_MODE_ADD
	add_child(light)

func _draw_freight_markings() -> void:
	var scale_factor := layout.room_size / Vector2(640, 360)
	var yellow := Color(0.72, 0.59, 0.28, 0.46)
	var pale := Color(0.54, 0.69, 0.70, 0.28)
	# Painted transport lanes and bay stencils use only native drawing; all
	# physical architecture and furniture retain the existing sprite assets.
	for y in [174, 208]:
		draw_dashed_line(Vector2(145, y) * scale_factor, Vector2(610, y) * scale_factor, yellow, 2, 12)
	for x in [240, 330, 420, 550]:
		var center := Vector2(x, 191) * scale_factor
		draw_polyline(PackedVector2Array([center + Vector2(-5, -6), center + Vector2(3, 0), center + Vector2(-5, 6)]), yellow, 2)
	for bounds: Rect2 in [Rect2(150, 278, 93, 54), Rect2(448, 278, 94, 58), Rect2(535, 278, 74, 58)]:
		var rect := Rect2(bounds.position * scale_factor, bounds.size * scale_factor)
		draw_rect(rect, pale, false, 2)
		for index in range(4):
			var from := rect.position + Vector2(index * 9, 0)
			draw_line(from, from + Vector2(8, 9), yellow, 2)
	for entry in [[Vector2(45, 132), "检修 03"], [Vector2(215, 90), "控制"], [Vector2(449, 91), "电力 03"], [Vector2(240, 244), "货运 03"], [Vector2(150, 338), "A 区"], [Vector2(371, 338), "B 区"]]:
		draw_string(CyberUITheme.FONT, entry[0] * scale_factor, entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.62, 0.73, 0.70, 0.35))


func _draw_depot_markings() -> void:
	var ratio := layout.room_size / Vector2(960, 540)
	var yellow := Color(0.68, 0.55, 0.24, 0.52)
	var pale := Color(0.47, 0.69, 0.69, 0.32)
	# The freight bands are painted staging beds, never solid islands.
	for x in [260, 566]:
		var bed := Rect2(Vector2(x, 46) * ratio, Vector2(146, 448) * ratio)
		draw_rect(bed, Color(0.45, 0.34, 0.13, 0.13))
		draw_rect(bed, yellow, false, 2)
		for rail_x in [x + 8, x + 138]:
			draw_dashed_line(Vector2(rail_x, 48) * ratio, Vector2(rail_x, 492) * ratio, yellow, 2, 12)
		for y in range(56, 490, 16):
			draw_line(Vector2(x + 14, y) * ratio, Vector2(x + 132, y) * ratio, Color(0.52, 0.49, 0.31, 0.15), 1)
	for index in 3:
		var y: float = [108.0, 270.0, 432.0][index]
		var crossing := Rect2(Vector2(146, y - 22) * ratio, Vector2(670, 44) * ratio)
		draw_rect(crossing, Color(0.12, 0.32, 0.36, 0.15))
		for edge in [y - 22, y + 22]:
			draw_dashed_line(Vector2(146, edge) * ratio, Vector2(816, edge) * ratio, pale, 1, 14)
		for x in [226, 728]:
			var center := Vector2(x, y) * ratio
			draw_polyline(PackedVector2Array([center + Vector2(-5, -6), center + Vector2(3, 0), center + Vector2(-5, 6)]), pale, 2)
		draw_string(CyberUITheme.FONT, Vector2(462, y + 5) * ratio, "%02d" % (index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, pale)
	for entry in [[Vector2(277, 35), "货运 A"], [Vector2(583, 35), "货运 B"], [Vector2(418, 510), "转运 04"]]:
		draw_string(CyberUITheme.FONT, entry[0] * ratio, entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.65, 0.65, 0.46, 0.47))


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


func _draw_pump_wall_pipes() -> void:
	for index in PUMP_WALL_PIPE_INDICES:
		var bounds := layout.covers[index]
		# The art tucks under the wall edge while the nav outlines stay inside it.
		bounds.position.y = 12.0
		bounds.size.y += 6.0
		draw_texture_rect(WALL_PIPES, bounds, false, Color(0.85, 0.88, 0.91))


func _draw_pump_station_markings() -> void:
	var upper := layout.covers[0]
	var lower := layout.covers[1]
	var lower_console := layout.covers[3]
	var bend := Vector2(upper.end.x + 61, upper.end.y - 22)
	var join_y := lower_console.get_center().y
	draw_texture_rect(GRATE, Rect2(upper.end.x - 4, bend.y - 11, 76, 22), false)
	draw_set_transform(bend, PI * 0.5)
	draw_texture_rect(GRATE, Rect2(0, -11, join_y - bend.y + 11, 22), false)
	draw_set_transform(Vector2.ZERO)
	draw_texture_rect(GRATE, Rect2(bend.x - 11, join_y - 11, lower_console.position.x - bend.x + 21, 22), false)
	for index in 2:
		var bed := layout.covers[index].merge(layout.covers[index + 2]).grow(15)
		_draw_service_bay(bed)
	for puddle in [Rect2(151, 323, 102, 72), Rect2(649, 110, 104, 74), Rect2(711, 434, 75, 53)]:
		draw_texture_rect(WET_DRAIN, puddle, false, Color(0.89, 0.96, 1.0, 0.66))
	for y in [77, 469]:
		draw_dashed_line(Vector2(74, y), Vector2(887, y), Color(0.61, 0.51, 0.32, 0.33), 1, 12)


func _draw_sorting_markings() -> void:
	var ochre := Color(0.67, 0.55, 0.29, 0.48)
	var upper_bay := layout.covers[0].merge(layout.covers[3]).merge(layout.covers[6]).grow(12)
	var lower_bay := layout.covers[1].merge(layout.covers[2]).merge(layout.covers[4]).merge(layout.covers[9]).merge(layout.covers[10]).grow(12)
	_draw_service_bay(upper_bay)
	_draw_service_bay(lower_bay)
	draw_string(CyberUITheme.FONT, Vector2(upper_bay.end.x - 146, upper_bay.position.y + 20), "01", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ochre)
	draw_string(CyberUITheme.FONT, lower_bay.position + Vector2(14, 20), "02", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ochre)
	for index in range(3, 12):
		if index == 5:
			continue
		var dock := layout.covers[index].grow(5)
		draw_line(dock.position, Vector2(dock.position.x, dock.end.y), ochre, 1)
		draw_line(Vector2(dock.end.x, dock.position.y), dock.end, ochre, 1)
		draw_dashed_line(Vector2(dock.position.x, dock.end.y), dock.end, ochre, 1, 5)
	draw_dashed_line(Vector2(106, 416), Vector2(848, 141), ochre, 2, 15)
	# These wall fixtures sit above floor traffic and have no footprint.
	for run in [Vector2(74, 288), Vector2(570, 902)]:
		draw_line(Vector2(run.x, 23), Vector2(run.y, 23), Color("10161d"), 7)
		draw_line(Vector2(run.x, 21), Vector2(run.y, 21), Color("424951"), 2)
	draw_texture_rect(SORTING_WALL_FAN, Rect2(772, 16, 67, 37), false)
	draw_texture_rect(SORTING_WALL_CONTROL, Rect2(92, 16, 21, 34), false)
	draw_texture_rect(SORTING_WALL_CONTROL, Rect2(598, 16, 21, 34), false)
	for anchor in [Vector2(50, 270), Vector2(886, 270)]:
		for index in 3:
			var point: Vector2 = anchor + Vector2(index * 9, 0)
			draw_polyline(PackedVector2Array([point + Vector2(-4, -7), point + Vector2(3, 0), point + Vector2(-4, 7)]), ochre, 2)


func _draw_service_bay(bounds: Rect2) -> void:
	var ochre := Color(0.61, 0.49, 0.28, 0.52)
	draw_rect(bounds, Color(0.60, 0.43, 0.19, 0.09))
	draw_rect(bounds, ochre, false, 2)
	for offset in range(8, int(bounds.size.x) - 12, 12):
		var point := Vector2(bounds.position.x + offset, bounds.end.y - 2)
		draw_line(point, point + Vector2(8, -6), ochre, 2)
