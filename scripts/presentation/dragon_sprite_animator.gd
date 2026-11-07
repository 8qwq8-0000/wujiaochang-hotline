class_name DragonSpriteAnimator
extends AnimatedSprite2D

const FRAMES := preload("res://assets/art/characters/companions/dragon_gpt_v1/frames.tres")
var facing := Vector2.DOWN


func _ready() -> void:
	sprite_frames = FRAMES
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = false
	offset = Vector2(-128, -232)
	play(&"idle_down")


func update_motion(motion: Vector2, pace_source: AnimatedSprite2D = null) -> void:
	var moving := motion.length_squared() > 1.0
	if moving:
		facing = motion.normalized()
	# Match the player's direction boundary, including diagonal movement.
	var direction: String
	if absf(facing.y) > absf(facing.x) * 0.75:
		direction = "up" if facing.y < 0 else "down"
	else:
		direction = "left" if facing.x < 0 else "right"
	var clip := StringName(("walk_" if moving else "idle_") + direction)
	speed_scale = 1.0
	if moving and is_instance_valid(pace_source):
		# Follow the protagonist's authored walk rate and playback multiplier.
		# Her approach speed must not invent a separate stepping rhythm.
		var source_clip := pace_source.animation if String(pace_source.animation).begins_with("walk_") else clip
		if pace_source.sprite_frames.has_animation(source_clip):
			var source_rate := pace_source.sprite_frames.get_animation_speed(source_clip) * absf(pace_source.speed_scale)
			speed_scale = source_rate / sprite_frames.get_animation_speed(clip)
	if animation != clip or not is_playing():
		play(clip)
