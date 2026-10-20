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
@onready var health: RooftopBossHealth = $HealthComponent

var state := State.DORMANT
var halo_segments_remaining := 5
var _anger_remaining := 0.0
var opening_guards_remaining := 3
var opening_guards_total := 3


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
	health.damage_enabled = true
	hurt_box.set_deferred("monitorable", true)
	queue_redraw()
	awakened.emit()


func activate_immediately() -> void:
	if state == State.DEFEATED:
		return
	state = State.ACTIVE
	health.damage_enabled = true
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


func set_opening_guards(remaining: int, total: int) -> void:
	opening_guards_total = maxi(total, 1)
	opening_guards_remaining = clampi(remaining, 0, opening_guards_total)
	queue_redraw()


func _on_health_changed(_current: int, _maximum: int, _delta: int) -> void:
	queue_redraw()


func _on_damaged(_amount: int, _packet: DamagePacket) -> void:
	if state == State.ACTIVE:
		_anger_remaining = 0.34


func _on_died(_packet: DamagePacket) -> void:
	if state == State.DEFEATED:
		return
	state = State.DEFEATED
	health.damage_enabled = false
	hurt_box.set_deferred("monitorable", false)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow_sprite, "modulate:a", 0.0, 0.55)
	queue_redraw()
	defeated.emit()


func _draw() -> void:
	# Opening guards have their own counter; no statue health bar before awakening.
	if state in [State.DORMANT, State.AWAKENING]:
		return
	var center := Vector2(0.0, -78.0)
	var radius := 54.0
	var arc_span := deg_to_rad(19.0)
	for index in halo_segment_count:
		var angle := deg_to_rad(216.0 + index * 27.0)
		var color := Color(0.25, 0.95, 1.0, 0.9) if index < halo_segments_remaining else Color(0.12, 0.16, 0.22, 0.55)
		draw_arc(center, radius, angle - arc_span * 0.5, angle + arc_span * 0.5, 10, color, 3.0)
	var remaining := health.get_precise_health()
	var maximum := health.max_health
	var ratio := clampf(float(remaining) / maximum, 0.0, 1.0)
	# Place the health bar just below the statue pedestal.
	var bar_y := 136.0
	var bar := Rect2(-87, bar_y, 174, 9)
	draw_rect(bar.grow(3), Color(0.025, 0.045, 0.075, 0.94), true)
	draw_rect(bar, Color(0.12, 0.18, 0.23), true)
	if ratio > 0.0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), Color(0.18, 0.85, 0.95), true)
	var caption := "BOSS %s" % health.get_health_text()
	if state == State.ACTIVE and health.guard_link_active:
		caption = "SHIELD - %s" % health.get_health_text()
	if state == State.DEFEATED:
		caption = "BOSS DEFEATED"
	draw_string(ThemeDB.fallback_font, Vector2(-87, bar_y + 25), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.95, 1.0))
