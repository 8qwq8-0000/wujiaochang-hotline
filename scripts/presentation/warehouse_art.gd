@tool
extends Node2D

## Modular, presentation-only warehouse assembly. Physics and services stay on
## their existing nodes. Every texture is a separately generated source asset.
const ROOT := "res://assets/art/environment/warehouse/"
# Opaque bounds ignore faint AI alpha speckles in the transparent margins.
# Source pixels stay untouched; AtlasTexture only selects the visible region.
const REGIONS := {
	"floor": Rect2(0, 0, 1254, 1254),
	"wall": Rect2(100, 174, 1783, 438),
	"chest": Rect2(221, 170, 1227, 612),
	"workbench": Rect2(183, 76, 1163, 873),
	"terminal": Rect2(137, 208, 1021, 844),
	"elevator": Rect2(116, 82, 1080, 1021),
	"training_door": Rect2(74, 107, 1010, 1115),
	"parts_rack": Rect2(164, 138, 1046, 872),
	"crates": Rect2(96, 152, 1493, 635),
	"lamp": Rect2(56, 118, 2060, 439),
	"wall_north_v2": Rect2(62, 75, 2048, 574),
	"wall_south_v2": Rect2(52, 218, 2068, 317),
	"wall_west_v2": Rect2(388, 78, 248, 1382),
	"wall_east_v2": Rect2(408, 45, 208, 1446),
	# Select the elbow itself; the generated L arms would shrink the joint
	# and leave transparent holes if the entire sprite were squeezed here.
	"corner_nw_v2": Rect2(93, 107, 260, 420),
	"corner_ne_v2": Rect2(750, 96, 314, 380),
	"corner_sw_v2": Rect2(86, 820, 220, 300),
	"corner_se_v2": Rect2(985, 730, 249, 328),
}
var textures: Dictionary = {}

func asset(id: String) -> Texture2D:
	if not textures.has(id):
		var source := load(ROOT + id + ".png") as Texture2D
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = REGIONS[id]
		textures[id] = atlas
	return textures[id]

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()
	if Engine.is_editor_hint():
		return
	get_parent().self_modulate = Color(1, 1, 1, 0)
	for child in get_children():
		if child is Sprite2D and str(child.name).begins_with("WallLamp"):
			add_lamp_light(child.position + Vector2(0, 21))

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func add_lamp_light(at: Vector2) -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var mask := GradientTexture2D.new()
	mask.gradient = gradient
	mask.width = 96
	mask.height = 96
	mask.fill = GradientTexture2D.FILL_RADIAL
	mask.fill_from = Vector2(0.5, 0.5)
	mask.fill_to = Vector2(1, 0.5)
	var light := PointLight2D.new()
	light.name = "CyanWallLight"
	light.position = at
	light.texture = mask
	light.color = Color("76d8e7")
	light.energy = 0.22
	light.blend_mode = Light2D.BLEND_MODE_ADD
	light.shadow_enabled = false
	add_child(light)

func _draw() -> void:
	var bounds := _visible_bounds()
	draw_rect(bounds, Color("0b111a"))
	# Let the floor run beneath the wall sprites so transparent edge pixels
	# cannot reveal the dark room backing as a seam.
	var floor_left := bounds.position.x + 16.0
	var floor_right := bounds.end.x - 16.0
	var floor_top := bounds.position.y + 32.0
	var floor_bottom := bounds.end.y - 24.0
	draw_rect(Rect2(floor_left, floor_top, floor_right - floor_left, floor_bottom - floor_top), Color("202d3b"))
	var y := floor_top
	while y < floor_bottom:
		var x := floor_left
		while x < floor_right:
			var size := Vector2(minf(32.0, floor_right - x), minf(32.0, floor_bottom - y))
			draw_texture_rect_region(asset("floor"), Rect2(Vector2(x, y), size), Rect2(Vector2.ZERO, asset("floor").get_size() * size / 32.0), Color(0.74, 0.78, 0.82))
			x += 32.0
		y += 32.0
	# Surface-mounted conduits; entry guidance lives on each door.
	draw_line(Vector2(floor_left + 8.0, floor_bottom - 11.0), Vector2(205, floor_bottom - 11.0), Color("31444c"), 3)
	draw_line(Vector2(205, floor_bottom - 11.0), Vector2(205, floor_bottom - 31.0), Color("31444c"), 3)

func _draw_foreground(canvas: Node2D) -> void:
	var bounds := _visible_bounds()
	var x := bounds.position.x + 32.0
	while x < bounds.end.x - 32.0:
		var width := minf(128.0, bounds.end.x - 32.0 - x)
		var texture := asset("wall_south_v2")
		canvas.draw_texture_rect_region(texture, Rect2(x, bounds.end.y - 40.0, width, 40.0), Rect2(Vector2.ZERO, texture.get_size() * Vector2(width / 128.0, 1)))
		x += 128.0
	canvas.draw_texture_rect(asset("corner_sw_v2"), Rect2(bounds.position.x, bounds.end.y - 40.0, 32, 40), false)
	canvas.draw_texture_rect(asset("corner_se_v2"), Rect2(bounds.end.x - 32.0, bounds.end.y - 40.0, 32, 40), false)

func _draw_walls(canvas: Node2D) -> void:
	var bounds := _visible_bounds()
	# Back wall has real facade height. Sidewalls are separately authored in
	# their final orientation; no facade, pipe or light gets turned sideways.
	var x := bounds.position.x + 32.0
	while x < bounds.end.x - 32.0:
		var width := minf(128.0, bounds.end.x - 32.0 - x)
		canvas.draw_texture_rect_region(asset("wall_north_v2"), Rect2(x, bounds.position.y, width, 40), Rect2(Vector2.ZERO, asset("wall_north_v2").get_size() * Vector2(width / 128.0, 1)))
		x += 128.0
	var y := bounds.position.y + 40.0
	while y < bounds.end.y - 40.0:
		var height := minf(96.0, bounds.end.y - 40.0 - y)
		for wall_info in [["wall_west_v2", bounds.position.x], ["wall_east_v2", bounds.end.x - 24.0]]:
			var texture := asset(wall_info[0])
			canvas.draw_texture_rect_region(texture, Rect2(wall_info[1], y, 24, height), Rect2(Vector2.ZERO, texture.get_size() * Vector2(1, height / 96.0)))
		y += 96.0
	canvas.draw_texture_rect(asset("corner_nw_v2"), Rect2(bounds.position.x, bounds.position.y, 32, 40), false)
	canvas.draw_texture_rect(asset("corner_ne_v2"), Rect2(bounds.end.x - 32.0, bounds.position.y, 32, 40), false)
	for step in range(6):
		var tint := Color(0.12, 0.19, 0.24, 0.12 * (1.0 - step / 6.0))
		canvas.draw_rect(Rect2(bounds.position.x + 24.0, bounds.position.y + 40.0 + step * 2.0, bounds.size.x - 48.0, 2.0), tint)
		canvas.draw_rect(Rect2(bounds.position.x + 24.0 + step, bounds.position.y + 42.0, 1.0, bounds.size.y - 82.0), tint)
		canvas.draw_rect(Rect2(bounds.end.x - 25.0 - step, bounds.position.y + 42.0, 1.0, bounds.size.y - 82.0), tint)


func _visible_bounds() -> Rect2:
	var size := get_viewport_rect().size
	return Rect2(Vector2(320, 180) - size * 0.5, size)
