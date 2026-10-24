class_name RockWaveEffect
extends Node2D

signal finished(effect: RockWaveEffect)

var _color := Color("ffe34a")
var _maximum_radius := 48.0
var _duration := 0.15
var _elapsed := 0.0


func play(at_position: Vector2, color: Color, maximum_radius: float, duration: float) -> void:
	global_position = at_position
	_color = color
	_maximum_radius = maxf(maximum_radius, 1.0)
	_duration = maxf(duration, 0.01)
	_elapsed = 0.0
	visible = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()
	if _elapsed >= _duration:
		visible = false
		set_process(false)
		finished.emit(self)


func current_outer_radius() -> float:
	var ratio := clampf(_elapsed / _duration, 0.0, 1.0)
	return minf(_maximum_radius, lerpf(_maximum_radius * 0.22, _maximum_radius * 0.98, ratio) + 2.0)


func _draw() -> void:
	var ratio := clampf(_elapsed / _duration, 0.0, 1.0)
	var fade := 1.0 - ratio
	var base_radius := lerpf(_maximum_radius * 0.22, _maximum_radius * 0.98, ratio)
	var ripple := minf(2.0, _maximum_radius * 0.04) * (1.0 - ratio * 0.5)
	var points := PackedVector2Array()
	for index in 65:
		var angle := TAU * float(index) / 64.0
		var radius := minf(base_radius + sin(angle * 8.0 + ratio * TAU * 2.0) * ripple, _maximum_radius)
		points.append(Vector2.from_angle(angle) * radius)
	var color := _color
	color.a *= fade
	draw_polyline(points, color, 2.0, true)
