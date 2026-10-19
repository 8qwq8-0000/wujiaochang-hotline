class_name RooftopBossRoomLighting
extends Node2D

@export_range(0.1, 5.0, 0.05) var awakening_duration := 2.2
@export var background_path: NodePath

const LIGHT_TICK_SECONDS := 1.0 / 12.0
const SERVER_LIGHTS := [
	Vector2(36.0, 54.0), Vector2(70.0, 86.0), Vector2(108.0, 120.0),
	Vector2(146.0, 62.0), Vector2(178.0, 104.0), Vector2(212.0, 72.0),
	Vector2(250.0, 118.0), Vector2(286.0, 78.0), Vector2(112.0, 196.0),
	Vector2(82.0, 238.0), Vector2(126.0, 282.0), Vector2(92.0, 330.0),
	Vector2(924.0, 54.0), Vector2(890.0, 86.0), Vector2(852.0, 120.0),
	Vector2(814.0, 62.0), Vector2(782.0, 104.0), Vector2(748.0, 72.0),
	Vector2(710.0, 118.0), Vector2(674.0, 78.0), Vector2(848.0, 196.0),
	Vector2(878.0, 238.0), Vector2(834.0, 282.0), Vector2(868.0, 330.0),
]
const DUST_BASES := [
	Vector2(380.0, 250.0), Vector2(430.0, 326.0), Vector2(478.0, 220.0),
	Vector2(522.0, 382.0), Vector2(566.0, 286.0), Vector2(612.0, 420.0),
]

var phase_light := 0.0
var _echo_remaining := 0.0
var _echo_duration := 0.35
var _light_accumulator := 0.0
var _light_tick := 0

@onready var background: Sprite2D = get_node_or_null(background_path) as Sprite2D


func _ready() -> void:
	set_process(true)
	queue_redraw()


func reset_to_phase_one() -> void:
	phase_light = 0.0
	_echo_remaining = 0.0
	if is_instance_valid(background):
		background.scale = Vector2.ONE
		background.modulate = Color.WHITE
	set_process(true)
	queue_redraw()


func begin_awakening() -> void:
	set_process(true)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "phase_light", 1.0, awakening_duration)
	tween.tween_callback(queue_redraw)


func activate_immediately() -> void:
	phase_light = 1.0
	set_process(true)
	queue_redraw()


func pulse_echo() -> void:
	_echo_remaining = _echo_duration
	set_process(true)


func _process(delta: float) -> void:
	_light_accumulator += delta
	if _light_accumulator >= LIGHT_TICK_SECONDS:
		var elapsed_ticks := floori(_light_accumulator / LIGHT_TICK_SECONDS)
		_light_accumulator = fmod(_light_accumulator, LIGHT_TICK_SECONDS)
		_light_tick += elapsed_ticks
		queue_redraw()
	if _echo_remaining > 0.0:
		_echo_remaining = maxf(_echo_remaining - delta, 0.0)
		_apply_echo_refraction()
		queue_redraw()
	elif is_instance_valid(background) and background.scale != Vector2.ONE:
		background.scale = Vector2.ONE
		background.modulate = Color.WHITE
		queue_redraw()
	if phase_light > 0.0 and phase_light < 0.999:
		queue_redraw()


func _apply_echo_refraction() -> void:
	if not is_instance_valid(background):
		return
	var progress := 1.0 - _echo_remaining / _echo_duration
	var wave := sin(progress * PI) * 0.003
	background.scale = Vector2(1.0 + wave, 1.0 - wave * 0.65)
	background.modulate = Color(1.0 + wave * 5.0, 1.0 + wave * 3.0, 1.0 + wave * 6.0, 1.0)


func _draw() -> void:
	# The environment is darkened independently so actors and warnings retain
	# their silhouettes during phase one.
	var darkness := lerpf(0.42, 0.07, phase_light)
	draw_rect(Rect2(0.0, 0.0, 960.0, 540.0), Color(0.005, 0.008, 0.015, darkness), true)
	if phase_light > 0.001:
		_draw_phase_two_light()
	_draw_server_lights()


func _draw_phase_two_light() -> void:
	# Keep the altar beam and dust at their original cadence while the server
	# hardware uses the full 12 FPS clock for double-speed blinking.
	var ambient_tick := floori(float(_light_tick) * 0.5)
	var breathe := 0.94 if ambient_tick % 12 < 6 else 0.86
	var beam_alpha := phase_light * 0.105 * breathe
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(420.0, 116.0),
			Vector2(540.0, 116.0),
			Vector2(654.0, 476.0),
			Vector2(306.0, 476.0),
		]),
		Color(1.0, 0.67, 0.2, beam_alpha)
	)

	# Only six aligned 2x2 motes remain, all constrained to the altar beam.
	for index in DUST_BASES.size():
		var base: Vector2 = DUST_BASES[index]
		var drift := float((ambient_tick * 2 + index * 6) % 20)
		var point := Vector2(base.x, base.y - drift).snapped(Vector2(2.0, 2.0))
		draw_rect(Rect2(point, Vector2(2.0, 2.0)), Color(1.0, 0.78, 0.34, phase_light * 0.38), true)


func _draw_server_lights() -> void:
	for index in SERVER_LIGHTS.size():
		# Phase one runs only three quarters of the authored slots. Phase two
		# enables the rest, but the discrete patterns keep 8-12 visibly active.
		if phase_light < 0.5 and index % 4 == 3:
			continue
		var intensity := _light_intensity(index)
		if intensity <= 0.0:
			continue
		var position: Vector2 = SERVER_LIGHTS[index]
		var distance_from_altar := absf(position.x - 480.0) / 480.0
		var amber_wake_threshold := 0.18 + distance_from_altar * 0.68
		var amber := phase_light >= amber_wake_threshold and distance_from_altar < 0.57 and index % 3 != 1
		var alpha_scale := lerpf(0.42, 0.82, phase_light)
		var color := Color(1.0, 0.68, 0.22, intensity * alpha_scale) if amber else Color(0.22, 0.92, 0.84, intensity * alpha_scale)
		var size := Vector2(2.0, 4.0) if index % 7 == 0 else Vector2(2.0, 2.0)
		var rect := Rect2(position, size)
		if amber and absf(position.x - 480.0) < 250.0:
			draw_rect(rect.grow(2.0), Color(1.0, 0.56, 0.12, color.a * 0.14), true)
		draw_rect(rect, color, true)


func _light_intensity(index: int) -> float:
	match index % 3:
		0:
			# Two discrete levels read as a hardware breathing state.
			return 0.72 if (_light_tick + index) % 12 < 6 else 0.46
		1:
			# Short double flash, then a long quiet interval.
			var phase := (_light_tick + index * 2) % 24
			return 1.0 if phase in [0, 1, 4, 5] else 0.0
		2:
			# Rare single heartbeat.
			return 0.92 if (_light_tick + index * 5) % 37 == 0 else 0.0
	return 0.0
