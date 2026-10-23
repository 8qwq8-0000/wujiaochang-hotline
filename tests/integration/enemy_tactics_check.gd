extends SceneTree

const ENEMY_SCENE := preload("res://scenes/actors/enemies/enemy.tscn")

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func _enemy(parent: Node, profile_path: String, position: Vector2, side: float) -> EnemyController:
	var enemy := ENEMY_SCENE.instantiate() as EnemyController
	enemy.profile = load(profile_path).duplicate()
	enemy.profile.patrol_enabled = false
	enemy.position = position
	enemy.initial_facing = Vector2.LEFT
	parent.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.tactical_brain.configure(enemy.profile.decision_interval, side)
	return enemy


func run() -> void:
	var room := load("res://scenes/levels/rooms/prototype_combat_room.tscn").instantiate() as Node2D
	root.add_child(room)
	current_scene = room
	await process_frame
	await physics_frame
	for spawned in get_nodes_in_group("enemies"):
		spawned.queue_free()
	await process_frame

	var player := CharacterBody2D.new()
	player.add_to_group("player")
	player.position = Vector2(100, 260)
	player.velocity = Vector2(80, 0)
	room.add_child(player)
	var parent := room.get_node("Enemies")

	var flank_left := _enemy(parent, "res://resources/enemies/melee_pressure.tres", Vector2(320, 220), -1.0)
	var flank_right := _enemy(parent, "res://resources/enemies/melee_pressure.tres", Vector2(320, 300), 1.0)
	flank_left._alert_to(player.global_position, false)
	flank_right._alert_to(player.global_position, false)
	flank_left._physics_process(0.2)
	flank_right._physics_process(0.2)
	check(flank_left.get_tactical_intent() == EnemyTacticalBrain.Intent.FLANK_LEFT, "supported melee chooses its stable left flank")
	check(flank_right.get_tactical_intent() == EnemyTacticalBrain.Intent.FLANK_RIGHT, "supported melee chooses its stable right flank")
	var left_destination: Vector2 = flank_left.get("_tactical_destination")
	var right_destination: Vector2 = flank_right.get("_tactical_destination")
	check(left_destination.x != INF and right_destination.x != INF, "both flank intentions resolve to reachable navigation points")
	check(left_destination.distance_to(right_destination) > 12.0, "paired melee enemies do not select the same approach point")

	var ranged := _enemy(parent, "res://resources/enemies/ranged_sightline.tres", Vector2(300, 260), -1.0)
	ranged.set("_attack_cooldown_remaining", 0.6)
	ranged._alert_to(player.global_position, false)
	ranged._physics_process(0.2)
	check(ranged.get_tactical_intent() == EnemyTacticalBrain.Intent.STRAFE_LEFT, "cooling ranged enemy strafes instead of standing still")
	var strafe_destination: Vector2 = ranged.get("_tactical_destination")
	check(strafe_destination.x != INF, "ranged strafe keeps a reachable destination with line of sight")
	# The old 100%-108% band strafed forever without entering firing range.
	for ratio in [1.001, 1.04, 1.08, 1.2]:
		for cooldown in [0.0, 0.6]:
			for side in [-1.0, 1.0]:
				ranged.tactical_brain.configure(ranged.profile.decision_interval, side)
				ranged.set("_attack_cooldown_remaining", cooldown)
				check(ranged._choose_tactical_intent(ranged.profile.attack_range * ratio, 0.2) == EnemyTacticalBrain.Intent.APPROACH, "ranged enemy closes distance outside firing range, ratio=%s cooldown=%s side=%s" % [ratio, cooldown, side])
	ranged.set("_attack_cooldown_remaining", 0.0)
	check(ranged._choose_tactical_intent(ranged.profile.attack_range, 0.0) == EnemyTacticalBrain.Intent.HOLD_AND_ATTACK, "entering firing range immediately opens the attack window")

	var heavy := _enemy(parent, "res://resources/enemies/heavy_anchor.tres", Vector2(330, 230), 1.0)
	heavy._alert_to(player.global_position, false)
	heavy._physics_process(0.25)
	check(heavy.get_tactical_intent() == EnemyTacticalBrain.Intent.INTERCEPT, "heavy enemy chooses predictive interception outside attack range")
	check(heavy._predicted_target_position().x > player.global_position.x, "heavy interception leads a visible moving target")

	room.queue_free()
	await process_frame
	print("Enemy tactics failures: ", failures)
	quit(0 if failures == 0 else 1)
