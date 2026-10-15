class_name AfterimageEffect
extends Sprite2D

signal finished(effect: AfterimageEffect)

var source_id: int = 0
var _duration := 0.25
var _elapsed := 0.0
var _base_color := Color(0.25, 0.85, 1.0, 0.55)


func play(source: Node, sprite: AnimatedSprite2D, color: Color, duration: float) -> bool:
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
	_elapsed = 0.0
	visible = true
	set_process(true)
	return true


func stop() -> void:
	visible = false
	set_process(false)
	source_id = 0
	texture = null


func _process(delta: float) -> void:
	_elapsed += delta
	var ratio := clampf(_elapsed / _duration, 0.0, 1.0)
	modulate = _base_color
	modulate.a = _base_color.a * (1.0 - ratio)
	if _elapsed >= _duration:
		stop()
		finished.emit(self)
