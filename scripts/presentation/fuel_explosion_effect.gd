class_name FuelExplosionEffect
extends Node2D

## Authored animation only; FuelPatch owns all damage and burning timers.
const DURATION := 0.85
const SHEET := "res://assets/art/effects/bomb/explosion_sheet_v1.png"
var elapsed := 0.0
var radius := 96.0

func _ready() -> void:
	z_index = 5
	var source := load(SHEET) as Texture2D
	var cell := source.get_size() / Vector2(4, 2)
	var frames := SpriteFrames.new()
	frames.add_animation("explode")
	frames.set_animation_loop("explode", false)
	frames.set_animation_speed("explode", 8.0 / DURATION)
	for index in 8:
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = Rect2(Vector2(index % 4, index / 4) * cell, cell)
		frames.add_frame("explode", atlas)
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AuthoredExplosion"
	sprite.sprite_frames = frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	var poses := [0.45, 0.68, 0.9, 1.0, 0.95, 0.9, 0.85, 0.75]
	var update_pose := func() -> void:
		var factor: float = poses[sprite.frame]
		sprite.scale = Vector2.ONE * 176.0 / cell.x * factor
		sprite.position.y = -80 * factor
	sprite.frame_changed.connect(update_pose)
	update_pose.call()
	sprite.play("explode")

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var progress := clampf(elapsed / DURATION, 0, 1)
	var expansion := 1.0 - pow(1.0 - progress, 3)
	draw_arc(Vector2.ZERO, radius * expansion, 0, TAU, 48, Color(1, 0.6, 0.2, 0.3 * (1.0 - progress)), 1)
