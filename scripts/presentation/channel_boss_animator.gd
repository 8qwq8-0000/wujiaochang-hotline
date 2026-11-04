class_name ChannelBossAnimator
extends AnimatedSprite2D

const FRAMES := preload("res://assets/art/characters/bosses/rooftop_whale_goddess/channel_returned_v1/frames.tres")
var moving := false
var hit_flash := 0.0


func _ready() -> void:
	sprite_frames = FRAMES
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = false
	offset = Vector2(-192, -470)
	scale = Vector2.ONE * 0.4
	animation_finished.connect(_on_animation_finished)
	play(&"idle")


func _process(delta: float) -> void:
	hit_flash = maxf(hit_flash - delta, 0)
	modulate = Color(1.3, 0.8, 0.7) if hit_flash > 0 else Color.WHITE


func play_cast(skill: StringName) -> void:
	speed_scale = 0.85 if skill == &"halo" else 1.0
	play(skill)
	set_frame_and_progress(0, 0)


func update_motion(is_moving: bool) -> void:
	moving = is_moving
	if animation in [&"idle", &"move"]:
		play(&"move" if moving else &"idle")


func flash_hit(_amount: int, _packet: DamagePacket) -> void:
	hit_flash = 0.12


func _on_animation_finished() -> void:
	speed_scale = 1.0
	play(&"move" if moving else &"idle")
