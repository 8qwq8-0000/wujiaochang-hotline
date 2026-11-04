extends Node2D

var floor_index := 0
var shrine := false
var _assets := preload("res://scripts/presentation/warehouse_art.gd").new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -1
	queue_redraw()


func _draw() -> void:
	var color: Color = [Color("75e8df"), Color("f3c579"), Color("ec837b")][floor_index]
	for x in range(16, 624, 128):
		draw_texture_rect(_assets.asset("wall_north_v2"), Rect2(x, -16, mini(128, 624-x), 48), false)
		draw_texture_rect(_assets.asset("wall_south_v2"), Rect2(x, 333, mini(128, 624-x), 24), false)
	if shrine:
		draw_texture_rect(_assets.asset("wall_west_v2"), Rect2(0, 20, 20, 112), false)
		draw_texture_rect(_assets.asset("wall_west_v2"), Rect2(0, 228, 20, 116), false)
	else:
		draw_texture_rect(_assets.asset("wall_west_v2"), Rect2(0, 20, 20, 324), false)
	draw_texture_rect(_assets.asset("wall_east_v2"), Rect2(620, 20, 20, 324), false)
	for x in [90, 290, 490]:
		draw_texture_rect(_assets.asset("lamp"), Rect2(x, 32, 52, 12), false, color)
	draw_texture_rect(_assets.asset("crates"), Rect2(233, 74, 48, 46) if shrine else Rect2(238, 94, 52, 46), false)
	draw_texture_rect(_assets.asset("crates"), Rect2(348, 224, 48, 46) if shrine else Rect2(368, 214, 52, 46), false)
	draw_texture_rect(_assets.asset("parts_rack"), Rect2(565, 55, 42, 65), false)
	draw_texture_rect(_assets.asset("parts_rack"), Rect2(565, 250, 42, 65), false)
	draw_line(Vector2(544, 150), Vector2(544, 65), color.darkened(0.6), 3)
	draw_line(Vector2(544, 65), Vector2(320, 65), color.darkened(0.6), 3)
	draw_string(CyberUITheme.FONT, Vector2(32, 64), ("隐室 / 静默祭坛" if shrine else ["01 / 呼叫档案", "02 / 签名维护", "03 / 回写隔离"][floor_index]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
	for x in range(120, 500, 32):
		draw_line(Vector2(x, 304), Vector2(x + 16, 304), color.darkened(0.65), 2)


func _exit_tree() -> void:
	_assets.free()
