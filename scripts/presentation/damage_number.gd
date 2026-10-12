class_name DamageNumber
extends Node2D

signal finished(number: DamageNumber)

@onready var label: Label = $Label
var _duration := 0.55
var _elapsed := 0.0


func play(at_position: Vector2, amount: int, color: Color) -> void:
	global_position = at_position
	label.text = str(amount)
	label.modulate = color
	_elapsed = 0.0
	visible = true
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	position.y -= 26.0 * delta
	label.modulate.a = 1.0 - clampf(_elapsed / _duration, 0.0, 1.0)
	if _elapsed >= _duration:
		visible = false
		set_process(false)
		finished.emit(self)
