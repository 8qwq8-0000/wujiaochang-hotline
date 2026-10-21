class_name EnemySpriteAnimator
extends Node

## Native sprite playback owns the frame clock; combat owns hit/shot timing.
const CELL_SIZE := 192
const FOOT_ANCHOR := Vector2(96, 168)
const WALK_FPS := 9.0
const FRAME_COUNTS := {"down": 8, "left": 8, "up": 8, "right": 6}
const FRAMES_PATH := "res://assets/art/characters/enemies/animated/%s_frames.tres"

var actor: EnemyController
var body: AnimatedSprite2D
var role_key := "melee"
var current_animation: String:
	get:
		return String(body.animation) if is_instance_valid(body) else ""
var current_frame: int:
	get:
		return body.frame if is_instance_valid(body) else 0
var _impact_remaining := 0.0
var _impact_duration := 0.18
var _impact_direction := "left"
var _hit_flash_remaining := 0.0
var _previous_position := Vector2.ZERO


func configure(enemy: EnemyController, sprite: AnimatedSprite2D) -> void:
	actor = enemy
	body = sprite
	role_key = ["melee", "ranged", "shield"][int(actor.profile.role)]
	body.sprite_frames = load(FRAMES_PATH % role_key)
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.scale = Vector2.ONE * (0.5 if role_key == "shield" else 0.45)
	body.centered = false
	body.offset = -FOOT_ANCHOR
	body.position = Vector2(0, 10)
	body.flip_h = false
	_previous_position = actor.global_position
	_impact_remaining = 0.0
	_hit_flash_remaining = 0.0
	update_visual(0.0)


func _process(delta: float) -> void:
	update_visual(delta)


func direction_name(direction: Vector2) -> String:
	if absf(direction.y) > absf(direction.x):
		return "down" if direction.y > 0.0 else "up"
	return "right" if direction.x > 0.0 else "left"


func play_impact(direction: Vector2) -> void:
	_impact_direction = direction_name(direction)
	_impact_duration = 0.24 if role_key == "shield" else (0.15 if role_key == "ranged" else 0.18)
	_impact_remaining = _impact_duration
	# Seek to contact in the same tick as damage/projectile creation, then let
	# AnimatedSprite2D play the three recovery frames without restarting them.
	body.play("attack_" + _impact_direction, 3.0 / (_impact_duration * 12.0))
	body.set_frame_and_progress(3, 0.0)


func cancel_attack() -> void:
	_impact_remaining = 0.0


func flash_hit() -> void:
	_hit_flash_remaining = 0.08


func update_visual(delta: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(body) or body.sprite_frames == null:
		return
	# A physics displacement remains valid across every render frame until the
	# next move_and_slide(). Comparing positions per render frame resets walk
	# clips whenever rendering runs faster than physics (e.g. 144 vs 60 Hz).
	var moved := (actor.velocity.length_squared() > 0.0001 and actor.get_position_delta().length_squared() > 0.0001) if actor.is_physics_processing() else actor.global_position.distance_squared_to(_previous_position) > 0.0001
	_previous_position = actor.global_position
	var direction := direction_name(actor.facing)
	if actor.state in [EnemyController.State.DEAD, EnemyController.State.SELF_DESTRUCT, EnemyController.State.STAGGERED]:
		cancel_attack()
		_show("idle_" + direction, 0)
	elif _impact_remaining > 0.0:
		_impact_remaining = maxf(_impact_remaining - delta, 0.0)
		if _impact_remaining == 0.0:
			_show("attack_" + _impact_direction, 5)
	elif actor.state == EnemyController.State.WINDUP:
		var clip := "attack_" + direction_name(actor._attack_direction)
		if current_animation != clip or (not body.is_playing() and body.frame > 2):
			body.play(clip, 3.0 / (maxf(actor.profile.attack_windup, 0.001) * 12.0))
			body.set_frame_and_progress(0, 0.0)
		if body.frame >= 3:
			_show(clip, 2)
	elif moved:
		var clip := "walk_" + direction
		if current_animation != clip or not body.is_playing():
			body.play(clip, 0.72 if role_key == "shield" else 1.0)
	else:
		_show("idle_" + direction, 0)
	_hit_flash_remaining = maxf(_hit_flash_remaining - delta, 0.0)
	var warning := actor.state == EnemyController.State.SELF_DESTRUCT and int(actor._self_destruct_remaining * 16.0) % 2 == 0
	body.modulate = Color(1.7, 1.5, 1.2) if warning or _hit_flash_remaining > 0.0 else Color.WHITE


func _show(animation: String, frame: int) -> void:
	body.animation = animation
	body.pause()
	body.set_frame_and_progress(frame, 0.0)
	body.flip_h = false
