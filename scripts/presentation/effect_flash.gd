class_name EffectFlash
extends Node2D

signal finished(effect: EffectFlash)

var _color := Color.WHITE
var _radius := 8.0
var _duration := 0.18
var _elapsed := 0.0


func play(at_position: Vector2, color: Color, radius: float = 12.0, duration: float = 0.18) -> void:
	global_position = at_position
	_color = color
	_radius = radius
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


func _draw() -> void:
	var ratio := clampf(_elapsed / _duration, 0.0, 1.0)
	var color := _color
	color.a *= 1.0 - ratio
	draw_arc(Vector2.ZERO, _radius * (0.5 + ratio), 0.0, TAU, 24, color, 3.0)
