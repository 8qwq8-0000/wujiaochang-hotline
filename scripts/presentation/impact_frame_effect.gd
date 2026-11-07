class_name ImpactFrameEffect
extends Node2D

const STANDARD_DURATION_USEC := 520_000
const REDUCED_DURATION_USEC := 420_000
const STANDARD_PEAK_USEC := 70_000
const REDUCED_PEAK_USEC := 55_000
const RETRIGGER_LOCKOUT_USEC := 900_000
const STANDARD_RADIUS := 58.0
const REDUCED_RADIUS := 38.0

var _started_at_usec := 0
var _duration_usec := 0
var _last_started_at_usec := -RETRIGGER_LOCKOUT_USEC
var _direction := Vector2.RIGHT
var _reduced_flashes := false
var _rays: Array[Dictionary] = []


func _ready() -> void:
	z_index = 8
	process_mode = Node.PROCESS_MODE_ALWAYS
	stop()


func play_world(world_position: Vector2, reduced_flashes: bool, direction: Vector2 = Vector2.RIGHT) -> bool:
	var now := Time.get_ticks_usec()
	if now - _last_started_at_usec < RETRIGGER_LOCKOUT_USEC:
		return false
	global_position = world_position
	return _start(reduced_flashes, direction, now)


func play_screen(normalized_center: Vector2, reduced_flashes: bool, direction: Vector2 = Vector2.RIGHT) -> bool:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return false
	var now := Time.get_ticks_usec()
	if now - _last_started_at_usec < RETRIGGER_LOCKOUT_USEC:
		return false
	global_position = get_viewport().get_canvas_transform().affine_inverse() * (normalized_center.clamp(Vector2.ZERO, Vector2.ONE) * viewport_size)
	return _start(reduced_flashes, direction, now)


func _start(reduced_flashes: bool, direction: Vector2, now: int) -> bool:
	_started_at_usec = now
	_last_started_at_usec = now
	_reduced_flashes = reduced_flashes
	_duration_usec = REDUCED_DURATION_USEC if reduced_flashes else STANDARD_DURATION_USEC
	_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	_build_rays(7 if reduced_flashes else 12)
	show()
	set_process(true)
	queue_redraw()
	return true


func stop() -> void:
	set_process(false)
	hide()
	_rays.clear()
	queue_redraw()


func is_active() -> bool:
	return visible


func maximum_radius() -> float:
	return REDUCED_RADIUS if _reduced_flashes else STANDARD_RADIUS


func current_radius(now_usec: int = -1) -> float:
	if not is_active() or _duration_usec <= 0:
		return 0.0
	var elapsed := (Time.get_ticks_usec() if now_usec < 0 else now_usec) - _started_at_usec
	var progress := clampf(float(elapsed) / float(_duration_usec), 0.0, 1.0)
	return maximum_radius() * (1.0 - pow(1.0 - minf(progress / 0.58, 1.0), 3.0))


func _process(_delta: float) -> void:
	_update_at(Time.get_ticks_usec())


func _update_at(now_usec: int) -> void:
	if now_usec - _started_at_usec >= _duration_usec:
		stop()
		return
	queue_redraw()


func _build_rays(count: int) -> void:
	_rays.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:%d" % [roundi(global_position.x), roundi(global_position.y), _started_at_usec / 20_000])
	for index in count:
		var angle := _direction.angle() + rng.randf_range(-1.05, 1.05)
		if index >= ceili(count * 0.7):
			angle = rng.randf_range(-PI, PI)
		_rays.append({
			"direction": Vector2.from_angle(angle),
			"distance": rng.randf_range(0.24, 0.72),
			"length": rng.randf_range(0.18, 0.46),
			"width": rng.randf_range(1.0, 2.2),
			"delay": rng.randf_range(0.02, 0.22),
		})


func _draw() -> void:
	if not is_active() or _duration_usec <= 0:
		return
	var elapsed_usec := Time.get_ticks_usec() - _started_at_usec
	var progress := clampf(float(elapsed_usec) / float(_duration_usec), 0.0, 1.0)
	var peak_usec := REDUCED_PEAK_USEC if _reduced_flashes else STANDARD_PEAK_USEC
	var peak := 1.0 - smoothstep(0.0, float(peak_usec), float(elapsed_usec))
	var tail := 1.0 - smoothstep(0.34, 1.0, progress)
	var radius := current_radius(_started_at_usec + elapsed_usec)
	var accessibility_scale := 0.58 if _reduced_flashes else 1.0
	var perpendicular := _direction.orthogonal()

	# A local black backing keeps the white core readable without recoloring the scene or HUD.
	if peak > 0.0:
		draw_circle(Vector2.ZERO, 7.0 + 10.0 * peak, Color(0.01, 0.012, 0.02, peak * 0.82 * accessibility_scale))
		var core_length := 13.0 * peak * accessibility_scale
		var core_width := 5.5 * peak * accessibility_scale
		draw_colored_polygon(PackedVector2Array([
			_direction * core_length,
			perpendicular * core_width,
			-_direction * core_length,
			-perpendicular * core_width,
		]), Color(1.0, 0.98, 0.88, peak * accessibility_scale))

	if radius > 1.0 and tail > 0.0:
		var ring := PackedVector2Array()
		for index in 33:
			var angle := TAU * float(index) / 32.0
			var irregularity := 1.0 + sin(angle * 7.0 + 0.6) * 0.055
			ring.append(Vector2.from_angle(angle) * radius * irregularity)
		draw_polyline(ring, Color(0.015, 0.02, 0.035, tail * 0.72 * accessibility_scale), 3.2, true)
		draw_polyline(ring, Color(1.0, 0.93, 0.72, tail * 0.78 * accessibility_scale), 1.1, true)

	var slash_fade := 1.0 - smoothstep(0.0, 0.48, progress)
	if slash_fade > 0.0:
		draw_line(-_direction * radius * 0.42, _direction * radius * 0.78, Color(0.01, 0.015, 0.025, slash_fade * 0.8 * accessibility_scale), 4.0)
		draw_line(-_direction * radius * 0.34, _direction * radius * 0.7, Color(1.0, 0.94, 0.76, slash_fade * 0.76 * accessibility_scale), 1.3)

	for ray in _rays:
		var ray_progress := clampf((progress - float(ray.delay)) / maxf(1.0 - float(ray.delay), 0.01), 0.0, 1.0)
		var ray_fade := (1.0 - ray_progress) * tail * accessibility_scale
		if ray_fade <= 0.0:
			continue
		var ray_direction: Vector2 = ray.direction
		var start := ray_direction * radius * float(ray.distance)
		var finish := start + ray_direction * maximum_radius() * float(ray.length) * (0.45 + ray_progress)
		draw_line(start, finish, Color(0.02, 0.025, 0.04, ray_fade * 0.82), float(ray.width) + 1.2)
		draw_line(start, finish, Color(1.0, 0.9, 0.68, ray_fade * 0.74), float(ray.width))
