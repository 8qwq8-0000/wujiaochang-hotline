class_name ImpactParticleEffect
extends Node2D

signal finished(effect: ImpactParticleEffect)

var _particles: Array[Dictionary] = []
var _elapsed := 0.0
var _duration := 0.28
var _rail_direction := Vector2.ZERO
var _rail_color := Color.WHITE
var _active := false
var _calamity_flame := false
var _reduced_flashes := false


func _ready() -> void:
	z_index = 1
	set_process(false)
	hide()


func play(
	world_position: Vector2,
	weapon_id: StringName,
	heavy_material: bool,
	direction: Vector2,
	reduced_flashes: bool,
	clarity_scale: float
) -> void:
	global_position = world_position
	_elapsed = 0.0
	_calamity_flame = weapon_id == &"calamity_flame"
	_reduced_flashes = reduced_flashes
	_duration = 0.36 if _calamity_flame else (0.34 if heavy_material else 0.26)
	_active = true
	_particles.clear()
	var palette := _weapon_palette(weapon_id)
	var count := 6
	if weapon_id == &"scattergun":
		count = 12
	elif weapon_id == &"rail_cannon":
		count = 9
	elif weapon_id == &"thermal_pulse":
		count = 10
	elif _calamity_flame:
		count = 24
	if heavy_material:
		count += 4
	var feedback_scale := minf(clarity_scale, 0.5) if _calamity_flame and reduced_flashes else clarity_scale * (0.62 if reduced_flashes and not _calamity_flame else 1.0)
	count = maxi(2, int(count * feedback_scale))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%d:%d:%d" % [weapon_id, roundi(world_position.x), roundi(world_position.y), Time.get_ticks_msec() / 40])
	var impact_direction := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	for index in count:
		var spread := rng.randf_range(-1.55 if _calamity_flame else -1.15, 1.55 if _calamity_flame else 1.15)
		var particle_direction := impact_direction.rotated(spread)
		var speed := rng.randf_range(54.0, 132.0) if _calamity_flame else rng.randf_range(42.0, 105.0) * (0.82 if heavy_material else 1.0)
		_particles.append({
			"position": Vector2.ZERO,
			"velocity": particle_direction * speed,
			"life": rng.randf_range(0.12, _duration),
			"max_life": _duration,
			"size": rng.randf_range(1.4, 3.1) if _calamity_flame else rng.randf_range(1.2, 2.4) * (1.65 if heavy_material else 1.0),
			"color": palette[index % palette.size()],
			"shard": heavy_material and index % 2 == 0,
		})
	_rail_direction = impact_direction if weapon_id == &"rail_cannon" else Vector2.ZERO
	_rail_color = palette[0]
	modulate.a = clarity_scale
	show()
	set_process(true)
	queue_redraw()


func stop() -> void:
	if not _active:
		return
	_active = false
	set_process(false)
	hide()
	_particles.clear()
	finished.emit(self)


func get_particle_count() -> int:
	return _particles.size()


func _process(delta: float) -> void:
	_elapsed += delta
	var alive := false
	for particle in _particles:
		particle.life = maxf(float(particle.life) - delta, 0.0)
		if particle.life <= 0.0:
			continue
		alive = true
		particle.position += particle.velocity * delta
		particle.velocity = particle.velocity.lerp(Vector2.DOWN * 38.0, clampf(delta * 4.0, 0.0, 1.0))
	queue_redraw()
	if not alive or _elapsed >= _duration:
		stop()


func _draw() -> void:
	if _calamity_flame and not _reduced_flashes and _elapsed < 0.11:
		var burst_fade := 1.0 - _elapsed / 0.11
		draw_circle(Vector2.ZERO, 8.0 + _elapsed * 55.0, Color(1.0, 0.08, 0.2, burst_fade * 0.46), false, 2.0)
		draw_circle(Vector2.ZERO, 3.5 * burst_fade, Color(1.0, 0.72, 0.78, burst_fade * 0.85))
	if not _rail_direction.is_zero_approx() and _elapsed < 0.11:
		var fade := 1.0 - _elapsed / 0.11
		draw_line(-_rail_direction * 13.0, _rail_direction * 20.0, Color(_rail_color, fade), 2.0)
	for particle in _particles:
		if particle.life <= 0.0:
			continue
		var ratio := clampf(float(particle.life) / float(particle.max_life), 0.0, 1.0)
		var color := Color(particle.color, ratio)
		var point: Vector2 = particle.position
		var size: float = particle.size
		if particle.shard:
			var velocity: Vector2 = particle.velocity.normalized()
			draw_line(point - velocity * size, point + velocity * size, color, maxf(1.0, size * 0.6))
		else:
			draw_circle(point, size * ratio, color)


func _weapon_palette(weapon_id: StringName) -> Array[Color]:
	match weapon_id:
		&"incoming_melee":
			return [Color("ff365b"), Color("ff8a9d"), Color("a80f36")]
		&"incoming_projectile":
			return [Color("ff3157"), Color("ffd0d7"), Color("c51d42")]
		&"incoming_explosive":
			return [Color("ff304f"), Color("ff784e"), Color("8e1433")]
		&"scattergun":
			return [Color("ffb24a"), Color("fff0b0"), Color("ef692f")]
		&"rail_cannon":
			return [Color("8ff7ff"), Color.WHITE, Color("5ba9ff")]
		&"thermal_pulse":
			return [Color("ff6038"), Color("ffb04d"), Color("7e221d")]
		&"calamity_flame":
			return [Color("ff1838"), Color("d7258f"), Color("85051f"), Color("2a0c17")]
		&"baton", &"initial_baton":
			return [Color("e7efff"), Color("8dd8ff"), Color.WHITE]
		_:
			return [Color("ffe58d"), Color("fff5cf"), Color("e99c4c")]
