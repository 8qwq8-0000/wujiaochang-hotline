class_name EnemyBarrierSkill
extends Node2D

## Authored front-view cast; physics faces the player captured at cast start.
const COLLISION_LAYER := 256
const CAST_FRAMES := preload("res://assets/art/characters/enemies/shield_barrier_cast_v1/cast_frames.tres")
const DEPLOY_FRAME := 4
const DEPLOY_SECONDS := 0.4
var actor: EnemyController
var visual: AnimatedSprite2D
var barrier: Area2D
var cooldown := 0.0
var elapsed := 0.0
var casting := false
var deployed := false
var direction := Vector2.DOWN


func configure(owner_actor: EnemyController) -> void:
	actor = owner_actor
	visual = AnimatedSprite2D.new()
	visual.sprite_frames = CAST_FRAMES
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.centered = false
	visual.offset = Vector2(-256, -400)
	visual.position = Vector2(0, 10)
	visual.scale = Vector2.ONE * 0.24
	visual.visible = false
	add_child(visual)
	barrier = Area2D.new()
	barrier.collision_layer = 0
	barrier.collision_mask = 0
	barrier.monitoring = false
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(96, 8)
	shape.shape = rectangle
	barrier.add_child(shape)
	add_child(barrier)


func try_cast(target: Node2D) -> bool:
	if not actor.profile.barrier_enabled or cooldown > 0.0 or casting or not is_instance_valid(target):
		return false
	if actor.state in [EnemyController.State.WINDUP, EnemyController.State.STAGGERED, EnemyController.State.DEAD, EnemyController.State.SELF_DESTRUCT]:
		return false
	direction = actor.global_position.direction_to(target.global_position)
	if direction.is_zero_approx():
		direction = actor.facing
	actor.facing = direction
	actor.state = EnemyController.State.ATTACK
	casting = true
	deployed = false
	elapsed = 0.0
	cooldown = actor.profile.barrier_cooldown
	barrier.position = direction * 28.0
	barrier.rotation = direction.angle() - PI / 2.0
	actor.sprite.visible = false
	visual.visible = true
	visual.play(&"cast_barrier_down")
	return true


func tick(delta: float) -> bool:
	cooldown = maxf(0.0, cooldown - delta)
	if not casting:
		return false
	elapsed += delta
	# Physics owns activation and the matching visual pose in this same tick.
	# Animation playback continues natively, then holds the final shield pose.
	if elapsed >= DEPLOY_SECONDS and not deployed:
		deployed = true
		barrier.collision_layer = COLLISION_LAYER
		if visual.frame < DEPLOY_FRAME:
			visual.set_frame_and_progress(DEPLOY_FRAME, 0.0)
	if elapsed >= DEPLOY_SECONDS + actor.profile.barrier_duration:
		cancel()
		return false
	return true


func cancel() -> void:
	casting = false
	deployed = false
	if is_instance_valid(barrier):
		barrier.collision_layer = 0
	if is_instance_valid(visual):
		visual.stop()
		visual.visible = false
	if is_instance_valid(actor) and is_instance_valid(actor.sprite):
		actor.sprite.visible = true
