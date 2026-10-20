extends Node2D

const TEXTURE := preload("res://assets/art/weapons/placeholder/rail_cannon_beam.png")
var beam_length := 1000.0
var beam_width := 48.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 5
	add_to_group("laser_beams")
	var tween := create_tween()
	tween.tween_interval(0.24)
	tween.tween_property(self, "modulate:a", 0.0, 0.08)
	tween.tween_callback(queue_free)

func _draw() -> void:
	draw_texture_rect(TEXTURE, Rect2(0.0, -beam_width * 0.5, beam_length, beam_width), false)
