class_name CyberSignalBackdrop
extends Control

var interrupted := true
var _phase := 0.0
var _reduced_motion := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reduced_motion = bool(PlayerConfig.get_config(&"UISettings", &"ReducedFlashes", false))


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if not _reduced_motion:
		_phase += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("060c17"))
	var ratio := maxf(size.x / 640.0, size.y / 360.0)
	draw_set_transform((size - Vector2(640, 360) * ratio) * 0.5, 0, Vector2.ONE * ratio)
	var cyan := Color("57d8de")
	var pink := Color("dc4d9a")
	# Layered silhouettes suggest the district behind an intercepted radio feed.
	for index in 24:
		var x := float(index * 29 - 18)
		var height := 28.0 + fmod(index * 37.0, 104.0)
		var top := 252.0 - height
		draw_rect(Rect2(x, top, 25, height + 50), Color("0d1b2b"))
		draw_line(Vector2(x, top), Vector2(x + 25, top), Color(cyan if index % 3 else pink, 0.18))
		if index % 4 == 0:
			draw_line(Vector2(x + 13, top), Vector2(x + 13, top - 18), Color(cyan, 0.22))
		for row in range(3, int(height - 5), 9):
			for column in 3:
				if (index * 5 + row + column * 7) % 5 < 2:
					draw_rect(Rect2(x + 4 + column * 6, top + row, 2, 3), Color(cyan if column % 2 else pink, 0.15))
	# A low-contrast perspective grid stays outside the dialogue reading surface.
	for x in range(-480, 1121, 64):
		draw_line(Vector2(320 + (x - 320) * 0.15, 245), Vector2(x, 360), Color(cyan, 0.075))
	for index in 9:
		var depth := fmod(index * 0.12 + _phase * 0.018, 1.0)
		var y := 246 + depth * depth * 114
		draw_line(Vector2(0, y), Vector2(640, y), Color(cyan, 0.065))
	for index in 7:
		var x := 20.0 + index * 101
		var start := Vector2(x, 20 + (index % 3) * 17)
		var bend := start + Vector2(24, 23)
		var end := Vector2(x + 24, 108)
		draw_polyline(PackedVector2Array([start, bend, end]), Color(cyan if index % 2 else pink, 0.18), 1)
		draw_circle(start, 2, Color(cyan, 0.35))
	var center := Vector2(550, 70)
	draw_arc(center, 34, 0, TAU, 64, Color(cyan, 0.16), 1, true)
	draw_arc(center, 43, 0.4 + _phase * 0.09, 3.7 + _phase * 0.09, 48, Color(pink, 0.28), 1, true)
	draw_line(center - Vector2(52, 0), center + Vector2(52, 0), Color(cyan, 0.1))
	draw_line(center - Vector2(0, 52), center + Vector2(0, 52), Color(cyan, 0.1))
	draw_string(CyberUITheme.FONT, Vector2(34, 51), "WUJIAOCHANG / PUBLIC RELAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(cyan, 0.65))
	draw_string(CyberUITheme.FONT, Vector2(32, 91), "HOTLINE", HORIZONTAL_ALIGNMENT_LEFT, -1, 35, Color(cyan, 0.17))
	var status := "公共频道 / 信号异常" if interrupted else "专用频道 / 连接稳定"
	draw_string(CyberUITheme.FONT, Vector2(220, 82), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d9968c") if interrupted else Color("6eaab8"))
	draw_string(CyberUITheme.FONT, Vector2(34, 333), "SHANGHAI  /  WJ-05", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(cyan, 0.4))
	draw_string(CyberUITheme.FONT, Vector2(430, 333), "RX  [ 031 ]  //  HOTLINE ACTIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(cyan, 0.4))
	var sweep := fmod(_phase * 15.0, 640)
	draw_line(Vector2(sweep, 0), Vector2(sweep, 360), Color(cyan, 0.035), 16)
	if not _reduced_motion:
		for y in range(0, 360, 4):
			draw_line(Vector2(0, y), Vector2(640, y), Color(0.0, 0.0, 0.0, 0.09))
	draw_set_transform(Vector2.ZERO)
