class_name MovementParticleEffect
extends Node2D

signal finished(effect: MovementParticleEffect)

var _particles: Array[Dictionary] = []
var _persona_id: StringName = &""
var _effect_kind: StringName = &"dash"
var _phase: StringName = &"path"
var _direction := Vector2.RIGHT
var _segment := Vector2.ZERO
var _duration := 0.24
var _elapsed := 0.0
var _reduced_flashes := false
var _primary := Color.WHITE
var _accent := Color.WHITE
var _signature_scale := 1.0


func _ready() -> void:
	z_index = -1
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	visible = false
	set_process(false)


func play(
	from: Vector2,
	to: Vector2,
	persona_id: StringName,
	effect_kind: StringName,
	phase: StringName,
	direction: Vector2,
	cancelled: bool,
	reduced_flashes: bool,
	quality_scale: float
) -> void:
	global_position = from
	_persona_id = persona_id
	_effect_kind = effect_kind
	_phase = &"blocked" if cancelled else phase
	_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	_segment = to - from
	_reduced_flashes = reduced_flashes
	_primary = MovementFeedbackStyle.primary_color(persona_id)
	_accent = MovementFeedbackStyle.accent_color(persona_id)
	_signature_scale = MovementFeedbackStyle.effect_strength(effect_kind)
	_duration = (0.42 if effect_kind == &"ninja_takeover" else (0.3 if _phase != &"path" else 0.22))
	if reduced_flashes:
		_duration *= 1.16
	_elapsed = 0.0
	_particles.clear()
	_build_particles(_segment, clampf(quality_scale, 0.35, 1.0))
	visible = true
	set_process(true)
	queue_redraw()


func stop() -> void:
	visible = false
	set_process(false)
	_particles.clear()
	queue_redraw()


func get_particle_count() -> int:
	return _particles.size()


func _build_particles(segment: Vector2, quality_scale: float) -> void:
	var length := segment.length()
	var base_count := 4
	if _phase == &"path":
		base_count = clampi(ceili(length / 7.0), 2, 7)
	elif _phase == &"blocked":
		base_count = 10
	else:
		base_count = 8
	base_count = maxi(2, roundi(float(base_count) * quality_scale * _signature_scale))
	if _reduced_flashes:
		base_count = maxi(2, roundi(float(base_count) * 0.68))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("move:%s:%s:%s:%d:%d:%d" % [
		_persona_id,
		_effect_kind,
		_phase,
		roundi(global_position.x),
		roundi(global_position.y),
		Time.get_ticks_msec() / 35,
	])
	var perpendicular := _direction.orthogonal()
	for index in base_count:
		var along := rng.randf()
		var position := segment * along
		if _phase != &"path":
			position = segment + perpendicular * rng.randf_range(-5.0, 5.0)
		var spread := rng.randf_range(-1.0, 1.0)
		var velocity := -_direction * rng.randf_range(7.0, 20.0) + perpendicular * spread * rng.randf_range(8.0, 24.0)
		if _phase == &"start":
			velocity = -_direction * rng.randf_range(10.0, 30.0) + perpendicular * spread * 18.0
		elif _phase == &"end":
			velocity = -position.normalized() * rng.randf_range(4.0, 13.0) if not position.is_zero_approx() else -_direction * 8.0
		elif _phase == &"blocked":
			velocity = -_direction * rng.randf_range(18.0, 38.0) + perpendicular * spread * rng.randf_range(18.0, 42.0)
		var color := _primary.lerp(_accent, rng.randf_range(0.15, 0.75))
		color.a = (0.4 if _reduced_flashes else 0.72) * rng.randf_range(0.72, 1.0)
		_particles.append({
			"position": position,
			"velocity": velocity,
			"rotation": _direction.angle() + rng.randf_range(-0.55, 0.55),
			"size": rng.randf_range(1.5, 3.2) * minf(_signature_scale, 1.55),
			"color": color,
			"variant": index % 3,
		})


func _process(delta: float) -> void:
	_elapsed += delta
	for particle in _particles:
		particle["position"] = (particle["position"] as Vector2) + (particle["velocity"] as Vector2) * delta
		particle["velocity"] = (particle["velocity"] as Vector2) * maxf(0.0, 1.0 - delta * 3.5)
	queue_redraw()
	if _elapsed >= _duration:
		stop()
		finished.emit(self)


