class_name ChannelTaskRoom
extends Node2D

# Shared hidden-room geometry and enemy tracking; the former floor 2/3 tasks
# and their signature/isolation terminals have been removed.
signal room_cleared
const SIZE := Vector2(640, 360)
var cleared := false
var started := false
var enemies: Array[EnemyController] = []
var terminal: ChannelTerminal
var terminal_action: Callable


func contains_world_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, SIZE).has_point(to_local(point))


func _add_solid(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = 1
	body.collision_mask = 0
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	body.add_child(collider)
	var visual := Polygon2D.new()
	visual.polygon = CombatLayoutData._outline(Rect2(-rect.size * 0.5, rect.size))
	visual.color = Color("30424c")
	visual.visible = rect.size.x >= 600 or rect.size.y >= 300
	body.add_child(visual)
	add_child(body)


func start() -> void:
	if started:
		return
	started = true
	_spawn_wave()


func _spawn_wave() -> void:
	pass


func living_enemies() -> Array[EnemyController]:
	var result: Array[EnemyController] = []
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.state != EnemyController.State.DEAD:
			result.append(enemy)
	return result


