class_name DeathBloodSpray
extends AnimatedSprite2D

signal settled
var _finished := false

const DIRECTIONS := 16
const FRAME_COUNT := 14
const CELL_SIZE := 192
const ANCHOR := Vector2(96, 96)
const FPS := 45.0
static var _shared_frames: SpriteFrames
var direction_index := 0

static func sector_for(direction: Vector2) -> int:
	if direction.is_zero_approx():
		return 0
	return posmod(roundi(direction.angle() * DIRECTIONS / TAU), DIRECTIONS)

static func shared_frames() -> SpriteFrames:
	if _shared_frames != null:
		return _shared_frames
	_shared_frames = SpriteFrames.new()
	_shared_frames.remove_animation(&"default")
	for sector in DIRECTIONS:
		var clip := StringName("spray_%02d" % sector)
		_shared_frames.add_animation(clip)
		_shared_frames.set_animation_loop(clip, false)
		_shared_frames.set_animation_speed(clip, FPS)
		var sheet := load("res://assets/art/effects/death_blood_spray_v1/spray_%02d.png" % sector) as Texture2D
		for index in FRAME_COUNT:
			var frame_texture := AtlasTexture.new()
			frame_texture.atlas = sheet
			frame_texture.region = Rect2(index * CELL_SIZE, 0, CELL_SIZE, CELL_SIZE)
			_shared_frames.add_frame(clip, frame_texture)
	return _shared_frames

func start(world_position: Vector2, direction: Vector2, opacity: float = 1.0) -> void:
	add_to_group("death_blood_sprays")
	sprite_frames = shared_frames()
	direction_index = sector_for(direction)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = false
	offset = -ANCHOR
	scale = Vector2.ONE * 0.75
	global_position = world_position + Vector2(0, -14)
	z_index = 2
	modulate.a = clampf(opacity, 0, 1)
	animation_finished.connect(finish, CONNECT_ONE_SHOT)
	play(StringName("spray_%02d" % direction_index))

func finish() -> void:
	if _finished:
		return
	_finished = true
	stop()
	settled.emit()
	queue_free()
