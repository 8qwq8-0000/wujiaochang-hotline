extends Node2D

# Reuse the warehouse's original atlas crops; no new image provenance.
const ASSET_ROOT := "res://assets/art/environment/warehouse/"
const CROPS := {
	"floor": Rect2(0, 0, 1254, 1254),
	"wall_north_v2": Rect2(62, 75, 2048, 574),
	"wall_south_v2": Rect2(52, 218, 2068, 317),
	"terminal": Rect2(137, 208, 1021, 844),
	"parts_rack": Rect2(164, 138, 1046, 872),
	"crates": Rect2(96, 152, 1493, 635),
	"elevator": Rect2(116, 82, 1080, 1021),
	"workbench": Rect2(183, 76, 1163, 873),
}
var _textures: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for id in CROPS:
		var atlas := AtlasTexture.new()
		atlas.atlas = load(ASSET_ROOT + id + ".png")
		atlas.region = CROPS[id]
		_textures[id] = atlas
	queue_redraw()


func _draw() -> void:
	if _textures.is_empty():
		return
	draw_rect(Rect2(-1000, -1000, 4000, 2300), Color("090f18"))
	for x in range(32, 2240, 32):
		for y in range(104, 264, 32):
			draw_texture_rect(_textures.floor, Rect2(x, y, 32, 32), false, Color("a4bac7"))
	for x in range(32, 2240, 224):
		var width := minf(224, 2240 - x)
		draw_texture_rect(_textures.wall_north_v2, Rect2(x, 64, width, 48), false)
		draw_texture_rect(_textures.wall_south_v2, Rect2(x, 262, width, 24), false)
	draw_line(Vector2(40, 242), Vector2(2220, 242), Color("54716b"), 2)
	for x in range(100, 2220, 100):
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, 235), Vector2(x + 12, 242), Vector2(x, 249),
			Vector2(x + 4, 242),
		]), Color("72d0bf"))
