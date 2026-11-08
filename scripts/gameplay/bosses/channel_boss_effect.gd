class_name ChannelBossEffect
extends Node2D

## Effects use the same ground geometry and paused physics clock as their hits.
const ECHO_RADIUS := Vector2(40, 22)
const ECHO_WARNING := 0.8
const ECHO_TAIL := 0.38
const HALO_OFFSETS := [-78.0, 0.0, 78.0]
const HALO_WIDTH := 20.0
const HALO_WARNING := 0.96
const HALO_TAIL := 0.6
const WAVE_START_RADIUS := 24.0
const WAVE_MAX_RADIUS := 285.0
const WAVE_SPEED := 216.0 / 0.66
const WAVE_Y_SCALE := 0.55
const WAVE_THICKNESS := 10.0
const WAVE_LIVE := (WAVE_MAX_RADIUS - WAVE_START_RADIUS) / WAVE_SPEED + 0.02
const WAVE_TAIL := 0.24
const TAIL_RADIUS := 172.0
const TAIL_Y_SCALE := 0.84
const TAIL_HALF_ANGLE := deg_to_rad(58.0)
const TAIL_WARNING := 0.42
const TAIL_FADE := 0.31
const ECHO_INK := Color("#64efff")
const GOLD := Color("#ffc45e")
const EMBER := Color("#e47939")
const WAVE_INK := Color("#a796ff")
const TAIL_INK := Color("#55d9cb")
const TAIL_DEEP := Color("#1c81ab")
const TAIL_EDGE := Color("#dcfff6")
const WHITE_HOT := Color("#fff6de")
const TAIL_ATLAS := preload("res://assets/art/characters/bosses/rooftop_whale_goddess/channel_returned_v1/idle.png")
const TAIL_ROOT := Vector2(272, 332)
const TAIL_TIP := Vector2(366, 275)
# Trace the original blue and gold tail in the first atlas cell, excluding hair and robe.
const TAIL_OUTLINE := [
	Vector2(272, 332), Vector2(279, 332), Vector2(286, 331), Vector2(295, 326),
	Vector2(301, 319), Vector2(307, 305), Vector2(317, 293), Vector2(327, 286),
	Vector2(338, 281), Vector2(349, 277), Vector2(360, 274), TAIL_TIP,
	Vector2(360, 280), Vector2(353, 290), Vector2(348, 300), Vector2(347, 311),
	Vector2(344, 323), Vector2(340, 332), Vector2(333, 340), Vector2(325, 346),
	Vector2(315, 350), Vector2(301, 353), Vector2(289, 354), Vector2(278, 353),
	Vector2(268, 350), Vector2(266, 347), Vector2(270, 342),
]

var arena: RooftopBossArena
var skill: StringName = &"echo"
var elapsed := 0.0
var resolved := false
var wave_contact := false
var previous_radius := 0.0
var tail_angle := 0.0


func _ready() -> void:
	# Ground effects sit above the floor and below the player.
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("channel_boss_effects")


func halo_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for offset in HALO_OFFSETS:
		result.append(Rect2(global_position.x + offset - HALO_WIDTH * 0.5, arena.to_global(arena.ARENA_BOUNDS.position).y,
			HALO_WIDTH, arena.ARENA_BOUNDS.size.y))
	return result


func contains_impact(point: Vector2) -> bool:
	if skill == &"echo":
		return ((point - global_position) / ECHO_RADIUS).length_squared() <= 1.0
	if skill == &"tail":
		var offset := (point - global_position) / Vector2(1.0, TAIL_Y_SCALE)
		return offset.length_squared() <= TAIL_RADIUS * TAIL_RADIUS and (
			offset.is_zero_approx() or absf(angle_difference(tail_angle, offset.angle())) <= TAIL_HALF_ANGLE)
	if skill == &"halo":
		for rect in halo_rects():
			if rect.has_point(point):
				return true
	return false


func wave_radius(clock: float) -> float:
	return minf(WAVE_START_RADIUS + WAVE_SPEED * maxf(clock, 0.0), WAVE_MAX_RADIUS)


