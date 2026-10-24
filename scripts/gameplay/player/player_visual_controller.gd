class_name PlayerVisualController
extends Node2D

const FLASH_SHADER_CODE := "shader_type canvas_item; uniform float flash_amount = 0.0; uniform vec4 flash_color : source_color = vec4(1.0); void fragment(){ vec4 tex = texture(TEXTURE, UV); vec4 tint = COLOR; vec3 base = tex.rgb * tint.rgb; COLOR = vec4(mix(base, flash_color.rgb, flash_amount), tex.a * tint.a); }"

@export var body_sprite_path: NodePath
@export var wrist_socket_path: NodePath
@export var weapon_pivot_path: NodePath
@export var guard_visual_path: NodePath
@export_range(0.1, 60.0, 0.1) var idle_gesture_min_delay := 6.0
@export_range(0.1, 60.0, 0.1) var idle_gesture_max_delay := 10.0

@onready var body_sprite: AnimatedSprite2D = get_node(body_sprite_path)
@onready var wrist_socket: PlayerWristSocket = get_node(wrist_socket_path) as PlayerWristSocket
@onready var weapon_pivot: WeaponMount = get_node(weapon_pivot_path) as WeaponMount
@onready var guard_visual: GuardArcVisual = get_node(guard_visual_path)

var _last_animation := ""
var _hurt_tween: Tween
var _idle_gesture_timer: Timer
var _idle_gesture_active := false
var _moving := false
var _dead := false
var _idle_rng := RandomNumberGenerator.new()
var _flash_material: ShaderMaterial
var _flash_until_usec := 0
var _visual_hold_until_usec := 0
var _reaction_tween: Tween
var _base_position := Vector2.ZERO
var _base_scale := Vector2.ONE


func _ready() -> void:
	_base_position = position
	_base_scale = scale
	_flash_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = FLASH_SHADER_CODE
	_flash_material.shader = shader
	body_sprite.material = _flash_material
	_idle_rng.randomize()
	_idle_gesture_timer = Timer.new()
	_idle_gesture_timer.one_shot = true
	add_child(_idle_gesture_timer)
	_idle_gesture_timer.timeout.connect(_on_idle_gesture_timeout)
	body_sprite.animation_finished.connect(_on_body_animation_finished)
	_schedule_idle_gesture()


func _process(_delta: float) -> void:
	if _flash_material != null:
		var remaining_usec := maxi(_flash_until_usec - Time.get_ticks_usec(), 0)
		_flash_material.set_shader_parameter(&"flash_amount", clampf(float(remaining_usec) / 50_000.0, 0.0, 1.0))
	if Time.get_ticks_usec() < _visual_hold_until_usec:
		body_sprite.pause()


func update_visual(
	aim_direction: Vector2,
	velocity: Vector2,
	guard_state: GuardComponent.State,
	guard_arc: float,
	weapon_swing_offset: float = 0.0,
	aim_target: Vector2 = Vector2.INF
) -> void:
	var moving := velocity.length_squared() > 64.0
	if moving != _moving:
		_moving = moving
		if moving:
			_cancel_idle_gesture()
		else:
			_schedule_idle_gesture()
	var direction_name := _direction_name(aim_direction)
	var animation := _body_animation(direction_name, moving)
	if _has_ranged_weapon() and _idle_gesture_active:
		_cancel_idle_gesture()
	if not moving and _idle_gesture_active:
		animation = &"idle_gesture"
	if body_sprite.sprite_frames.has_animation(animation) and (animation != _last_animation or not body_sprite.is_playing()):
		body_sprite.play(animation)
		_last_animation = animation
	if Time.get_ticks_usec() < _visual_hold_until_usec:
		body_sprite.pause()
	body_sprite.flip_h = false
	wrist_socket.sync_pose(body_sprite, StringName(animation), body_sprite.frame)
	weapon_pivot.position = wrist_socket.position
	update_weapon_aim(aim_direction, weapon_swing_offset, aim_target)
	guard_visual.update_guard(guard_state, aim_direction, guard_arc)


func update_weapon_aim(aim_direction: Vector2, weapon_swing_offset: float = 0.0, aim_target: Vector2 = Vector2.INF) -> void:
	var angle := aim_direction.angle()
	if aim_target.is_finite() and is_instance_valid(weapon_pivot.current_view):
		var delta := to_local(aim_target) - weapon_pivot.position
		var muzzle_y := weapon_pivot.to_local(weapon_pivot.current_view.muzzle_socket.global_position).y
		if aim_direction.x < 0.0:
			muzzle_y = -muzzle_y
		if delta.length() > absf(muzzle_y) + 2.0:
			angle = delta.angle() - asin(muzzle_y / delta.length())
	weapon_pivot.rotation = angle + weapon_swing_offset
	weapon_pivot.scale.y = -1.0 if aim_direction.x < 0.0 else 1.0
	var direction_name := _direction_name(aim_direction)
	_set_weapon_draw_order(direction_name)


func play_hurt_flash() -> void:
	if _hurt_tween != null and _hurt_tween.is_valid():
		_hurt_tween.kill()
	modulate = Color(1.8, 1.8, 1.8, 1.0)
	_hurt_tween = create_tween()
	_hurt_tween.set_ignore_time_scale(true)
	_hurt_tween.tween_property(self, "modulate", Color.WHITE, 0.12)


