class_name ChannelBossEffect
extends Node2D

## Authored VFX and explicit ground geometry share one paused physics clock.
const FRAMES := preload("res://assets/art/effects/channel_boss_v1/frames.tres")
const ECHO_RADIUS := Vector2(40, 22)
const HALO_OFFSETS := [-78.0, 0.0, 78.0]
const HALO_WIDTH := 20.0
const HALO_WARNING := 0.96
const WAVE_MAX_RADIUS := 240.0
const WAVE_Y_SCALE := 0.55
const WAVE_THICKNESS := 10.0
var arena: RooftopBossArena
var skill: StringName = &"echo"
var elapsed := 0.0
var resolved := false
var wave_contact := false
var previous_radius := 0.0
var sprite: AnimatedSprite2D


func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = FRAMES
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var size := 0.28
	var anchor := Vector2(222, 244)
	z_index = 9
	if skill == &"halo":
		size = 0.7
		anchor = Vector2(222, 354)
		z_index = 20
	elif skill == &"protect":
		size = 1.25
		anchor = Vector2(222, 228)
	sprite.scale = Vector2.ONE * size
	sprite.position = -anchor * size
	add_child(sprite)
	sprite.play(skill)
	sprite.animation_finished.connect(queue_free)
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
	if skill == &"halo":
		for rect in halo_rects():
			if rect.has_point(point):
				return true
	return false


func wave_radius(clock: float) -> float:
	return lerpf(24.0, WAVE_MAX_RADIUS, clampf(clock / 0.66, 0, 1))


func _physics_process(delta: float) -> void:
	if arena == null or arena.phase != arena.Phase.BOSS_ACTIVE or arena.player.health.is_dead():
		queue_free()
		return
	elapsed += delta
	if skill in [&"echo", &"halo"]:
		var strike_time := 0.8 if skill == &"echo" else HALO_WARNING
		if not resolved and elapsed >= strike_time:
			resolved = true
			if contains_impact(arena.player.global_position):
				arena._damage_player(global_position)
	elif skill == &"protect":
		var radius := wave_radius(elapsed)
		var point := arena.player.global_position - global_position
		point.y /= WAVE_Y_SCALE
		var distance := point.length()
		if not wave_contact and elapsed <= 0.68 and distance >= previous_radius - WAVE_THICKNESS and distance <= radius + WAVE_THICKNESS:
			# One ring crossing only; dash invulnerability still goes through HurtBox.
			wave_contact = true
			arena._damage_player(global_position)
		previous_radius = radius
	queue_redraw()


func _draw() -> void:
	if skill == &"echo" and elapsed < 0.8:
		draw_set_transform(Vector2.ZERO, 0, Vector2(1, ECHO_RADIUS.y / ECHO_RADIUS.x))
		draw_circle(Vector2.ZERO, ECHO_RADIUS.x, Color(0.25, 0.85, 1, 0.08))
		draw_arc(Vector2.ZERO, ECHO_RADIUS.x, 0, TAU, 48, Color(0.5, 0.93, 1, 0.85), 1.5)
		draw_set_transform(Vector2.ZERO)
	elif skill == &"halo":
		for world_rect in halo_rects():
			var rect := Rect2(to_local(world_rect.position), world_rect.size)
			if elapsed < HALO_WARNING:
				draw_rect(rect, Color(1, 0.8, 0.28, 0.12))
				draw_rect(rect, Color(1, 0.85, 0.5, 0.8), false, 1)
			elif elapsed < HALO_WARNING + 0.21:
				draw_rect(rect, Color(1, 0.85, 0.35, 0.42))
				draw_rect(Rect2(rect.position.x + 8, rect.position.y, 4, rect.size.y), Color(1, 0.97, 0.85, 0.92))
	elif skill == &"protect" and elapsed <= 0.68:
		# Continuous rim matches the swept damage interval between authored frames.
		draw_set_transform(Vector2.ZERO, 0, Vector2(1, WAVE_Y_SCALE))
		draw_arc(Vector2.ZERO, wave_radius(elapsed), 0, TAU, 72, Color(0.5, 0.95, 1, 0.75), 2)
		draw_set_transform(Vector2.ZERO)
