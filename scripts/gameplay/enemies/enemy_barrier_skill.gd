class_name EnemyBarrierSkill
extends Node2D

## Casting body and detached travelling barrier use separate native animations.
const COLLISION_LAYER := 256
const CAST_FRAMES := preload("res://assets/art/characters/enemies/shield_barrier_cast_v2/frames.tres")
const DEPLOY_SECONDS := 0.4
var actor: EnemyController
var visual: AnimatedSprite2D
var flight_visual: AnimatedSprite2D
var barrier: Area2D
var cooldown := 0.0
var elapsed := 0.0
var casting := false
var deployed := false
var direction := Vector2.DOWN
var cast_origin := Vector2.ZERO


func configure(owner_actor: EnemyController) -> void:
	actor = owner_actor
	cooldown = actor.profile.barrier_initial_cooldown
	visual = AnimatedSprite2D.new()
	visual.sprite_frames = CAST_FRAMES
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.centered = false
	visual.offset = Vector2(-192, -320)
	visual.position = Vector2(0, 10)
	visual.scale = Vector2.ONE * 0.24
	visual.visible = false
	add_child(visual)
	barrier = Area2D.new()
	add_child(barrier)
	barrier.top_level = true
	barrier.collision_layer = 0
	barrier.collision_mask = 0
	barrier.monitoring = false
	barrier.visible = false
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(96, 8)
	shape.shape = rectangle
	barrier.add_child(shape)
	flight_visual = AnimatedSprite2D.new()
	flight_visual.sprite_frames = CAST_FRAMES
	flight_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	barrier.add_child(flight_visual)


func try_cast(target: Node2D) -> bool:
	if not actor.profile.barrier_enabled or cooldown > 0.0 or casting or not is_instance_valid(target):
		return false
	if actor.state in [EnemyController.State.WINDUP, EnemyController.State.STAGGERED, EnemyController.State.DEAD, EnemyController.State.SELF_DESTRUCT]:
		return false
	var aim := actor.global_position.direction_to(target.global_position)
	if aim.is_zero_approx():
		aim = actor.facing
	var heading := actor.visuals.direction_name(aim)
	direction = {"down": Vector2.DOWN, "up": Vector2.UP, "left": Vector2.LEFT, "right": Vector2.RIGHT}[heading]
	actor.facing = direction
	actor.state = EnemyController.State.ATTACK
	casting = true
	deployed = false
	elapsed = 0.0
	cooldown = actor.profile.barrier_cooldown
	cast_origin = actor.global_position
	barrier.global_position = cast_origin + direction * 28.0
	barrier.rotation = direction.angle() - PI / 2.0
	flight_visual.rotation = -barrier.rotation
	flight_visual.scale = Vector2(0.25, 0.25)
	flight_visual.play("flight_" + heading)
	actor.sprite.visible = false
	visual.visible = true
	visual.play("cast_barrier_" + heading)
	return true


func tick(delta: float) -> bool:
	cooldown = maxf(0.0, cooldown - delta)
	if not casting:
		return false
	var previous := elapsed
	elapsed += delta
	if elapsed >= DEPLOY_SECONDS and not deployed:
		deployed = true
		barrier.collision_layer = COLLISION_LAYER
		barrier.visible = true
		# The flying shield is rendered separately from the recovering caster.
		visual.stop()
		visual.visible = false
		actor.sprite.visible = true
		actor.visuals.update_visual(0.0)
		if not _move_barrier(Vector2.ZERO):
			cancel()
			return false
	if deployed:
		var flight_delta := maxf(minf(elapsed, DEPLOY_SECONDS + actor.profile.barrier_duration) - maxf(previous, DEPLOY_SECONDS), 0.0)
		if not _move_barrier(direction * actor.profile.barrier_speed * flight_delta):
			cancel()
			return false
	if elapsed >= DEPLOY_SECONDS + actor.profile.barrier_duration:
		cancel()
		return false
	return true


func _move_barrier(motion: Vector2) -> bool:
	# Sweep the full width so the flying shield cannot cross thin walls.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = (barrier.get_child(0) as CollisionShape2D).shape
	query.transform = barrier.global_transform
	query.collision_mask = 1
	query.collide_with_areas = false
	var space := get_world_2d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return false
	if motion.is_zero_approx():
		return true
	query.motion = motion
	var fractions := space.cast_motion(query)
	barrier.global_position += motion * fractions[0]
	return fractions[0] >= 1.0


func cancel() -> void:
	casting = false
	deployed = false
	if is_instance_valid(barrier):
		barrier.collision_layer = 0
		barrier.visible = false
	if is_instance_valid(visual):
		visual.stop()
		visual.visible = false
	if is_instance_valid(actor) and is_instance_valid(actor.sprite):
		actor.sprite.visible = true
