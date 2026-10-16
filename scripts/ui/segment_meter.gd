@tool
class_name SegmentMeter
extends Control

@export var caption := "METER" :
	set(value):
		caption = value
		queue_redraw()
@export_range(0.0, 1000.0, 1.0) var value := 5.0 :
	set(next):
		value = next
		queue_redraw()
@export_range(1.0, 1000.0, 1.0) var maximum := 10.0 :
	set(next):
		maximum = maxf(next, 1.0)
		queue_redraw()
@export_range(1, 20, 1) var segments := 10 :
	set(next):
		segments = maxi(next, 1)
		queue_redraw()
@export var meter_color := CyberUITheme.PHOSPHOR :
	set(next):
		meter_color = next
		queue_redraw()
@export var show_numeric := true :
	set(next):
		show_numeric = next
		queue_redraw()


func _ready() -> void:
	if custom_minimum_size.x <= 0.0:
		custom_minimum_size.x = 175.0
	if custom_minimum_size.y <= 0.0:
		custom_minimum_size.y = 18.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_meter(next_value: float, next_maximum: float = maximum) -> void:
	maximum = maxf(next_maximum, 1.0)
	value = clampf(next_value, 0.0, maximum)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var ratio := clampf(value / maximum, 0.0, 1.0)
	var filled := ceili(ratio * float(segments))
	draw_string(CyberUITheme.FONT, Vector2(0.0, 13.0), caption, HORIZONTAL_ALIGNMENT_LEFT, 58.0, 12, CyberUITheme.MUTED)
	var numeric_width := 34.0 if show_numeric else 0.0
	var meter_left := 58.0
	var available := maxf(size.x - meter_left - numeric_width, float(segments) * 4.0)
	var gap := 2.0
	var block_width := maxf(2.0, (available - gap * float(segments - 1)) / float(segments))
	for index in segments:
		var rect := Rect2(meter_left + float(index) * (block_width + gap), 4.0, block_width, 9.0)
		var color := meter_color if index < filled else Color(CyberUITheme.DIM_GREEN, 0.42)
		draw_rect(rect, color, true)
		draw_rect(rect, Color(meter_color, 0.65), false, 1.0)
	if show_numeric:
		draw_string(CyberUITheme.FONT, Vector2(size.x - 32.0, 13.0), "%03d" % roundi(value), HORIZONTAL_ALIGNMENT_RIGHT, 32.0, 12, meter_color)