func flash_hit(color: Color = Color.WHITE) -> void:
	_flash_until_usec = Time.get_ticks_usec() + 50_000
	if _flash_material != null:
		_flash_material.set_shader_parameter(&"flash_color", color)
		_flash_material.set_shader_parameter(&"flash_amount", 1.0)


func hold_impact(seconds: float) -> void:
	_visual_hold_until_usec = maxi(_visual_hold_until_usec, Time.get_ticks_usec() + int(seconds * 1_000_000.0))


func play_hit_reaction(direction: Vector2, strength: float = 0.7) -> void:
	_play_reaction(direction, strength, false)


func play_recoil(direction: Vector2, strength: float = 0.35) -> void:
	_play_reaction(-direction, strength, true)


func _play_reaction(direction: Vector2, strength: float, recoil: bool) -> void:
	if _reaction_tween != null and _reaction_tween.is_valid():
		_reaction_tween.kill()
	var axis := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	var amount := (2.8 if recoil else 4.2) * clampf(strength, 0.0, 1.2)
	position = _base_position + axis * amount
	scale = _base_scale * Vector2(1.0 + 0.06 * strength, 1.0 - 0.08 * strength)
	_reaction_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_ignore_time_scale(true)
	_reaction_tween.set_parallel(true)
	_reaction_tween.tween_property(self, "position", _base_position, 0.13)
	_reaction_tween.tween_property(self, "scale", _base_scale, 0.13)


func set_weapon(data: WeaponComponentData) -> void:
	weapon_pivot.set_weapon(data)
	if _has_ranged_weapon():
		_cancel_idle_gesture()
	else:
		_schedule_idle_gesture()


func play_weapon_attack() -> void:
	weapon_pivot.play_attack()


func get_weapon_muzzle_global_position() -> Vector2:
	return weapon_pivot.get_muzzle_global_position()


func get_weapon_mount_global_position() -> Vector2:
	return weapon_pivot.global_position


func get_weapon_barrel_global_direction() -> Vector2:
	return weapon_pivot.global_transform.x.normalized()


func set_dead(dead: bool) -> void:
	_dead = dead
	guard_visual.set_disabled(dead)
	if dead:
		_cancel_idle_gesture()
		weapon_pivot.cancel_feedback()
		body_sprite.stop()
		rotation = deg_to_rad(90.0)
		modulate = Color(0.45, 0.45, 0.45, 0.75)
	else:
		rotation = 0.0
		modulate = Color.WHITE
		_schedule_idle_gesture()


func _schedule_idle_gesture() -> void:
	if _idle_gesture_timer == null or _dead or _moving or _idle_gesture_active or _has_ranged_weapon():
		return
	var minimum := minf(idle_gesture_min_delay, idle_gesture_max_delay)
	var maximum := maxf(idle_gesture_min_delay, idle_gesture_max_delay)
	_idle_gesture_timer.start(_idle_rng.randf_range(minimum, maximum))


func _cancel_idle_gesture() -> void:
	_idle_gesture_active = false
	if _idle_gesture_timer != null:
		_idle_gesture_timer.stop()


func _on_idle_gesture_timeout() -> void:
	if _dead or _moving or _has_ranged_weapon() or not body_sprite.sprite_frames.has_animation(&"idle_gesture"):
		return
	_idle_gesture_active = true
	body_sprite.play(&"idle_gesture")
	_last_animation = &"idle_gesture"


func _on_body_animation_finished() -> void:
	if body_sprite.animation != &"idle_gesture":
		return
	_idle_gesture_active = false
	body_sprite.play(&"idle")
	_last_animation = &"idle"
	_schedule_idle_gesture()


func _direction_name(direction: Vector2) -> String:
	if absf(direction.y) > absf(direction.x) * 0.75:
		return "up" if direction.y < 0.0 else "down"
	return "left" if direction.x < 0.0 else "right"


func _body_animation(direction_name: String, moving: bool) -> StringName:
	if not moving:
		return &"idle"
	return StringName("walk_" + direction_name)


func _has_ranged_weapon() -> bool:
	return is_instance_valid(weapon_pivot) and weapon_pivot.current_data != null and weapon_pivot.current_data.attack_kind != WeaponComponentData.AttackKind.MELEE


func _weapon_draws_in_front(direction_name: String) -> bool:
	return direction_name == "down" or direction_name == "right"


func _set_weapon_draw_order(direction_name: String) -> void:
	# Keep every player part on the actor's normal canvas layer. A negative
	# z-index would also put the gun behind the floor; sibling order changes only
	# its relationship to the body. The sleeve remains last and covers the hand.
	weapon_pivot.z_index = 0
	if not _weapon_draws_in_front(direction_name):
		if weapon_pivot.get_index() > body_sprite.get_index():
			move_child(weapon_pivot, body_sprite.get_index())
		return
	var socket_index := wrist_socket.get_index()
	var target_index := socket_index - 1 if weapon_pivot.get_index() < socket_index else socket_index
	if weapon_pivot.get_index() != target_index:
		move_child(weapon_pivot, target_index)
