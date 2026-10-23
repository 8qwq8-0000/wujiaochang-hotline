class_name AfterimageEffect
extends Sprite2D

signal finished(effect: AfterimageEffect)

var source_id: int = 0
var _duration := 0.25
var _elapsed := 0.0
var _base_color := Color(0.25, 0.85, 1.0, 0.55)
var _drift_velocity := Vector2.ZERO


func play(
	source: Node,
	sprite: AnimatedSprite2D,
	color: Color,
	duration: float,
	drift_direction: Vector2 = Vector2.ZERO,
	drift_distance: float = 0.0
) -> bool:
	if not is_instance_valid(source) or not is_instance_valid(sprite) or sprite.sprite_frames == null:
		return false
	var frame_texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if frame_texture == null:
		return false
	source_id = source.get_instance_id()
	texture = frame_texture
	global_transform = sprite.global_transform
	centered = sprite.centered
	offset = sprite.offset
	flip_h = sprite.flip_h
	flip_v = sprite.flip_v
	_base_color = color
	modulate = color
	_duration = maxf(duration, 0.01)
	_drift_velocity = (drift_direction.normalized() if not drift_direction.is_zero_approx() else Vector2.ZERO) * drift_distance / _duration
	_elapsed = 0.0
	visible = true
	set_process(true)
	return true


func stop() -> void:
	visible = false
	set_process(false)
	source_id = 0
	texture = null
	_drift_velocity = Vector2.ZERO


func _process(delta: float) -> void:
	_elapsed += delta
	var ratio := clampf(_elapsed / _duration, 0.0, 1.0)
	modulate = _base_color
	modulate.a = _base_color.a * (1.0 - ratio)
	global_position += _drift_velocity * delta * (1.0 - ratio)
	if _elapsed >= _duration:
		stop()
		finished.emit(self)