func _physics_process(delta: float) -> void:
	if arena == null or arena.phase != arena.Phase.BOSS_ACTIVE or arena.player.health.is_dead():
		queue_free()
		return
	elapsed += delta
	if skill == &"halo":
		if not resolved and elapsed >= HALO_WARNING and elapsed <= HALO_WARNING + HALO_TAIL and contains_impact(arena.player.global_position):
			resolved = true
			arena._damage_player(global_position)
	elif skill in [&"echo", &"tail"]:
		var strike_time := _warning_time()
		if not resolved and elapsed >= strike_time:
			resolved = true
			if contains_impact(arena.player.global_position):
				arena._damage_player(global_position)
	elif skill == &"protect":
		var radius := wave_radius(elapsed)
		var point := arena.player.global_position - global_position
		point.y /= WAVE_Y_SCALE
		var distance := point.length()
		if not wave_contact and elapsed <= WAVE_LIVE and distance >= previous_radius - WAVE_THICKNESS and distance <= radius + WAVE_THICKNESS:
			# One ring crossing only; dash invulnerability still goes through HurtBox.
			wave_contact = true
			arena._damage_player(global_position)
		previous_radius = radius
	if elapsed >= visual_end():
		queue_free()
	else:
		queue_redraw()


func _warning_time() -> float:
	match skill:
		&"echo": return ECHO_WARNING
		&"halo": return HALO_WARNING
		_: return TAIL_WARNING


func visual_end() -> float:
	match skill:
		&"echo": return ECHO_WARNING + ECHO_TAIL
		&"halo": return HALO_WARNING + HALO_TAIL
		&"tail": return TAIL_WARNING + TAIL_FADE
		_: return WAVE_LIVE + WAVE_TAIL


func _draw() -> void:
	match skill:
		&"echo": _draw_echo()
		&"halo": _draw_halo()
		&"protect": _draw_wave()
		&"tail": _draw_tail()


func _draw_echo() -> void:
	var radius := ECHO_RADIUS.x
	var strike := elapsed - ECHO_WARNING
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, ECHO_RADIUS.y / radius))
	if strike < 0.0:
		var charge := clampf(elapsed / ECHO_WARNING, 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(0.035, 0.15, 0.22, 0.72))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(ECHO_INK, 0.62), 1.6, true)
		var sweep := maxf(TAU * charge, 0.02)
		draw_arc(Vector2.ZERO, radius - 5.0, -PI * 0.5, -PI * 0.5 + sweep, 48, ECHO_INK, 2.5, true)
		for index in 4:
			var direction := Vector2.from_angle(PI * 0.25 + PI * 0.5 * index)
			var notch := lerpf(19.0, 8.0, charge)
			draw_line(direction * notch, direction * (notch + 6.0), ECHO_INK, 2.0, true)
	else:
		var impact := 1.0 - smoothstep(0.04, 0.24, strike)
		var afterglow := 1.0 - smoothstep(0.08, ECHO_TAIL, strike)
		draw_circle(Vector2.ZERO, radius, Color(ECHO_INK, 0.45 * impact))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(ECHO_INK, afterglow), 2.0, true)
		var ripple := lerpf(7.0, radius - 3.0, smoothstep(0.0, 0.19, strike))
		draw_arc(Vector2.ZERO, ripple, 0, TAU, 40, Color(WHITE_HOT, impact), 4.0, true)
	draw_set_transform(Vector2.ZERO)
	if strike >= 0.0 and strike < 0.18:
		_draw_echo_impact(strike / 0.18)


func _draw_echo_impact(progress: float) -> void:
	var flash := 1.0 - smoothstep(0.10, 1.0, progress)
	var tip := Vector2(0, -lerpf(46.0, 18.0, progress))
	var shard := PackedVector2Array([tip, Vector2(9, -8), Vector2.ZERO, Vector2(-9, -8)])
	draw_colored_polygon(shard, Color(ECHO_INK, flash * 0.8))
	draw_line(tip, Vector2.ZERO, Color(WHITE_HOT, flash), 2.0, true)
	for index in 6:
		var direction := Vector2.from_angle(TAU * index / 6.0)
		var spark := direction * Vector2(1, 0.55) * lerpf(8.0, 31.0, progress)
		draw_line(spark, spark - Vector2(0, 4), Color(ECHO_INK, flash), 2.0, true)


func _draw_halo() -> void:
	var strike := elapsed - HALO_WARNING
	for world_rect in halo_rects():
		var rect := Rect2(to_local(world_rect.position), world_rect.size)
		if strike < 0.0:
			_draw_halo_warning(rect)
		else:
			_draw_halo_cut(rect, strike)


