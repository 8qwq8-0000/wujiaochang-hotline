@tool
extends Polygon2D

## Full floor sigil, clipped at the doorway plane so its wall-side half is hidden.
@export_enum("Down", "Left") var facing := 0:
	set(value):
		facing = value
		_refresh_projection()
@export var tint := Color("68e6ef"):
	set(value):
		tint = value
		_refresh_projection()
@export_range(16, 48, 1) var radius := 32.0:
	set(value):
		radius = value
		_refresh_projection()

var _phase := 0.0
var _proximity := 0.0

func _ready() -> void:
	z_as_relative = false
	z_index = -2
	# Draw a complete circle as a child, then let the wall-plane mask hide
	# the back half. The mask itself is invisible and has no diameter stroke.
	clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	var glyph := get_node_or_null("CircleGeometry") as Node2D
	if glyph == null:
		glyph = Node2D.new()
		glyph.name = "CircleGeometry"
		add_child(glyph)
		glyph.draw.connect(_draw_glyph.bind(glyph))
	_refresh_projection()

func _refresh_projection() -> void:
	var extent := radius + 5
	if facing == 1:
		polygon = PackedVector2Array([Vector2(-extent, -extent), Vector2(0, -extent), Vector2(0, extent), Vector2(-extent, extent)])
	else:
		polygon = PackedVector2Array([Vector2(-extent, 0), Vector2(extent, 0), Vector2(extent, extent), Vector2(-extent, extent)])
	_redraw_glyph()

func _redraw_glyph() -> void:
	var glyph := get_node_or_null("CircleGeometry") as Node2D
	if glyph != null:
		glyph.queue_redraw()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_phase = fmod(_phase + delta, TAU * 10.0)
	var doorway := get_parent()
	var actor := doorway.get_parent().get_node_or_null("Player") as Node2D
	if not is_instance_valid(actor):
		actor = get_tree().get_first_node_in_group("player") as Node2D
	var near: bool = is_instance_valid(actor) and doorway.can_interact(actor)
	_proximity = move_toward(_proximity, 1.0 if near else 0.0, delta * 3.5)
	_redraw_glyph()

func _project(angle: float, distance: float) -> Vector2:
	var point := Vector2.from_angle(angle) * distance
	if facing == 1:
		point = point.rotated(PI * 0.5)
	point.y *= 0.52
	return point

func _arc(canvas: Node2D, distance: float, start: float, end: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in 97:
		points.append(_project(lerpf(start, end, index / 96.0), distance))
	canvas.draw_polyline(points, color, width, true)

func _draw_glyph(canvas: Node2D) -> void:
	var breathing := 0.88 + 0.12 * sin(_phase * 1.8)
	var strength := lerpf(0.45, 1.0, _proximity) * breathing
	# The complete rings and symbols continue beneath the clipping plane.
	_arc(canvas, radius, 0, TAU, Color(tint, 0.07 * strength), 7)
	_arc(canvas, radius, 0, TAU, Color(tint, 0.16 * strength), 3)
	_arc(canvas, radius, 0, TAU, Color(tint, 0.95 * strength), 1)
	_arc(canvas, radius - 6, 0, TAU, Color(tint, 0.65 * strength), 1)
	_arc(canvas, radius * 0.47, 0, TAU, Color(tint, 0.65 * strength), 1)
	for index in 16:
		var angle := TAU * index / 16.0
		canvas.draw_line(_project(angle, radius - 3), _project(angle, radius + 2), Color(tint, 0.85 * strength), 1, true)
	# Runes and radial traces wrap around the whole circle before masking.
	for index in 12:
		var angle := TAU * (index + 0.5) / 12.0
		var center_radius := radius - 10
		var glyph := PackedVector2Array([
			_project(angle, center_radius - 2),
			_project(angle - 0.07, center_radius),
			_project(angle, center_radius + 2),
			_project(angle + 0.07, center_radius),
			_project(angle, center_radius - 2),
		])
		canvas.draw_polyline(glyph, Color(tint, 0.95 * strength), 1, true)
		if index % 2 == 0:
			canvas.draw_line(_project(angle, radius * 0.49), _project(angle, radius - 14), Color(tint, 0.55 * strength), 1, true)
	for offset in [0.0, PI]:
		var triangle := PackedVector2Array()
		for index in 4:
			triangle.append(_project(offset + (index % 3) * TAU / 3.0, radius * 0.32))
		canvas.draw_polyline(triangle, Color(tint, 0.5 * strength), 1, true)
