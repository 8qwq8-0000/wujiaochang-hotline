class_name BossCombatPresentation
extends Node2D

## Arena-owned feedback only: never changes damage, attack clocks or collision.
const PROBE := preload("res://assets/audio/sfx/bosses/rooftop_whale_echo_probe.wav")
const SONG := preload("res://assets/audio/sfx/bosses/rooftop_whale_song.wav")
const METAL := preload("res://assets/audio/sfx/combat/weapon_hits/material_heavy_metal_02.wav")
const SHIELD := preload("res://assets/audio/sfx/combat/defense/block_metal_03.wav")
const ENERGY := preload("res://assets/audio/sfx/combat/defense/perfect_guard_energy_02.wav")
const SWEEP := preload("res://assets/audio/sfx/combat/melee_swing.wav")
const WEIGHT := preload("res://assets/audio/sfx/combat/kills/heavy_kill_weight_02.wav")
const GOLD := Color("ffd380")
const CYAN := Color("80edff")
const VIOLET := Color("b4a0ff")
const MAX_PULSES := 24
const VOICE_COUNT := 6

var arena: Node2D
var pulses: Array[Dictionary] = []
var voices: Array[AudioStreamPlayer2D] = []
var event_counts: Dictionary = {}
var _clock := 0.0
var _next_hit := 0.0
var _next_release := 0.0
var _normal_voice := 0
var _critical_voice := 0
var _hit_flash := 0.0
var _dead := false
var _shield_progress := 0
var _body_origin := Vector2.ZERO
var _glow_origin := Vector2.ZERO
var _recoil := Vector2.ZERO


func _ready() -> void:
	arena = get_parent()
	_body_origin = arena.boss.body_sprite.position
	_glow_origin = arena.boss.glow_sprite.position
	z_index = 24
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for index in VOICE_COUNT:
		var voice := AudioStreamPlayer2D.new()
		voice.bus = &"SFX"
		voice.max_distance = 1800.0
		voice.attenuation = 0.5
		add_child(voice)
		voices.append(voice)
	get_node("/root/CombatEvents").damage_resolved.connect(_on_damage)
	arena.boss.health.health_changed.connect(_on_health_changed)
	arena.boss.defeated.connect(_on_defeated)
	arena.player.player_died.connect(_on_player_died)


func _process(delta: float) -> void:
	_clock += delta
	_recoil = _recoil.lerp(Vector2.ZERO, 1.0 - exp(-delta * 28.0))
	_hit_flash = maxf(_hit_flash - delta, 0.0)
	if is_instance_valid(arena.boss) and not arena.boss.channel_form:
		arena.boss.body_sprite.position = _body_origin + _recoil
		arena.boss.glow_sprite.position = _glow_origin + _recoil
		arena.boss.body_sprite.self_modulate = Color(1.35, 1.23, 1.03) if _hit_flash > 0.0 else Color.WHITE
	for index in range(pulses.size() - 1, -1, -1):
		pulses[index].age += delta
		if float(pulses[index].age) >= float(pulses[index].life):
			pulses.remove_at(index)
	queue_redraw()


func cast(skill: StringName, point: Vector2, warning: float) -> void:
	if _dead:
		return
	var color := _skill_color(skill)
	_pulse(&"charge", point, color, warning, 24.0)
	# Lightning and echo already have authored probe/strike players in the arena.
	if skill not in [&"echo", &"lightning"]:
		_sound(PROBE, point, -13.0, 0.72 if skill == &"protect" else 1.18)
	_record(&"cast_" + String(skill))


func release(skill: StringName, point: Vector2) -> void:
	if _dead or _clock < _next_release:
		return
	_next_release = _clock + 0.04
	var color := _skill_color(skill)
	_pulse(&"release", point, color, 0.32, 31.0 if skill == &"echo" else 45.0)
	match skill:
		&"tail": _sound(SWEEP, point, -6.0, 0.7)
		&"protect": _sound(ENERGY, point, -8.0, 0.68)
		&"halo": _sound(ENERGY, point, -9.0, 1.15)
		&"echo": _sound(WEIGHT, point, -12.0, 1.15)
	# Existing lightning strike owns its thunder, rather than duplicating it.
	_record(&"release_" + String(skill))


func moment(kind: StringName) -> void:
	if _dead:
		return
	var point: Vector2 = arena.boss.global_position - Vector2(0, 64)
	var color := CYAN if arena.boss.channel_form else GOLD
	var breaking := kind == &"break"
	_pulse(&"shatter" if breaking else &"crest", point, color, 0.65 if breaking else 0.9, 82.0)
	if not breaking:
		var base: Vector2 = arena.boss.global_position + Vector2(0, 8 if arena.boss.channel_form else 100)
		_pulse(&"release", base, color, 0.65, 112.0)
	_sound(WEIGHT if breaking else SONG, point, -6.0 if breaking else -11.0, 0.8 if breaking else 0.88, true)
	_shake(0.34 if breaking else 0.22)
	_record(kind)


func _on_health_changed(current: int, _maximum: int, _delta: int) -> void:
	if not arena.boss.health.guard_link_active:
		return
	# A guard-link segment has actually broken; partial guard hits use small sparks.
	var lost: int = arena.boss.health.max_health - current
	if lost > _shield_progress:
		_shield_progress = lost
		moment(&"break")