func _draw_halo_warning(rect: Rect2) -> void:
	var charge := clampf(elapsed / HALO_WARNING, 0.0, 1.0)
	var center_x := rect.get_center().x
	draw_rect(rect, Color(0.17, 0.075, 0.055, 0.76))
	for x in [rect.position.x + 1.0, rect.end.x - 1.0]:
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color(EMBER, 0.48 + 0.44 * charge), 2.0)
	var spacing := 30.0
	var scroll := fposmod(elapsed * lerpf(68.0, 132.0, charge), spacing)
	for row in ceili(rect.size.y / spacing):
		var y := rect.position.y + 7.0 + row * spacing + scroll
		if y + 7.0 >= rect.end.y:
			break
		var arrow := PackedVector2Array([Vector2(center_x - 6, y), Vector2(center_x, y + 7), Vector2(center_x + 6, y)])
		draw_polyline(arrow, Color(GOLD, 0.45 + 0.50 * charge), 2.0, true)


func _draw_halo_cut(rect: Rect2, strike: float) -> void:
	var edge := 1.0 - smoothstep(0.06, HALO_TAIL, strike)
	var flare := 1.0 - smoothstep(0.025, 0.18, strike)
	draw_rect(rect, Color(EMBER, 0.33 * edge))
	# A bevel on each end and alternating facets give the blade a silhouette.
	var x := rect.get_center().x
	var y := rect.position.y
	var length := rect.size.y
	var width := rect.size.x * 0.5
	var blade := PackedVector2Array([
		Vector2(x - width * 0.74, y),
		Vector2(x + width * 0.48, y),
		Vector2(x + width, y + length * 0.16),
		Vector2(x + width * 0.60, y + length * 0.49),
		Vector2(x + width, y + length * 0.71),
		Vector2(x + width * 0.45, rect.end.y),
		Vector2(x - width * 0.70, rect.end.y),
		Vector2(x - width, y + length * 0.76),
		Vector2(x - width * 0.62, y + length * 0.44),
		Vector2(x - width, y + length * 0.21),
	])
	draw_colored_polygon(blade, Color(EMBER, 0.52 * edge + 0.36 * flare))
	var spine := PackedVector2Array([
		Vector2(x - 3.0, y),
		Vector2(x + width * 0.61, y + length * 0.15),
		Vector2(x + 1.0, y + length * 0.51),
		Vector2(x + width * 0.50, y + length * 0.73),
		Vector2(x - 2.0, rect.end.y),
		Vector2(x - width * 0.37, y + length * 0.71),
		Vector2(x - width * 0.60, y + length * 0.22),
	])
	draw_colored_polygon(spine, Color(WHITE_HOT, 0.94 * flare))
	for index in 8:
		var phase := fposmod(float(index) * 0.131 + strike * 1.8, 1.0)
		var spark := Vector2(x + (7.0 if index % 2 == 0 else -7.0), y + phase * (length - 7.0))
		draw_line(spark, spark + Vector2(0, 7), Color(GOLD, 0.85 * edge), 1.5)


static func draw_wave_charge(canvas: Node2D, origin: Vector2, charge: float) -> void:
	canvas.draw_set_transform(origin, 0.0, Vector2(1.0, WAVE_Y_SCALE))
	var radius := lerpf(36.0, 24.0, charge)
	canvas.draw_circle(Vector2.ZERO, radius, Color(WAVE_INK, 0.1 * charge))
	for index in 4:
		var angle := index * TAU / 4.0 + charge * 0.48
		var length := lerpf(0.32, 1.35, charge)
		canvas.draw_arc(Vector2.ZERO, radius, angle, angle + length, 16, Color(WAVE_INK, 0.28 + 0.65 * charge), 2.5, true)
	canvas.draw_set_transform(Vector2.ZERO)


func _draw_wave() -> void:
	var radius := wave_radius(elapsed)
	var fade := 1.0 - smoothstep(WAVE_LIVE, WAVE_LIVE + WAVE_TAIL, elapsed)
	var width := WAVE_THICKNESS * 2.0 * fade
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, WAVE_Y_SCALE))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 96, Color(WAVE_INK, 0.32 * fade), width, true)
	draw_arc(Vector2.ZERO, radius + width * 0.43, 0, TAU, 96, Color(WAVE_INK, 0.90 * fade), 2.0, true)
	for index in 8:
		var angle := index * TAU / 8.0 - 0.10
		draw_arc(Vector2.ZERO, radius + width * 0.22, angle, angle + 0.25, 8, Color(WHITE_HOT, 0.82 * fade), 2.5, true)
	draw_set_transform(Vector2.ZERO)


