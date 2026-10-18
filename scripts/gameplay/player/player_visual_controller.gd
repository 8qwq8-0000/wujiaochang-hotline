class_name PlayerVisualController
extends Node2D

@export var body_sprite_path: NodePath
@export var wrist_socket_path: NodePath
@export var weapon_pivot_path: NodePath
@export var guard_visual_path: NodePath

@onready var body_sprite: AnimatedSprite2D = get_node(body_sprite_path)
@onready var wrist_socket: PlayerWristSocket = get_node(wrist_socket_path) as PlayerWristSocket
@onready var weapon_pivot: WeaponMount = get_node(weapon_pivot_path) as WeaponMount
@onready var guard_visual: GuardArcVisual = get_node(guard_visual_path)

var _last_animation := ""
var _hurt_tween: Tween


func update_visual(
	aim_direction: Vector2,
	velocity: Vector2,
	guard_state: GuardComponent.State,
	guard_arc: float,
	weapon_swing_offset: float = 0.0
) -> void:
	var moving := velocity.length_squared() > 64.0
	var direction_name := _direction_name(aim_direction)
	var animation := _body_animation(direction_name, moving)
	if animation != _last_animation and body_sprite.sprite_frames.has_animation(animation):
		body_sprite.play(animation)
		_last_animation = animation
	# Every direction now has an authored source animation. The sole idle clip
	# always keeps its original orientation, so body mirroring is disabled.
	body_sprite.flip_h = false
	wrist_socket.sync_pose(body_sprite, StringName(animation), body_sprite.frame)
	weapon_pivot.position = wrist_socket.position
	update_weapon_aim(aim_direction, weapon_swing_offset)
	guard_visual.update_guard(guard_state, aim_direction, guard_arc)


func update_weapon_aim(aim_direction: Vector2, weapon_swing_offset: float = 0.0) -> void:
	weapon_pivot.rotation = aim_direction.angle() + weapon_swing_offset
	weapon_pivot.scale.y = -1.0 if aim_direction.x < 0.0 else 1.0
	var direction_name := _direction_name(aim_direction)
	_set_weapon_draw_order(direction_name)


func play_hurt_flash() -> void:
	if _hurt_tween != null and _hurt_tween.is_valid():
		_hurt_tween.kill()
	modulate = Color(1.8, 1.8, 1.8, 1.0)
	_hurt_tween = create_tween()
	_hurt_tween.tween_property(self, "modulate", Color.WHITE, 0.12)


func set_weapon(data: WeaponComponentData) -> void:
	weapon_pivot.set_weapon(data)


func play_weapon_attack() -> void:
	weapon_pivot.play_attack()


func get_weapon_muzzle_global_position() -> Vector2:
	return weapon_pivot.get_muzzle_global_position()


func get_weapon_mount_global_position() -> Vector2:
	return weapon_pivot.global_position


func set_dead(dead: bool) -> void:
	if dead:
		weapon_pivot.cancel_feedback()
		body_sprite.stop()
		rotation = deg_to_rad(90.0)
		modulate = Color(0.45, 0.45, 0.45, 0.75)
	else:
		rotation = 0.0
		modulate = Color.WHITE


func _direction_name(direction: Vector2) -> String:
	if absf(direction.y) > absf(direction.x) * 0.75:
		return "up" if direction.y < 0.0 else "down"
	return "left" if direction.x < 0.0 else "right"


func _body_animation(direction_name: String, moving: bool) -> StringName:
	if not moving:
		return &"idle"
	return StringName("walk_" + direction_name)


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
