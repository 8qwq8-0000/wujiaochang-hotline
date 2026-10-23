class_name DeathBurstEffect
extends Node2D

signal finished(effect: DeathBurstEffect)

var _sprite := Sprite2D.new()
var _shards: Array[Dictionary] = []
var _elapsed := 0.0
var _hold_seconds := 0.05
var _duration := 0.42
var _push_direction := Vector2.RIGHT
var _heavy := false


func _ready() -> void:
	add_child(_sprite)
	set_process(false)
	hide()


func play(enemy: EnemyController, weapon_id: StringName, clarity_scale: float) -> void:
	if not is_instance_valid(enemy) or not is_instance_valid(enemy.sprite):
		return
	global_position = enemy.global_position
	_heavy = enemy.profile != null and enemy.profile.role == EnemyProfile.Role.HEAVY_ANCHOR
	_hold_seconds = 0.08 if _heavy else 0.045
	_duration = 0.56 if _heavy else 0.38
	_push_direction = enemy.death_impact_direction
	if _push_direction.is_zero_approx():
		_push_direction = enemy.death_motion_direction
	if _push_direction.is_zero_approx():
		_push_direction = Vector2.RIGHT
	_push_direction = _push_direction.normalized()
	var source := enemy.sprite
	_sprite.texture = source.sprite_frames.get_frame_texture(source.animation, source.frame)
	_sprite.centered = source.centered
	_sprite.offset = source.offset
	_sprite.position = source.position
	_sprite.scale = source.scale
	_sprite.flip_h = source.flip_h
	_sprite.modulate = Color(1.35, 1.25, 1.15, 0.92 * clarity_scale)
	_shards.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("death:%d:%d:%s" % [roundi(global_position.x), roundi(global_position.y), weapon_id])
	var palette := _weapon_palette(weapon_id)
	var shard_count := int((11 if _heavy else 7) * clarity_scale)
	for index in maxi(shard_count, 3):
		var direction := _push_direction.rotated(rng.randf_range(-1.35, 1.35))
		_shards.append({
			"position": Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-14.0, 6.0)),
			"velocity": direction * rng.randf_range(35.0, 88.0) + Vector2.UP * rng.randf_range(8.0, 36.0),
			"size": rng.randf_range(1.5, 3.2) * (1.5 if _heavy else 1.0),
			"color": palette[index % palette.size()],
		})
	_elapsed = 0.0
	show()
	set_process(true)
	queue_redraw()


func stop() -> void:
	set_process(false)
	hide()
	_sprite.texture = null
	_shards.clear()
	finished.emit(self)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed <= _hold_seconds:
		queue_redraw()
		return
	var travel_time := _elapsed - _hold_seconds
	_sprite.position += _push_direction * (19.0 if _heavy else 28.0) * delta
	_sprite.scale = _sprite.scale.lerp(Vector2(_sprite.scale.x * 1.03, _sprite.scale.y * 0.94), clampf(delta * 4.0, 0.0, 1.0))
	_sprite.modulate.a = clampf(1.0 - travel_time / maxf(_duration - _hold_seconds, 0.01), 0.0, 1.0)
	for shard in _shards:
		shard.position += shard.velocity * delta
		shard.velocity += Vector2.DOWN * (54.0 if _heavy else 36.0) * delta
	queue_redraw()
	if _elapsed >= _duration:
		stop()


func _draw() -> void:
	if _elapsed <= _hold_seconds:
		return
	var fade := clampf(1.0 - (_elapsed - _hold_seconds) / maxf(_duration - _hold_seconds, 0.01), 0.0, 1.0)
	for shard in _shards:
		var point: Vector2 = shard.position
		var velocity: Vector2 = shard.velocity.normalized()
		var size: float = shard.size
		draw_line(point - velocity * size, point + velocity * size, Color(shard.color, fade), maxf(1.0, size * 0.65))


func _weapon_palette(weapon_id: StringName) -> Array[Color]:
	match weapon_id:
		&"rail_cannon":
			return [Color("9cf7ff"), Color.WHITE, Color("4798ff")]
		&"thermal_pulse":
			return [Color("ff4f32"), Color("ffad42"), Color("73302a")]
		&"scattergun":
			return [Color("ffad45"), Color("e6ddd1"), Color("8f6d62")]
		_:
			return [Color("f0e9dc"), Color("e9b75b"), Color("7e8a9a")]
