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
		texture.atlas = load(ROOT + key + ".png")
		texture.region = REGIONS[key]
		_cache[key] = texture
	return _cache[key]

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	queue_redraw()

func _draw() -> void:
	if layout == null:
		return
	if floor_pass:
		_draw_floor()
		return
	_draw_perimeter()
	for index in layout.covers.size():
		var rect := layout.covers[index]
		if minf(rect.size.x,rect.size.y) <= 6.1:
			_beam(rect)
		else:
			var key := "crate"
			if layout.id == &"loading_workshop":
				key = "machine" if index == 2 else ("console" if index == 1 else "crate")
			elif index in [0,2]:
				key = "console"
			_prop(key,rect)
	# Wall-mounted consoles are shallow decorations outside the usable travel lane.
	_prop("console",Rect2(35,22,62,22))
	_prop("console",Rect2(290,19,66,15))
	_prop("console",Rect2(365,323,72,17))
	for window in layout.windows:
		draw_rect(window.grow(2),Color("111e28"))
		draw_rect(window,Color("70dbed"))
		for y in range(int(window.position.y)+4,int(window.end.y),8):
			draw_line(Vector2(window.position.x,y),Vector2(window.end.x,y),Color("c5f8ff"),1)
	for door in layout.doors:
		var tangent := Vector2.from_angle(door.z + PI/2)
		var normal := Vector2.from_angle(door.z)
		for side: int in [-1,1]:
			var jamb := Vector2(door.x,door.y) + tangent * (door.w/2 + 3) * side
			draw_line(jamb-normal*3,jamb+normal*3,Color("f7c56b"),2)

func _draw_floor() -> void:
	var size := layout.room_size
	draw_rect(Rect2(Vector2.ZERO, size),Color("101a23"))
	var texture := asset("floor")
	var cell := texture.get_size()/4.0
	for y in range(16,int(size.y)-16,24):
		for x in range(16,int(size.x)-16,24):
			var tile := Rect2(x,y,minf(24,size.x-16-x),minf(24,size.y-16-y))
			var source := Rect2(Vector2((x/24)%4,(y/24)%4)*cell,cell*tile.size/24.0)
			draw_texture_rect_region(texture,tile,source,Color(0.73,0.79,0.83))
	var tints := [Color(0.03,0.18,0.24,0.17),Color(0.08,0.14,0.21,0.10),Color(0.20,0.19,0.08,0.14),Color(0.05,0.1,0.16,0.09),Color(0.12,0.21,0.15,0.16),Color(0.23,0.17,0.08,0.14)]
	for index in layout.zones.size():
		draw_rect(layout.zones[index],tints[index%tints.size()])
	for index in mini(6,layout.covers.size()):
		var rect := layout.covers[index]
		if minf(rect.size.x,rect.size.y)>6.1:
			_hazard(rect.grow(5))
	for door in layout.doors:
		var point := Vector2(door.x,door.y)
		for radius in range(44,2,-2):
			draw_circle(point,float(radius),Color(0.95,0.59,0.15,0.006))

func _draw_perimeter() -> void:
	var size := layout.room_size
	_beam(Rect2(0,0,size.x,16))
	_beam(Rect2(0,size.y-16,size.x,16))
	var opening_size := 96.0
	var segment_size := (size.y - opening_size) * 0.5
	for right: bool in [false,true]:
		var x: float = size.x - 16.0 if right else 0.0
		var opened := right_open if right else left_open
		if opened:
			_beam(Rect2(x,0,16,segment_size))
			_beam(Rect2(x,size.y-segment_size,16,segment_size))
		else:
			_beam(Rect2(x,0,16,size.y))

func _beam(rect: Rect2) -> void:
	var vertical := rect.size.y > rect.size.x
	# Bleed two pixels past each collider endpoint so adjacent wall and door
	# pieces cannot expose a background seam under linear texture filtering.
	var length := (rect.size.y if vertical else rect.size.x) + VISUAL_SEAM_OVERLAP * 2.0
	var width := maxf(10,minf(rect.size.x,rect.size.y))
	draw_set_transform(rect.get_center(),PI/2 if vertical else 0)
	var texture := asset("wall")
	var cursor := -length/2
	while cursor < length/2-0.1:
		var segment := minf(64,length/2-cursor)
		draw_texture_rect_region(texture,Rect2(cursor,-width/2,segment,width),Rect2(0,0,texture.get_width()*segment/64,texture.get_height()))
		cursor += segment
	draw_set_transform(Vector2.ZERO)

func _prop(key: String, rect: Rect2) -> void:
	draw_rect(Rect2(rect.position+Vector2(2,3),rect.size),Color(0,0,0,0.28))
	if key == "crate" and rect.size.x > rect.size.y * 1.8:
		# Two adjacent square boxes fit a long cover collider without squashing art.
		var size := minf(rect.size.y,rect.size.x/2)
		for side: int in [-1,1]:
			var center := rect.get_center()+Vector2(side*size/2,0)
			draw_texture_rect(asset(key),Rect2(center-Vector2.ONE*size/2,Vector2.ONE*size),false)
	else:
		draw_texture_rect(asset(key),rect.grow(1),false)

func _hazard(rect: Rect2) -> void:
	draw_rect(rect,Color("171d22"),false,2)
	for x in range(int(rect.position.x),int(rect.end.x)-3,6):
		draw_line(Vector2(x,rect.position.y),Vector2(x+3,rect.position.y),Color("a57e30"),2)
		draw_line(Vector2(x,rect.end.y),Vector2(x+3,rect.end.y),Color("a57e30"),2)