func _on_damage(result: DamageResult) -> void:
	if _dead or result == null or not is_instance_valid(result.target):
		return
	var is_boss: bool = result.target == arena.boss
	var is_guard: bool = result.target is WingGuard and arena.is_ancestor_of(result.target)
	if not is_boss and not is_guard:
		return
	if result.outcome != DamageResult.Outcome.DAMAGED or result.final_damage <= 0:
		return
	if _clock < _next_hit:
		return
	_next_hit = _clock + 0.08
	var heavy := result.packet != null and result.packet.weapon_id in [&"rail_cannon", &"gravity_wave"]
	var point: Vector2 = result.target.global_position - Vector2(0, 72 if is_boss else 22)
	var direction := Vector2.RIGHT
	if result.packet != null and is_instance_valid(result.packet.source):
		direction = (result.target.global_position - result.packet.source.global_position).normalized()
	point -= direction * (19.0 if is_boss else 12.0)
	_pulse(&"hit", point, CYAN if is_boss else GOLD, 0.26 if heavy else 0.16, 21.0 if heavy else 12.0, direction.angle())
	_sound(METAL if is_boss else SHIELD, point, -10.0 if heavy else -16.0, 0.88 if is_boss else 1.12)
	if is_boss:
		_hit_flash = 0.08
		_recoil = direction * (3.0 if heavy else 1.25)
	if heavy:
		_shake(0.15)
	_record(&"body_hit" if is_boss else &"guard_hit")


func _on_defeated() -> void:
	if _dead:
		return
	moment(&"break")
	var point: Vector2 = arena.boss.global_position - Vector2(0, 64)
	_pulse(&"crest", point, Color("fff2c6"), 1.2, 124.0)
	_sound(SONG, point, -8.0, 0.62, true)
	_shake(0.42)
	_dead = true
	_record(&"defeat")


func _on_player_died(_packet: DamagePacket) -> void:
	_dead = true
	pulses.clear()
	for voice in voices:
		voice.stop()
		voice.stream = null
	queue_redraw()


func _exit_tree() -> void:
	for voice in voices:
		voice.stop()
		voice.stream = null
	if is_instance_valid(arena) and is_instance_valid(arena.boss):
		arena.boss.body_sprite.self_modulate = Color.WHITE
		arena.boss.body_sprite.position = _body_origin
		arena.boss.glow_sprite.position = _glow_origin


func _sound(stream: AudioStream, point: Vector2, volume: float, pitch: float, critical := false) -> void:
	var index: int
	if critical:
		index = _critical_voice % 2
		_critical_voice += 1
	else:
		index = 2 + _normal_voice % (VOICE_COUNT - 2)
		_normal_voice += 1
	var voice := voices[index]
	voice.stop()
	voice.stream = stream
	voice.global_position = point
	voice.volume_db = volume
	voice.pitch_scale = pitch
	voice.play()


func _shake(strength: float) -> void:
	# PlayerController applies the user's camera motion setting, including zero.
	if is_instance_valid(arena.player) and not arena.player.health.is_dead():
		arena.player.add_camera_trauma(Vector2.DOWN, strength)


func _skill_color(skill: StringName) -> Color:
	if skill == &"halo":
		return GOLD
	return VIOLET if skill == &"protect" else CYAN


func _pulse(kind: StringName, point: Vector2, color: Color, life: float, radius: float, angle := 0.0) -> void:
	if pulses.size() >= MAX_PULSES:
		pulses.pop_front()
	pulses.append({"kind": kind, "point": to_local(point), "color": color, "life": life, "age": 0.0, "radius": radius, "angle": angle})
	queue_redraw()


func _record(kind: StringName) -> void:
	event_counts[kind] = int(event_counts.get(kind, 0)) + 1


func _draw() -> void:
	for pulse in pulses:
		var t := clampf(float(pulse.age) / float(pulse.life), 0.0, 1.0)
		var color: Color = pulse.color
		var point: Vector2 = pulse.point
		var radius := float(pulse.radius)
		var kind: StringName = pulse.kind
		color.a = (1.0 - t) * (0.65 if kind == &"charge" else 0.9)
		if kind == &"hit":
			for index in 5:
				var angle := float(pulse.angle) + (float(index) - 2.0) * 0.62
				var direction := Vector2.from_angle(angle)
				draw_line(point + direction * radius * t, point + direction * radius * (t + 0.45), color, 2.0)
			if t < 0.3:
				draw_rect(Rect2(point - Vector2(2, 2), Vector2(4, 4)), Color("fff8df"))
		elif kind == &"shatter":
			for index in 12:
				var direction := Vector2.from_angle(TAU * float(index) / 12.0)
				var center := point + direction * radius * (0.4 + t * 0.8) + Vector2(0, 30 * t * t)
				draw_colored_polygon(PackedVector2Array([center + direction * 7, center + direction.orthogonal() * 3, center - direction * 4, center - direction.orthogonal() * 3]), color)
		else:
			var size := radius * (1.0 - t * 0.65 if kind == &"charge" else 0.4 + t * 0.75)
			var squash := 0.55 if kind == &"release" else 1.0
			for index in 8:
				var angle := TAU * float(index) / 8.0
				var a := point + Vector2(cos(angle), sin(angle) * squash) * size
				var b := point + Vector2(cos(angle + 0.38), sin(angle + 0.38) * squash) * size
				draw_line(a, b, color, 2.0 if kind == &"charge" else 3.0)
			if kind == &"crest":
				draw_line(point - Vector2(0, size * 1.15), point + Vector2(0, size * 1.15), Color(color, color.a * 0.35), 2.0)
