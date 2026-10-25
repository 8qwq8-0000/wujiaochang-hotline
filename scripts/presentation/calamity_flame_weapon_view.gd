class_name CalamityFlameWeaponView
extends WeaponView

const FULL_PARTICLE_COUNT := 36
const LOW_PARTICLE_COUNT := 18
const PARTICLE_DURATION := 0.34
const PALETTE: Array[Color] = [
	Color("7d071d"),
	Color("ff1838"),
	Color("d7258f"),
	Color("2a0c17"),
]

var _particles: Array[Dictionary] = []
var _emit_remaining := 0.0
var _emit_accumulator := 0.0
var _last_tip_position := Vector2.ZERO
var _has_last_tip := false
var _rng := RandomNumberGenerator.new()

@onready var flame_tip: Marker2D = get_node("EffectSocket/FlameTip") as Marker2D


func _ready() -> void:
	super._ready()
	_rng.seed = hash("calamity_flame:%d" % get_instance_id())
	set_process(false)


func play_attack() -> void:
	# Keep embers from the previous fast swing alive while restarting the weapon's
	# short line-trail feedback.
	super.cancel_feedback()
	if data == null:
		return
	_play_melee_feedback()
	cue_requested.emit(data.id, &"swing", global_position)
	_emit_remaining = data.melee_active_seconds
	_emit_accumulator = 4.0
	_has_last_tip = false
	set_process(true)


func cancel_feedback() -> void:
	super.cancel_feedback()
	_emit_remaining = 0.0
	_emit_accumulator = 0.0
	_has_last_tip = false
	_particles.clear()
	set_process(false)
	queue_redraw()


func get_live_particle_count() -> int:
	return _particles.size()


func _process(delta: float) -> void:
	var tip_position := flame_tip.global_position
	if _emit_remaining > 0.0:
		var low_quality := int(PlayerConfig.get_config(&"UISettings", &"CombatFeedbackQuality", 1)) == 0
		var reduced_flashes := bool(PlayerConfig.get_config(&"UISettings", &"ReducedFlashes", false))
		var target_count := LOW_PARTICLE_COUNT if low_quality or reduced_flashes else FULL_PARTICLE_COUNT
		var active_seconds := maxf(data.melee_active_seconds if data != null else 0.14, 0.01)
		_emit_accumulator += float(target_count) * delta / active_seconds
		var spawn_count := floori(_emit_accumulator)
		_emit_accumulator -= spawn_count
		_spawn_particles(tip_position, spawn_count)
		_emit_remaining = maxf(_emit_remaining - delta, 0.0)
	_last_tip_position = tip_position
	_has_last_tip = true
	var alive: Array[Dictionary] = []
	for particle in _particles:
		particle.life = float(particle.life) - delta
		if particle.life <= 0.0:
			continue
		particle.position += particle.velocity * delta
		particle.velocity = particle.velocity.lerp(Vector2.UP * -18.0, clampf(delta * 2.8, 0.0, 1.0))
		alive.append(particle)
	_particles = alive
	queue_redraw()
	if _emit_remaining <= 0.0 and _particles.is_empty():
		set_process(false)


func _spawn_particles(tip_position: Vector2, count: int) -> void:
	if count <= 0:
		return
	var previous := _last_tip_position if _has_last_tip else tip_position
	var tangent := tip_position - previous
	var blade_direction := global_transform.x.normalized()
	if tangent.is_zero_approx():
		tangent = blade_direction.rotated(PI * 0.5)
	for index in count:
		var ratio := (float(index) + 0.5) / float(count)
		var position := previous.lerp(tip_position, ratio)
		position += blade_direction.rotated(_rng.randf_range(-1.4, 1.4)) * _rng.randf_range(0.0, 4.5)
		var direction := tangent.normalized().rotated(_rng.randf_range(-0.7, 0.7))
		var lifetime := _rng.randf_range(0.16, PARTICLE_DURATION)
		_particles.append({
			"position": position,
			"velocity": direction * _rng.randf_range(22.0, 76.0) + blade_direction * _rng.randf_range(5.0, 24.0),
			"life": lifetime,
			"max_life": lifetime,
			"size": _rng.randf_range(1.3, 3.2),
			"color": PALETTE[_rng.randi_range(0, PALETTE.size() - 1)],
		})


func _draw() -> void:
	for particle in _particles:
		var ratio := clampf(float(particle.life) / float(particle.max_life), 0.0, 1.0)
		var point := to_local(particle.position as Vector2)
		var velocity := (particle.velocity as Vector2).normalized()
		var length := float(particle.size) * (1.4 + ratio * 2.3)
		var color := Color(particle.color, ratio * 0.9)
		draw_line(point - velocity * length, point + velocity * length * 0.35, color, maxf(1.0, float(particle.size) * ratio))
		draw_circle(point, maxf(0.55, float(particle.size) * ratio * 0.7), color)
