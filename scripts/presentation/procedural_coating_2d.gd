class_name ProceduralCoating2D
extends Node2D

## Lightweight, deterministic paint marks for static equipment panels.
## Drawing commands are cached by CanvasItem after _draw(), so this node has no
## per-frame cost unless a new seed is configured.

@export var seed_key: StringName = &"coating"
@export_range(1, 3, 1) var mark_count: int = 2
@export var safe_rects: Array[Rect2] = [
	Rect2(4.0, -2.0, 8.0, 4.0),
	Rect2(13.0, -2.0, 9.0, 4.0),
]
@export var accent_colors: Array[Color] = [
	Color("f22991"),
	Color("23d9ee"),
	Color("ff8a24"),
]

var _configured_seed: int = 0
var _marks: Array[Dictionary] = []


func _ready() -> void:
	_rebuild_layout()


func configure(seed_value: int, key: StringName = &"") -> void:
	_configured_seed = seed_value
	if not key.is_empty():
		seed_key = key
	_rebuild_layout()
	queue_redraw()


func get_layout_hash() -> int:
	return hash(str(_marks))


func get_mark_count() -> int:
	return _marks.size()


func _rebuild_layout() -> void:
	_marks.clear()
	if safe_rects.is_empty() or accent_colors.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d" % [seed_key, _configured_seed])
	var count := mini(mark_count, safe_rects.size())
	var available_rects := safe_rects.duplicate()
	for _index in count:
		var rect_index := rng.randi_range(0, available_rects.size() - 1)
		var panel: Rect2 = available_rects.pop_at(rect_index)
		var inset := Vector2(panel.size.x * 0.12, panel.size.y * 0.12)
		var usable := Rect2(panel.position + inset, panel.size - inset * 2.0)
		var center := usable.get_center()
		center += Vector2(
			rng.randf_range(-usable.size.x * 0.12, usable.size.x * 0.12),
			rng.randf_range(-usable.size.y * 0.08, usable.size.y * 0.08)
		)
		var color := accent_colors[rng.randi_range(0, accent_colors.size() - 1)]
		color.a = rng.randf_range(0.72, 0.92)
		var chips: Array[Vector2] = []
		for _chip in rng.randi_range(1, 3):
			chips.append(Vector2(
				rng.randf_range(-usable.size.x * 0.35, usable.size.x * 0.35),
				rng.randf_range(-usable.size.y * 0.28, usable.size.y * 0.28)
			))
		_marks.append({
			"kind": rng.randi_range(0, 3),
			"center": center,
			"size": usable.size * rng.randf_range(0.72, 0.96),
			"flip": -1.0 if rng.randi_range(0, 1) == 0 else 1.0,
			"color": color,
			"chips": chips,
		})


func _draw() -> void:
	for mark in _marks:
		var center: Vector2 = mark["center"]
		var size: Vector2 = mark["size"]
		var color: Color = mark["color"]
		var flip: float = mark["flip"]
		draw_set_transform(center, 0.0, Vector2(flip, 1.0))
		match int(mark["kind"]):
			0:
				_draw_cross(size, color)
			1:
				_draw_chevron(size, color)
			2:
				_draw_broken_stripe(size, color)
			_:
				_draw_arrow(size, color)
		var chip_color := Color(0.08, 0.09, 0.12, color.a * 0.8)
		for chip: Vector2 in mark["chips"]:
			draw_circle(chip, maxf(0.45, size.y * 0.08), chip_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_cross(size: Vector2, color: Color) -> void:
	var half := size * Vector2(0.34, 0.38)
	var width := maxf(0.8, size.y * 0.18)
	draw_line(Vector2(-half.x, -half.y), Vector2(half.x, half.y), color, width)
	draw_line(Vector2(-half.x, half.y), Vector2(half.x, -half.y), color, width)


func _draw_chevron(size: Vector2, color: Color) -> void:
	var width := maxf(0.8, size.y * 0.2)
	var first := PackedVector2Array([
		Vector2(-size.x * 0.32, -size.y * 0.32),
		Vector2(-size.x * 0.05, 0.0),
		Vector2(-size.x * 0.32, size.y * 0.32),
	])
	var second := PackedVector2Array([
		Vector2(size.x * 0.02, -size.y * 0.32),
		Vector2(size.x * 0.29, 0.0),
		Vector2(size.x * 0.02, size.y * 0.32),
	])
	draw_polyline(first, color, width)
	draw_polyline(second, color, width)


func _draw_broken_stripe(size: Vector2, color: Color) -> void:
	var height := maxf(1.0, size.y * 0.42)
	draw_rect(Rect2(-size.x * 0.42, -height * 0.5, size.x * 0.3, height), color)
	draw_rect(Rect2(-size.x * 0.02, -height * 0.5, size.x * 0.42, height), color)


func _draw_arrow(size: Vector2, color: Color) -> void:
	var width := maxf(0.8, size.y * 0.18)
	draw_line(Vector2(-size.x * 0.38, 0.0), Vector2(size.x * 0.24, 0.0), color, width)
	draw_line(Vector2(size.x * 0.08, -size.y * 0.3), Vector2(size.x * 0.34, 0.0), color, width)
	draw_line(Vector2(size.x * 0.34, 0.0), Vector2(size.x * 0.08, size.y * 0.3), color, width)
