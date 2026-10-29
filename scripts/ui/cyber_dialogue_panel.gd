class_name CyberDialoguePanel
extends TerminalPanel

const CYAN := Color("75f5e5")
const MAGENTA := Color("ef4ca8")
var compact := false:
	set(value):
		compact = value
		_update_margins()
var interrupted := false
var _phase := 0.0
var _reduced_motion := false


func _ready() -> void:
	super._ready()
	_reduced_motion = bool(PlayerConfig.get_config(&"UISettings", &"ReducedFlashes", false))
	_update_margins()


func _update_margins() -> void:
	add_theme_constant_override("margin_left", 14 if compact else 24)
	add_theme_constant_override("margin_right", 14 if compact else 24)
	add_theme_constant_override("margin_top", 23 if compact else 46)
	add_theme_constant_override("margin_bottom", 8 if compact else 50)
	queue_redraw()


func set_channel(is_interrupted: bool) -> void:
	interrupted = is_interrupted
	accent_color = Color("ff9973") if interrupted else CYAN
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if not _reduced_motion:
		_phase += delta
	queue_redraw()


func _outline(offset: Vector2, color: Color) -> void:
	var w := size.x
	var h := size.y
	var points := PackedVector2Array([
		Vector2(0, 13), Vector2(13, 0), Vector2(w - 46, 0),
		Vector2(w - 34, 8), Vector2(w - 10, 8), Vector2(w, 18),
		Vector2(w, h - 13), Vector2(w - 13, h), Vector2(32, h),
		Vector2(22, h - 6), Vector2(8, h - 6), Vector2(0, h - 14), Vector2(0, 13),
	])
	for index in points.size():
		points[index] += offset
	draw_polyline(points, color, 1.0, true)


func _draw() -> void:
	if size.x < 40 or size.y < 40:
		return
	var w := size.x
	var h := size.y
	draw_rect(Rect2(-4, 5, w + 8, h), Color(0.0, 0.0, 0.0, 0.35))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 13), Vector2(13, 0), Vector2(w - 46, 0), Vector2(w - 34, 8),
		Vector2(w - 10, 8), Vector2(w, 18), Vector2(w, h - 13), Vector2(w - 13, h),
		Vector2(32, h), Vector2(22, h - 6), Vector2(8, h - 6), Vector2(0, h - 14),
	]), Color("08131ff7"))
	_outline(Vector2(2, 2), Color(MAGENTA, 0.35))
	_outline(Vector2.ZERO, Color(accent_color, 0.85))
	draw_rect(Rect2(14, 1, 83, 3), accent_color)
	draw_rect(Rect2(100, 1, 20, 3), MAGENTA)
	var header_y := 17.0 if compact else 24.0
	draw_string(CyberUITheme.FONT, Vector2(16 if compact else 24, header_y), title, HORIZONTAL_ALIGNMENT_LEFT, w - 170, 10 if compact else 12, accent_color)
	var state_text := "SIGNAL HIJACKED" if interrupted else "LINK SECURED"
	draw_string(CyberUITheme.FONT, Vector2(w - 136, header_y), state_text, HORIZONTAL_ALIGNMENT_RIGHT, 116, 9, Color("ff9973") if interrupted else Color("7b9da7"))
	if compact:
		return
	draw_line(Vector2(24, 34), Vector2(w - 24, 34), Color(accent_color, 0.18))
	for y in range(43, int(h - 44), 4):
		draw_line(Vector2(14, y), Vector2(w - 14, y), Color(0.25, 0.65, 0.76, 0.018))
	draw_rect(Rect2(12, 47, 2, h - 102), Color(accent_color, 0.5))
	draw_line(Vector2(24, h - 42), Vector2(w - 24, h - 42), Color(accent_color, 0.16))
	var wave_center := Vector2(w * 0.5, h - 23)
	for index in 25:
		var amplitude := (2.0 + absf(sin(index * 0.79 + _phase * 3.0)) * 9.0) * (1.0 - absf(index - 12.0) / 15.0)
		var x := wave_center.x + (index - 12) * 3
		draw_line(Vector2(x, wave_center.y - amplitude), Vector2(x, wave_center.y + amplitude), Color(accent_color, 0.45), 1)
	for index in 6:
		draw_rect(Rect2(w - 52 + index * 4, h - 8, 2, 3), Color(MAGENTA if index > 3 else accent_color, 0.6))


static func style_button(button: Button, primary := false) -> void:
	button.theme = CyberUITheme.create_theme()
	button.add_theme_font_size_override("font_size", 12)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var highlighted: bool = state in ["hover", "pressed", "focus"]
		var style := StyleBoxFlat.new()
		style.bg_color = Color("75f5e5") if highlighted else Color("12232e")
		style.border_color = CYAN if primary or highlighted else Color("456574")
		style.set_border_width_all(1)
		style.border_width_left = 4 if primary else 1
		style.content_margin_left = 12
		style.content_margin_right = 12
		if state == "disabled":
			style.bg_color = Color("10202a")
			style.border_color = Color("29434f")
		button.add_theme_stylebox_override(state, style)
		var ink := Color("07121b") if highlighted else (CYAN if primary else Color("9db5c3"))
		if state == "disabled":
			ink = Color("506975")
		button.add_theme_color_override("font_color" if state == "normal" else "font_" + state + "_color", ink)
