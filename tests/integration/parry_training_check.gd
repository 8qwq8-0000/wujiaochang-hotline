extends SceneTree

const TEST_PATH := "res://.godot/parry-training-check.json"
const TRAINING := "res://scenes/debug/parry_training.tscn"
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func wait_scene(main: Node, path: String, previous: int = 0) -> Node:
	for frame in 600:
		await process_frame
		var container := main.get_node("SceneContainer")
		if container.get_child_count() > 0 and not main.get_node("SceneFlow").get("_is_loading"):
			var scene := container.get_child(0)
			if scene.scene_file_path == path and scene.get_instance_id() != previous:
				return scene
	return null

func hit(player: PlayerController, timing: float) -> DamageResult:
	player.guard.reset_to_idle()
	player.hurt_box.clear_invulnerability()
	player.guard.begin_guard(Vector2.RIGHT)
	player.guard.advance_timing(timing)
	var packet := DamagePacket.new()
	packet.source_faction = CombatFaction.Id.ENEMY
	packet.source_position = player.global_position + Vector2.RIGHT * 40
	packet.travel_direction = Vector2.LEFT
	packet.is_projectile = true
	packet.reflectable = true
	return player.hurt_box.receive_hit(packet)

func run() -> void:
	var store := root.get_node("WarehouseStore")
	store.save_path = TEST_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	var main := load("res://scenes/bootstrap/warehouse_main.tscn").instantiate() as Node
	main.get_node("SceneFlow").fade_duration = 0.0
	root.add_child(main)
	current_scene = main
	var warehouse := await wait_scene(main, "res://scenes/levels/base/warehouse.tscn")
	check(warehouse != null, "starts in warehouse")
	if warehouse == null:
		quit(1)
		return
	var saved: Dictionary = store.get_profile()
	warehouse.player.set_physics_process(false)
	warehouse.player.position = Vector2(270, 100)
	for frame in 4:
		await physics_frame
	var door: Node = warehouse.get_node("ParryTraining")
	check(door.can_interact(warehouse.player), "training doorway is reachable")
	check(warehouse.player.interactor.get_best_target(warehouse.player) == door, "E detector selects training doorway")
	check(warehouse.enter_parry_training(), "training doorway accepts transition")
	var camp := await wait_scene(main, TRAINING)
	check(camp != null, "training scene loads")
	if camp == null:
		quit(1)
		return
	check(not root.get_node("RunManager").persistent_run, "training has no persistent run")
	check(not main.get_node("CombatHUD").visible, "formal combat HUD hidden")
	check(camp.robots.size() == 3, "three ring robots")
	for robot in camp.robots:
		check(robot.health.current_health == 3 and robot.health.max_health == 3, "robot defaults to three HP")
		check(robot.stationary_test_target and is_equal_approx(robot.position.distance_to(camp.CENTER), 112), "robot stationary on ring")
	check(is_equal_approx(camp.shot_interval, 0.9), "default interval 0.9 seconds")
	# Advance the real scheduler without allowing player damage to interrupt the sequence.
	camp.set_physics_process(false)
	camp.player.set_physics_process(false)
	camp.player.guard.set_physics_process(false)
	camp._shot_remaining = 0.9
	camp._physics_process(0.89)
	check(camp.last_fired_index == -1, "scheduler waits for interval")
	camp._physics_process(0.02)
	check(camp.last_fired_index == 0, "first robot fires")
	camp._physics_process(0.9)
	check(camp.last_fired_index == 1, "second robot fires next")
	camp._physics_process(0.9)
	check(camp.last_fired_index == 2, "third robot fires next")
	camp._physics_process(0.9)
	check(camp.last_fired_index == 0, "order loops")
	camp._editing = true
	camp._physics_process(5)
	check(camp.last_fired_index == 0, "dragging pauses shots")
	camp._editing = false
	camp.sliders.speed.value = 400
	camp.sliders.interval.value = 1.3
	camp.sliders.health.value = 5
	await process_frame
	check(camp.robot_health == 5 and camp.robots[0].health.max_health == 5, "health slider resets robots")
	check(is_equal_approx(camp.shot_interval, 1.3) and is_equal_approx(camp.bullet_speed, 400), "speed and interval sliders apply")
	camp._fire_next()
	var bullets: Array[Node] = []
	for node in camp.get_children():
		if node is CombatProjectile and not node.is_queued_for_deletion():
			bullets.append(node)
	check(bullets.size() == 1 and is_equal_approx(bullets[0].speed, 400), "new shot uses slider speed and old bullets removed")
	camp._clear_shots()
	camp.robots[1].health.set_current_health(0)
	camp._fire_next()
	check(camp.last_fired_index == 2, "dead robot skipped")
	camp._clear_shots()
	camp._reset_robots()
	await physics_frame
	for index in 3:
		var robot: EnemyController = camp.robots[index]
		camp.player.guard.reset_to_idle()
		camp.player.hurt_box.clear_invulnerability()
		camp.player.guard.begin_guard(camp.player.global_position.direction_to(robot.global_position))
		camp.player.guard.advance_timing(0.061)
		camp._fire_next()
		for frame in 180:
			await physics_frame
			if robot.health.current_health < 5 or camp.player.health.current_health < camp.player.health.max_health:
				break
		check(robot.health.current_health == 4, "real robot %d projectile reflects back and damages shooter" % index)
		camp._clear_shots()
	var feedback := main.get_node("VFXManager/PerfectParryFeedback") as PerfectParryFeedback
	feedback.clear()
	feedback.popups_shown = 0
	feedback.set_process(false)
	check(hit(camp.player, 0.061).reflected, "actual damage resolver reflects perfect hit")
	check(feedback.combo_count == 1 and not feedback.sprite.visible, "first perfect does not show popup")
	hit(camp.player, 0.061)
	check(feedback.popups_shown == 1 and feedback.sprite.visible, "second perfect shows approved purple popup")
	feedback._process(0.7)
	hit(camp.player, 0.061)
	check(feedback.popups_shown == 2 and feedback.sprite.visible, "third consecutive perfect replays popup after previous fade")
	hit(camp.player, 0.061)
	check(feedback.popups_shown == 3 and is_zero_approx(feedback._elapsed), "fourth consecutive perfect restarts popup animation")
	hit(camp.player, 0.19)
	check(feedback.combo_count == 0, "normal block breaks chain")
	hit(camp.player, 0.061)
	check(feedback.popups_shown == 3, "first perfect after broken chain does not trigger")
	hit(camp.player, 0.061)
	check(feedback.popups_shown == 4, "second perfect after broken chain triggers again")
	feedback.clear()
	hit(camp.player, 0.061)
	feedback._process(1.21)
	check(feedback.combo_count == 0 and not feedback.sprite.visible, "timeout clears chain and fades popup")
	hit(camp.player, 0.061)
	hit(camp.player, 0.0)
	check(feedback.combo_count == 0, "damage breaks chain")
	camp.sliders.interval.value = 0.9
	check(feedback.combo_count == 0, "parameter changes clear feedback chain")
	camp.set_physics_process(true)
	paused = true
	var frozen: float = camp._shot_remaining
	await create_timer(0.06, true).timeout
	check(is_equal_approx(camp._shot_remaining, frozen), "pause freezes training cadence")
	paused = false
	camp.set_physics_process(false)
	camp.player.health.set_current_health(0)
	check(not root.get_node("RunManager").persistent_run and store.get_profile() == saved, "training death preserves formal save")
	var previous := camp.get_instance_id()
	var restart := InputEventAction.new()
	restart.action = &"restart_room"
	restart.pressed = true
	root.push_input(restart, true)
	camp = await wait_scene(main, TRAINING, previous)
	check(camp != null, "actual R input reloads camp instead of combat harness")
	if camp == null:
		quit(1)
		return
	camp.set_physics_process(false)
	check(camp.player.health.current_health == camp.player.health.max_health and camp.perfects == 0, "R restores player and counters")
	check(camp.robot_health == 5 and camp.robots[0].health.current_health == 5 and is_equal_approx(camp.bullet_speed, 400), "R preserves selected settings")
	check(not feedback.sprite.visible and feedback.combo_count == 0, "scene restart clears popup")
	check(store.get_profile() == saved, "training and reset preserve warehouse save")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		camp.player.set_physics_process(false)
		camp.player.guard.set_physics_process(false)
		hit(camp.player, 0.061)
		hit(camp.player, 0.061)
		feedback._process(0.1)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/art/validation/parry_training.png")
	paused = true
	check(camp.return_to_warehouse(), "return works even when paused")
	warehouse = await wait_scene(main, "res://scenes/levels/base/warehouse.tscn")
	check(warehouse != null and not paused, "returns to warehouse unpaused")
	check(main.get_node("CombatHUD").visible, "formal HUD restored")
	check(store.get_profile() == saved, "return preserves warehouse save")
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("Parry training checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
