class_name RooftopWhaleGoddess
extends StaticBody2D

signal awakened
signal halo_segments_changed(remaining: int, maximum: int)
signal defeated

enum State {
	DORMANT,
	AWAKENING,
	ACTIVE,
	DEFEATED,
}

@export var dormant_texture: Texture2D
@export_range(0.1, 4.0, 0.05) var awakening_duration := 1.15
@export_range(1, 12, 1) var halo_segment_count := 5

@onready var body_sprite: Sprite2D = $BodySprite
@onready var glow_sprite: Sprite2D = $GlowSprite
@onready var echo_probe_audio: AudioStreamPlayer2D = $EchoProbeAudio
@onready var hurt_box: HurtBox2DComponent = $HurtBox
@onready var health: HealthComponent = $HealthComponent

var state := State.DORMANT
var halo_segments_remaining := 5
var _anger_remaining := 0.0


func _ready() -> void:
	add_to_group("bosses")
	halo_segments_remaining = halo_segment_count
	body_sprite.texture = dormant_texture
	glow_sprite.visible = false
	hurt_box.monitorable = false
	health.health_changed.connect(_on_health_changed)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	queue_redraw()


func _process(delta: float) -> void:
	if state != State.ACTIVE:
		return
	_anger_remaining = maxf(_anger_remaining - delta, 0.0)
	var breath := 0.64 + sin(Time.get_ticks_msec() * 0.0035) * 0.16
	if _anger_remaining > 0.0:
		glow_sprite.modulate = Color(1.0, 0.36, 0.12, minf(breath + 0.2, 1.0))
	else:
		# The mask already carries cyan and amber channels; white modulation preserves both.
		glow_sprite.modulate = Color(1.0, 1.0, 1.0, breath)


func begin_awakening() -> void:
	if state != State.DORMANT:
		return
	state = State.AWAKENING
	# Phase two keeps the dormant statue base. State is communicated entirely
	# by the separately-authored colored glow mask.
	body_sprite.texture = dormant_texture
	glow_sprite.visible = true
	glow_sprite.modulate = Color(0.55, 0.95, 1.0, 0.0)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(glow_sprite, "modulate", Color(1.0, 1.0, 1.0, 0.8), awakening_duration)
	await tween.finished
	if state != State.AWAKENING:
		return
	state = State.ACTIVE
	hurt_box.set_deferred("monitorable", true)
	queue_redraw()
	awakened.emit()


func activate_immediately() -> void:
	if state == State.DEFEATED:
		return
	state = State.ACTIVE
	body_sprite.texture = dormant_texture
	glow_sprite.visible = true
	glow_sprite.modulate = Color(1.0, 1.0, 1.0, 0.75)
	hurt_box.monitorable = true
	queue_redraw()
	awakened.emit()


func play_echo_probe() -> void:
	# A probe is a single authored pulse. Restarting prevents accidental overlap
	# if a test or future attack pattern requests another probe too early.
	if echo_probe_audio.playing:
		echo_probe_audio.stop()
	echo_probe_audio.play()


func get_halo_segments_remaining() -> int:
	return halo_segments_remaining


func is_core_exposed() -> bool:
	return state == State.ACTIVE and health.current_health == 1


func _on_health_changed(current: int, _maximum: int, _delta: int) -> void:
	var next_segments := clampi(current - 1, 0, halo_segment_count)
	if next_segments != halo_segments_remaining:
		halo_segments_remaining = next_segments
		halo_segments_changed.emit(halo_segments_remaining, halo_segment_count)
	queue_redraw()


func _on_damaged(_amount: int, _packet: DamagePacket) -> void:
	if state == State.ACTIVE:
		_anger_remaining = 0.34


func _on_died(_packet: DamagePacket) -> void:
	if state == State.DEFEATED:
		return
	state = State.DEFEATED
	hurt_box.set_deferred("monitorable", false)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow_sprite, "modulate:a", 0.0, 0.55)
	queue_redraw()
	defeated.emit()


func _draw() -> void:
	if state not in [State.ACTIVE, State.DEFEATED]:
		return
	var center := Vector2(0.0, -78.0)
	var radius := 54.0
	var arc_span := deg_to_rad(19.0)
	for index in halo_segment_count:
		var angle := deg_to_rad(216.0 + index * 27.0)
		var color := Color(0.25, 0.95, 1.0, 0.9) if index < halo_segments_remaining else Color(0.12, 0.16, 0.22, 0.55)
		draw_arc(center, radius, angle - arc_span * 0.5, angle + arc_span * 0.5, 10, color, 3.0)
	if is_core_exposed():
		draw_circle(Vector2(0.0, -20.0), 7.0, Color(1.0, 0.32, 0.12, 0.85), false, 2.0)
