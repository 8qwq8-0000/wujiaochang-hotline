class_name PlayerWristSocket
extends Node2D

## Right-wrist attachment for the current placeholder animation pack.
## Coordinates are authored in each 128x256 source cell and converted through
## BodyVisual's existing transform, so no character PNG needs to be edited.

const FRAME_SIZE := Vector2(128.0, 256.0)
const WRIST_PIXELS := {
	&"idle": [
		Vector2(18, 169), Vector2(26, 160), Vector2(34, 150),
		Vector2(40, 143), Vector2(34, 151), Vector2(25, 165),
	],
	&"walk_down": [
		Vector2(19, 165), Vector2(20, 164), Vector2(20, 164),
		Vector2(19, 165), Vector2(19, 165), Vector2(19, 165),
	],
	&"walk_up": [
		Vector2(105, 166), Vector2(104, 164), Vector2(105, 164),
		Vector2(105, 166), Vector2(104, 164), Vector2(104, 167),
	],
	&"walk_left": [
		Vector2(27, 155), Vector2(31, 164), Vector2(28, 164),
		Vector2(27, 155), Vector2(31, 164), Vector2(28, 164),
	],
	&"walk_right": [
		Vector2(81, 164), Vector2(78, 169), Vector2(82, 159),
		Vector2(78, 163), Vector2(82, 145), Vector2(81, 164),
	],
}

var facing := &"left"
var current_animation := &"idle"
var current_frame := 0


func _ready() -> void:
	queue_redraw()


func sync_pose(body_sprite: AnimatedSprite2D, animation: StringName, frame: int) -> void:
	if body_sprite == null:
		return
	var points: Array = WRIST_PIXELS.get(animation, WRIST_PIXELS[&"idle"])
	if points.is_empty():
		return
	current_animation = animation
	current_frame = clampi(frame, 0, points.size() - 1)
	facing = _animation_direction(animation)
	var source_point: Vector2 = points[current_frame]
	position = body_sprite.position + (source_point - FRAME_SIZE * 0.5) * body_sprite.scale.abs()
	queue_redraw()


func get_pose_frame_count(animation: StringName) -> int:
	var points: Array = WRIST_PIXELS.get(animation, [])
	return points.size()


func get_source_wrist(animation: StringName, frame: int) -> Vector2:
	var points: Array = WRIST_PIXELS.get(animation, [])
	if points.is_empty():
		return Vector2.ZERO
	return points[clampi(frame, 0, points.size() - 1)]


func _animation_direction(animation: StringName) -> StringName:
	if animation == &"idle":
		return &"left"
	var text := String(animation)
	for direction in [&"down", &"up", &"left", &"right"]:
		if text.ends_with(String(direction)):
			return direction
	return &"down"


func _draw() -> void:
	# Low-cost fixed sleeve: it covers the old hand pose while the weapon child
	# rotates independently around this origin.
	var horizontal := facing == &"left" or facing == &"right"
	var outer := Rect2(-3, -2, 6, 4) if horizontal else Rect2(-2, -3, 4, 6)
	draw_rect(outer, Color("161b21"))
	draw_rect(outer, Color("7e8990"), false, 1.0)
	draw_rect(Rect2(-1, -1, 2, 2), Color("43d9df"))
