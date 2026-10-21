class_name CombatArchitecture
extends RefCounted

## Reuse authored four-way architecture without rotating its vertical faces.
const ROOT := "res://assets/art/environment/warehouse/"
const REGIONS := {
	"north": Rect2(62, 75, 2048, 574),
	"south": Rect2(52, 218, 2068, 317),
	"west": Rect2(388, 78, 248, 1382),
	"east": Rect2(408, 45, 208, 1446),
	"nw": Rect2(93, 107, 260, 420),
	"ne": Rect2(750, 96, 314, 380),
	"sw": Rect2(86, 820, 220, 300),
	"se": Rect2(985, 730, 249, 328),
}
const FILES := {"north": "wall_north_v2", "south": "wall_south_v2", "west": "wall_west_v2", "east": "wall_east_v2", "nw": "corner_nw_v2", "ne": "corner_ne_v2", "sw": "corner_sw_v2", "se": "corner_se_v2"}
static var _textures: Dictionary = {}

static func door_texture(horizontal: bool) -> Texture2D:
	var key := "door_horizontal_v1" if horizontal else "door_vertical_v1"
	if not _textures.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = load("res://assets/art/environment/combat_architecture/" + key + ".png")
		atlas.region = Rect2(111, 113, 1951, 544) if horizontal else Rect2(152, 194, 421, 1781)
		_textures[key] = atlas
	return _textures[key]

static func door_rect(horizontal: bool, opening: float) -> Rect2:
	return Rect2(-opening * 0.5, -20, opening, 28) if horizontal else Rect2(-8, -opening * 0.5, 16, opening)

static func door(canvas: CanvasItem, horizontal: bool, opening: float, opened: bool) -> void:
	var source := door_texture(horizontal)
	var rect := door_rect(horizontal, opening)
	if not opened:
		canvas.draw_texture_rect(source, rect, false)
		return
	# Broken leaves disappear. Only the two end jambs remain, so the whole
	# collision opening is visibly traversable instead of a black door panel.
	var source_size := source.get_size()
	var jamb := 0.075
	for end: int in [0, 1]:
		var fraction := float(end) * (1.0 - jamb)
		var uv := Rect2(Vector2(source_size.x * fraction, 0) if horizontal else Vector2(0, source_size.y * fraction), source_size * (Vector2(jamb, 1) if horizontal else Vector2(1, jamb)))
		var destination := Rect2(rect.position + rect.size * (Vector2(fraction, 0) if horizontal else Vector2(0, fraction)), rect.size * (Vector2(jamb, 1) if horizontal else Vector2(1, jamb)))
		canvas.draw_texture_rect_region(source, destination, uv)

static func texture(key: String) -> Texture2D:
	if not _textures.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = load(ROOT + FILES[key] + ".png")
		atlas.region = REGIONS[key]
		_textures[key] = atlas
	return _textures[key]

static func wall(canvas: CanvasItem, rect: Rect2, direction: String) -> void:
	var source := texture(direction)
	var vertical := direction in ["west", "east"]
	var length := rect.size.y if vertical else rect.size.x
	var repeat_length := 128.0 if vertical else 160.0
	var cursor := 0.0
	# A solid backing closes faint alpha seams without changing source pixels.
	canvas.draw_rect(rect, Color("222c37"))
	while cursor < length - 0.01:
		var span := minf(repeat_length, length - cursor)
		var destination := Rect2(rect.position + (Vector2(0, cursor) if vertical else Vector2(cursor, 0)), Vector2(rect.size.x, span) if vertical else Vector2(span, rect.size.y))
		var fraction := Vector2(1, span / repeat_length) if vertical else Vector2(span / repeat_length, 1)
		canvas.draw_texture_rect_region(source, destination, Rect2(Vector2.ZERO, source.get_size() * fraction))
		cursor += span
