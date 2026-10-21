extends SceneTree

const ENEMY_SCENE := preload("res://scenes/actors/enemies/enemy.tscn")
const MELEE_PROFILE := preload("res://resources/enemies/melee_pressure.tres")

var failures := 0
var blocking_rects: Array[Rect2] = []


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func _inside_blocking_geometry(position: Vector2) -> bool:
	if position.x < 19.0 or position.x > CombatRoom.ROOM_SIZE.x - 19.0 or position.y < 19.0 or position.y > CombatRoom.ROOM_SIZE.y - 19.0:
		return true
	# Check the authored collider interiors. Touching the navigation polygon's
	# baked 12 px clearance is not equivalent to passing through a wall.
	return blocking_rects.any(func(rect: Rect2) -> bool: return rect.has_point(position))


func run() -> void:
	var room := load("res://scenes/levels/rooms/prototype_combat_room.tscn").instantiate() as Node2D
	root.add_child(room)
	current_scene = room
	await process_frame
	await physics_frame
	# CombatRoom expands/repositions the authored shell at runtime. Query the
	# real collider transforms instead of testing obsolete 640x360 coordinates.
	for path in ["CoverA/CollisionShape2D", "CoverB/CollisionShape2D"]:
		var collider := room.get_node(path) as CollisionShape2D
		var shape := collider.shape as RectangleShape2D
		blocking_rects.append(collider.global_transform * Rect2(-shape.size * 0.5, shape.size))
	for spawned in get_nodes_in_group("enemies"):
		spawned.queue_free()
	await process_frame

	var player := Node2D.new()
	player.add_to_group("player")
	player.position = Vector2(100, 112)
	room.add_child(player)
	var parent := room.get_node("Enemies")
	var enemies: Array[EnemyController] = []
	for index in 16:
		var enemy := ENEMY_SCENE.instantiate() as EnemyController
		var profile := MELEE_PROFILE.duplicate() as EnemyProfile
		profile.patrol_enabled = false
		profile.awareness_range = 600.0
		profile.vision_angle_degrees = 180.0
		profile.attack_range = 12.0
		enemy.profile = profile
		enemy.position = Vector2(430 + (index % 4) * 14, 84 + (index / 4) * 14)
		enemy.initial_facing = Vector2.LEFT
		parent.add_child(enemy)
		enemy._alert_to(player.global_position, false)
		enemies.append(enemy)

	await physics_frame
	await physics_frame
	var overlap_streaks: Dictionary = {}
	var longest_overlap := 0
	var entered_wall := false
	var first_wall_position := Vector2(INF, INF)
	var made_progress := false
	for frame in 180:
		await physics_frame
		for enemy in enemies:
			if _inside_blocking_geometry(enemy.global_position) and not entered_wall:
				entered_wall = true
				first_wall_position = enemy.global_position
			made_progress = made_progress or enemy.global_position.x < 390.0
		for first in enemies.size():
			for second in range(first + 1, enemies.size()):
				var key := Vector2i(first, second)
				var streak := int(overlap_streaks.get(key, 0))
				streak = streak + 1 if enemies[first].global_position.distance_to(enemies[second].global_position) < 4.0 else 0
				overlap_streaks[key] = streak
				longest_overlap = maxi(longest_overlap, streak)

	check(made_progress, "16 enemies advance toward the target")
	check(not entered_wall, "navigation and recovery never move an enemy through arena walls or cover; first invalid position: %s" % first_wall_position)
	check(longest_overlap < 30, "no enemy pair remains fully overlapped for 0.5 seconds")
	check(enemies.all(func(enemy: EnemyController) -> bool: return enemy.navigation_agent.avoidance_enabled), "all 16 enemies keep soft avoidance enabled")
	room.queue_free()
	await process_frame
	print("Enemy navigation failures: ", failures)
	quit(0 if failures == 0 else 1)