func _draw_tail() -> void:
	var strike := elapsed - TAIL_WARNING
	var start := tail_angle - TAIL_HALF_ANGLE
	var end := tail_angle + TAIL_HALF_ANGLE
	var charge := clampf(elapsed / TAIL_WARNING, 0.0, 1.0)
	var fade := 1.0 - smoothstep(0.0, TAIL_FADE, strike)
	var fan := PackedVector2Array([Vector2.ZERO])
	for index in 25:
		var angle := lerpf(start, end, float(index) / 24.0)
		fan.append(Vector2.from_angle(angle) * TAIL_RADIUS)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, TAIL_Y_SCALE))
	if strike < 0.0:
		draw_colored_polygon(fan, Color(TAIL_DEEP, 0.12 + 0.13 * charge))
		draw_line(Vector2.ZERO, fan[1], Color(TAIL_INK, 0.50), 1.0, true)
		draw_line(Vector2.ZERO, fan[25], Color(TAIL_INK, 0.50), 1.0, true)
		draw_arc(Vector2.ZERO, TAIL_RADIUS - 1.5, start, end, 48, Color(TAIL_INK, 0.74), 1.5, true)
		var tip := maxf(start + 0.01, lerpf(start, end, charge))
		draw_arc(Vector2.ZERO, TAIL_RADIUS - 7.0, start, tip, 40, Color(TAIL_EDGE, 0.80), 1.5, true)
		for index in range(1, 8):
			var angle := lerpf(start, end, index / 8.0)
			var tick := Vector2.from_angle(angle)
			draw_line(tick * (TAIL_RADIUS - 12.0), tick * (TAIL_RADIUS - 8.0), Color(TAIL_INK, 0.32), 1.0, true)
	else:
		var flash := 1.0 - smoothstep(0.0, 0.12, strike)
		draw_colored_polygon(fan, Color(TAIL_INK, 0.14 * flash))
		_draw_whale_tail(start, end, strike, fade)
	draw_set_transform(Vector2.ZERO)


func _draw_whale_tail(start: float, end: float, strike: float, fade: float) -> void:
	var sweep := smoothstep(0.0, 0.18, strike)
	# Reserve space for the asymmetric bend of the tail inside the hit fan.
	var heading := lerpf(start + 0.12, end - 0.55, sweep)
	var reach := lerpf(0.84, 1.0, smoothstep(0.0, 0.06, strike))
	_draw_tail_spray(start, heading, strike, fade)

	var silhouette := PackedVector2Array()
	var uvs := PackedVector2Array()
	var ink := PackedColorArray()
	var pivot := Vector2.from_angle(heading) * 48.0
	var rotation_angle := heading - (TAIL_TIP - TAIL_ROOT).angle()
	var atlas_size := TAIL_ATLAS.get_size()
	for pixel: Vector2 in TAIL_OUTLINE:
		var offset := (pixel - TAIL_ROOT).rotated(rotation_angle) * 1.08
		silhouette.append((pivot + offset) * reach)
		uvs.append(pixel / atlas_size)
		var tip_light := smoothstep(0.0, 72.0, (pixel - TAIL_ROOT).length())
		ink.append(Color(1.0 + 0.14 * tip_light, 1.0 + 0.14 * tip_light, 1.0, fade * lerpf(0.50, 1.0, tip_light)))
	draw_polygon(silhouette, ink, uvs, TAIL_ATLAS)


func _draw_tail_spray(start: float, heading: float, strike: float, fade: float) -> void:
	for index in 11:
		var seed := fposmod(index * 0.618, 1.0)
		var reach := minf(0.93, lerpf(0.48, 0.90, seed) + strike * 0.28)
		var angle := heading - lerpf(0.40, 0.75, fposmod(index * 0.37, 1.0))
		if angle <= start + 0.025:
			continue
		var radius := reach * TAIL_RADIUS
		var wake := maxf(start + 0.016, angle - lerpf(0.032, 0.10, seed))
		var intensity := fade * smoothstep(0.0, 0.035, strike)
		draw_arc(Vector2.ZERO, radius, wake, angle, 5, Color(TAIL_INK, intensity * 0.60), 1.5, true)
		draw_circle(Vector2.from_angle(angle) * radius, lerpf(0.8, 1.6, seed), Color(GOLD, intensity * 0.76))
