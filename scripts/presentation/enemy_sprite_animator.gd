class_name EnemySpriteAnimator
extends Node

## Native sprite playback owns the frame clock; combat owns hit/shot timing.
const CELL_SIZE := 192
const FOOT_ANCHOR := Vector2(96, 168)
const WALK_FPS := 9.0
const FRAME_COUNTS := {"down": 8, "left": 8, "up": 8, "right": 6}
const FRAMES_PATH := "res://assets/art/characters/enemies/animated/%s_frames.tres"
const FLASH_SHADER_CODE := "shader_type canvas_item; uniform float flash_amount = 0.0; uniform vec4 flash_color : source_color = vec4(1.0); void fragment(){ vec4 tex = texture(TEXTURE, UV); vec4 tint = COLOR; vec3 base = tex.rgb * tint.rgb; COLOR = vec4(mix(base, flash_color.rgb, flash_amount), tex.a * tint.a); }"

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
var _hit_flash_until_usec := 0
var _previous_position := Vector2.ZERO
var _base_position := Vector2.ZERO
var _base_scale := Vector2.ONE
var _reaction_elapsed := 1.0
var _reaction_duration := 0.12
var _reaction_direction := Vector2.RIGHT
var _reaction_strength := 0.0
var _visual_hold_until_usec := 0
var _flash_material: ShaderMaterial


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
	_base_position = body.position
	_base_scale = body.scale
	_flash_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = FLASH_SHADER_CODE
	_flash_material.shader = shader
	body.material = _flash_material
	_impact_remaining = 0.0
	_hit_flash_until_usec = 0
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


func flash_hit(color: Color = Color.WHITE) -> void:
	_hit_flash_until_usec = Time.get_ticks_usec() + 50_000
	if _flash_material != null:
		_flash_material.set_shader_parameter(&"flash_color", color)
		_flash_material.set_shader_parameter(&"flash_amount", 1.0)


func hold_impact(seconds: float) -> void:
	_visual_hold_until_usec = maxi(_visual_hold_until_usec, Time.get_ticks_usec() + int(seconds * 1_000_000.0))


func play_hit_reaction(direction: Vector2, strength: float = 0.5) -> void:
	_reaction_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	_reaction_strength = clampf(strength, 0.0, 1.2)
	_reaction_duration = 0.16 if role_key == "shield" else 0.12
	_reaction_elapsed = 0.0


func play_recoil(direction: Vector2, strength: float = 0.35) -> void:
	play_hit_reaction(-direction, strength * 0.7)


func update_visual(delta: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(body) or body.sprite_frames == null:
		return
	if Time.get_ticks_usec() < _visual_hold_until_usec:
		body.pause()
		_apply_reaction_transform(0.0)
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
	if _flash_material != null:
		var remaining_usec := maxi(_hit_flash_until_usec - Time.get_ticks_usec(), 0)
		_flash_material.set_shader_parameter(&"flash_amount", clampf(float(remaining_usec) / 50_000.0, 0.0, 1.0))
	_apply_reaction_transform(delta)
	var warning := actor.state == EnemyController.State.SELF_DESTRUCT and int(actor._self_destruct_remaining * 16.0) % 2 == 0
	body.modulate = Color(1.7, 1.5, 1.2) if warning else Color.WHITE


func _apply_reaction_transform(delta: float) -> void:
	if _reaction_elapsed >= _reaction_duration:
		body.position = _base_position
		body.scale = _base_scale
		body.rotation = 0.0
		return
	_reaction_elapsed = minf(_reaction_elapsed + delta, _reaction_duration)
	var ratio := _reaction_elapsed / maxf(_reaction_duration, 0.001)
	var pulse := sin(ratio * PI)
	var recoil := (1.0 - ratio) * _reaction_strength
	body.position = _base_position + _reaction_direction * (4.5 * recoil)
	body.scale = _base_scale * Vector2(1.0 + pulse * 0.08 * _reaction_strength, 1.0 - pulse * 0.11 * _reaction_strength)
	body.rotation = _reaction_direction.y * 0.045 * recoil


func _show(animation: String, frame: int) -> void:
	body.animation = animation
	body.pause()
	body.set_frame_and_progress(frame, 0.0)
	body.flip_h = false