func _draw() -> void:
	if not visible:
		return
	var ratio := clampf(_elapsed / _duration, 0.0, 1.0)
	var fade := (1.0 - ratio) * (1.0 - ratio * 0.35)
	for particle in _particles:
		var color: Color = particle["color"]
		color.a *= fade
		_draw_particle(
			particle["position"] as Vector2,
			float(particle["rotation"]),
			float(particle["size"]) * (1.0 + ratio * 0.12),
			color,
			int(particle["variant"])
		)
	_draw_signature(ratio, fade)


func _draw_particle(position: Vector2, rotation: float, size: float, color: Color, variant: int) -> void:
	var axis := Vector2.RIGHT.rotated(rotation)
	var perpendicular := axis.orthogonal()
	match MovementFeedbackStyle.visual_style(_persona_id):
		MovementFeedbackStyle.VisualStyle.DEEP_NINJA:
			var points := PackedVector2Array([
				position - axis * size * 1.8 - perpendicular * size * 0.25,
				position + axis * size * 1.35,
				position + axis * size * 0.2 + perpendicular * size * 0.55,
			])
			draw_colored_polygon(points, color)
		MovementFeedbackStyle.VisualStyle.LEGENDARY_MASTER:
			draw_line(position - perpendicular * size, position + perpendicular * size, color, 1.15, true)
			if variant == 0:
				draw_line(position, position + axis * size * 1.4, color, 0.75, true)
		MovementFeedbackStyle.VisualStyle.ROCK_VIGILANTE:
			var wave := PackedVector2Array([
				position - axis * size * 1.5,
				position - axis * size * 0.35 + perpendicular * size * 0.8,
				position + axis * size * 0.25 - perpendicular * size * 0.65,
				position + axis * size * 1.5,
			])
			draw_polyline(wave, color, 1.15, true)
		_:
			draw_line(position - axis * size, position + axis * size, color, 1.0, true)


func _draw_signature(ratio: float, fade: float) -> void:
	if _phase == &"path":
		_draw_path_signature(fade)
		return
	var center := Vector2.ZERO
	var radius := (5.0 + ratio * 8.0) * minf(_signature_scale, 1.6)
	var color := _accent
	color.a = fade * (0.32 if _reduced_flashes else 0.62)
	match MovementFeedbackStyle.visual_style(_persona_id):
		MovementFeedbackStyle.VisualStyle.DEEP_NINJA:
			var direction := _direction
			var side := direction.orthogonal()
			if _effect_kind == &"ninja_takeover" and _phase == &"end":
				var eye := PackedVector2Array([
					center - direction * radius,
					center - side * radius * 0.42,
					center + direction * radius,
					center + side * radius * 0.42,
					center - direction * radius,
				])
				draw_polyline(eye, color, 1.6, true)
				draw_line(center - side * 2.0, center + side * 2.0, color, 1.0, true)
			else:
				draw_line(center - direction * radius - side * 4.0, center + direction * radius, color, 1.5, true)
				draw_line(center - direction * radius + side * 4.0, center + direction * radius, color, 1.0, true)
		MovementFeedbackStyle.VisualStyle.LEGENDARY_MASTER:
			draw_arc(center, radius, 0.2, TAU - 0.75, 18, color, 1.25, true)
			draw_line(center + _direction * (radius - 2.0), center + _direction * (radius + 3.0), color, 1.0, true)
		MovementFeedbackStyle.VisualStyle.ROCK_VIGILANTE:
			var side := _direction.orthogonal()
			var wave := PackedVector2Array([
				center - _direction * radius,
				center - _direction * radius * 0.45 + side * 3.0,
				center - side * 4.0,
				center + _direction * radius * 0.4 + side * 2.0,
				center + _direction * radius,
			])
			draw_polyline(wave, color, 1.6, true)
		_:
			draw_arc(center, radius, 0.0, TAU, 14, color, 1.0, true)


func _draw_path_signature(fade: float) -> void:
	if MovementFeedbackStyle.visual_style(_persona_id) != MovementFeedbackStyle.VisualStyle.DEEP_NINJA:
		return
	var color := _accent
	color.a = fade * (0.2 if _reduced_flashes else 0.38)
	var side := _direction.orthogonal()
	match _effect_kind:
		&"ninja_chase":
			draw_line(side * 3.5, _segment, color, 1.0, true)
			draw_line(-side * 3.5, _segment, color, 1.0, true)
		&"ninja_borrowed_step":
			var center := _segment * 0.5
			draw_line(center - _direction * 7.0 - side * 3.5, center + _direction * 7.0 + side * 1.5, color, 1.5, true)
			draw_line(center - _direction * 5.0 + side * 3.5, center + _direction * 9.0 - side * 1.5, color, 1.0, true)
		&"ninja_takeover":
			draw_dashed_line(Vector2.ZERO, _segment, color, 1.25, 5.0, true)
