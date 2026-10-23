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
@export var show_caption := true :
	set(next):
		show_caption = next
		queue_redraw()
@export var square_segments := false :
	set(next):
		square_segments = next
		queue_redraw()
@export_range(0.0, 1.0, 0.01) var empty_alpha := 0.18 :
	set(next):
		empty_alpha = next
		queue_redraw()
@export var show_loss_trail := false
@export var loss_trail_color := Color(1.0, 0.22, 0.28, 0.52)

var _trail_value := -1.0
var _trail_delay := 0.0


func _ready() -> void:
	if custom_minimum_size.x <= 0.0:
		custom_minimum_size.x = 175.0
	if custom_minimum_size.y <= 0.0:
		custom_minimum_size.y = 18.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)
	queue_redraw()


func set_meter(next_value: float, next_maximum: float = maximum) -> void:
	var previous_value := value
	maximum = maxf(next_maximum, 1.0)
	var clamped := clampf(next_value, 0.0, maximum)
	if _trail_value < 0.0:
		_trail_value = clamped
	elif show_loss_trail and clamped < previous_value:
		_trail_value = maxf(_trail_value, previous_value)
		_trail_delay = 0.18
	elif clamped > previous_value:
		_trail_value = clamped
	value = clamped
	queue_redraw()


func _process(delta: float) -> void:
	if not show_loss_trail or _trail_value <= value:
		return
	_trail_delay = maxf(_trail_delay - delta, 0.0)
	if _trail_delay <= 0.0:
		_trail_value = move_toward(_trail_value, value, maximum * 2.8 * delta)
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var ratio := clampf(value / maximum, 0.0, 1.0)
	var filled := ceili(ratio * float(segments))
	var trail_filled := ceili(clampf(_trail_value / maximum, 0.0, 1.0) * float(segments)) if show_loss_trail else filled
	if show_caption:
		draw_string(CyberUITheme.FONT, Vector2(0.0, 13.0), caption, HORIZONTAL_ALIGNMENT_LEFT, 58.0, 12, CyberUITheme.MUTED)
	var numeric_width := 34.0 if show_numeric else 0.0
	var meter_left := 58.0 if show_caption else 0.0
	var available := maxf(size.x - meter_left - numeric_width, float(segments) * 4.0)
	var gap := 2.0
	var block_height := minf(14.0, maxf(size.y - 4.0, 4.0))
	var block_width := block_height if square_segments else maxf(2.0, (available - gap * float(segments - 1)) / float(segments))
	for index in segments:
		var rect := Rect2(meter_left + float(index) * (block_width + gap), (size.y - block_height) * 0.5, block_width, block_height)
		var color := meter_color if index < filled else (loss_trail_color if index < trail_filled else Color(meter_color, empty_alpha))
		draw_rect(rect, color, true)
		draw_rect(rect, Color(meter_color, 0.78 if index < filled else 0.42), false, 1.0)
	if show_numeric:
		draw_string(CyberUITheme.FONT, Vector2(size.x - 32.0, 13.0), "%03d" % roundi(value), HORIZONTAL_ALIGNMENT_RIGHT, 32.0, 12, meter_color)
