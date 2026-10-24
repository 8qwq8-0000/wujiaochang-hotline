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
	check(camp.ui.get_node("PlayerDamageFeedback").is_visible_in_tree(), "training keeps screen damage feedback visible while formal HUD is hidden")
	check(camp.robots.size() == 3, "three fan robots")
	check(camp.ui.get_node("PlayerHealthBar").value == camp.player.health.current_health, "fixed player health bar shows starting health")
	camp.player.health.set_current_health(2)
	check(camp.ui.get_node("PlayerHealthBar").value == 2 and "2/" in camp.ui.get_node("PlayerHealthLabel").text, "player health bar and label update after damage")
	camp._panel.find_child("HealButton", true, false).pressed.emit()
	check(camp.player.health.current_health == camp.player.health.max_health, "heal button restores player to full health")
	camp.player.health.set_current_health(1)
	var heal_key := InputEventKey.new()
	heal_key.physical_keycode = KEY_H
	heal_key.pressed = true
	root.push_input(heal_key, true)
	await process_frame
	check(camp.player.health.current_health == camp.player.health.max_health, "H key restores health without resetting training")
	for robot in camp.robots:
		check(robot.health.current_health == 3 and robot.health.max_health == 3, "robot defaults to three HP")
		check(robot.stationary_test_target and robot.position.y < camp.CENTER.y and is_equal_approx(robot.position.distance_to(camp.CENTER), 112), "robot stationary on forward fan arc")
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
	camp.sliders.interval.value = 1.3
	camp.sliders.health.value = 5
	await process_frame
	check(camp.robot_health == 5 and camp.robots[0].health.max_health == 5, "health slider resets robots")
	check(is_equal_approx(camp.shot_interval, 1.3) and not camp.sliders.has("speed"), "interval slider applies and speed slider removed")
	camp._fire_next()
	var bullets: Array[Node] = []
	for node in camp.get_children():
		if node is CombatProjectile and not node.is_queued_for_deletion():
			bullets.append(node)
	check(bullets.size() == 1 and is_equal_approx(bullets[0].speed, 260), "new shot uses fixed speed and old bullets removed")
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
	# Walk between both physical zones; only the active zone attacks.
	camp._clear_shots()
	check(is_instance_valid(camp.melee_robot) and camp.melee_robot.profile.role == EnemyProfile.Role.MELEE_PRESSURE, "second zone contains real melee enemy")
	check(camp.melee_robot.get_node("TrainingHealthLabel").text == "近战 5/5", "melee health label shows current and maximum")
	camp.melee_robot.health.set_current_health(4)
	check(camp.melee_robot.get_node("TrainingHealthBar").value == 4 and "4/5" in camp.melee_robot.get_node("TrainingHealthLabel").text, "damage updates melee bar and health text")
	check(camp.robots[0].has_node("TrainingHealthBar"), "ranged targets also show health bars")
	check(camp.melee_robot.health.max_health == 5, "health slider also configures melee target")
	camp.player.position = Vector2(610, 240)
	await physics_frame
	camp.player.move_and_collide(Vector2(60, 0))
	check(camp.player.position.x > 650, "player physically crosses connecting doorway")
	camp.player.position = camp.MELEE_CENTER
	camp._physics_process(0.01)
	check(camp._melee_zone and camp.get_node("Camera2D").position.x > 320, "walking into second zone switches training and camera")
	var fixed_position: Vector2 = camp.melee_robot.position
	camp.melee_robot.apply_knockback(Vector2(300, 0))
	camp._physics_process(0.2)
	check(camp.melee_robot.position == fixed_position and camp.melee_robot.velocity == Vector2.ZERO, "melee target stays fixed outside attack range even after knockback")
	var last_shooter: int = camp.last_fired_index
	var melee: EnemyController = camp.melee_robot
	melee.position = camp.player.position + Vector2.RIGHT * 40
	melee._target = camp.player
	melee.facing = Vector2.LEFT
	melee._attack_cooldown_remaining = 0.0
	await physics_frame
	camp._physics_process(0.01)
	check(melee.state == EnemyController.State.WINDUP, "real melee AI telegraphs before striking")
	camp._process(0.0)
	check("即将挥击" in camp._turn.text, "melee windup displays timing prompt")
	camp._physics_process(0.15)
	camp.player.guard.reset_to_idle()
	camp.player.hurt_box.clear_invulnerability()
	camp.player.guard.begin_guard(Vector2.RIGHT)
	camp.player.guard.advance_timing(0.16)
	var melee_feedback := main.get_node("VFXManager/PerfectParryFeedback") as PerfectParryFeedback
	melee_feedback.clear()
	var popups_before: int = melee_feedback.popups_shown
	var enemy_health_before: int = melee.health.current_health
	var perfect_before: int = camp.perfects
	var health_before: int = camp.player.health.current_health
	camp._physics_process(0.16)
	check(camp.perfects == perfect_before + 1 and camp.player.health.current_health == health_before, "actual melee impact is perfectly parried without damage")
	check(melee.position == camp.player.position + Vector2.RIGHT * 40, "melee target stays fixed while winding up and parrying")
	check(melee.state == EnemyController.State.STAGGERED and melee._stagger_remaining >= 0.8, "perfect melee parry stuns actual attacker for at least 0.8 seconds")
	check(melee.health.current_health == enemy_health_before - 1, "perfect melee parry deals one counter damage")
	check(melee_feedback.popups_shown == popups_before + 1 and melee_feedback.sprite.visible, "single melee perfect immediately shows PERFECT")
	check(camp.last_fired_index == last_shooter, "ranged scheduler stays paused in melee zone")
	camp._physics_process(0.9)
	melee._attack_cooldown_remaining = 0.0
	camp.player.guard.reset_to_idle()
	camp.player.hurt_box.clear_invulnerability()
	camp._physics_process(0.01)
	check(melee.state == EnemyController.State.WINDUP, "fixed enemy begins next attack after parry stagger")
	camp._physics_process(0.31)
	check(melee.health.current_health == enemy_health_before - 1, "ordinary unblocked hit does not counter damage attacker")
	check(camp.player.health.current_health == health_before - 1, "unblocked real melee hit damages player at visible close range")
	check(camp.ui.get_node("PlayerDamageFeedback")._effects.any(func(effect: Dictionary) -> bool: return effect.kind == PlayerDamageFeedbackLayer.Kind.DAMAGE), "real melee damage triggers visible training screen feedback")
	check(main.get_node("VFXManager")._active_impacts.any(func(effect: Node2D) -> bool: return effect.global_position.distance_to(camp.player.global_position) < 1.0), "real training damage spawns restored impact particles at player")
	check(camp.player.visuals._flash_material.get_shader_parameter(&"flash_amount") > 0.99, "real damage triggers restored hit shader flash")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/parry_training_hurt_synced.png")
	camp.restore_player_health()
	camp.player.position = melee.position + Vector2.LEFT * 56
	melee._attack_cooldown_remaining = 0.0
	camp._physics_process(0.01)
	check(melee.state == EnemyController.State.IDLE, "outside displayed circle enemy waits without moving")
	camp.player.position = camp.CENTER
	camp._physics_process(0.01)
	check(not camp._melee_zone and melee.position == camp.MELEE_CENTER + Vector2(64, 0), "leaving resets melee opponent inside its zone")
	camp.player.guard.reset_to_idle()
	camp.player.guard.begin_guard(Vector2.RIGHT)
	camp.player.guard.advance_timing(0.019)
	check(camp.player.guard.state == GuardComponent.State.STARTUP, "startup still lasts until 20 ms")
	camp.player.guard.advance_timing(0.002)
	check(camp.player.guard.state == GuardComponent.State.PERFECT, "perfect window starts at 20 ms")
	camp.player.guard.advance_timing(0.198)
	check(camp.player.guard.state == GuardComponent.State.PERFECT, "late parry remains perfect through 219 ms")
	camp.player.guard.advance_timing(0.002)
	check(camp.player.guard.state == GuardComponent.State.NORMAL, "perfect window ends after 220 ms")
	var feedback := main.get_node("VFXManager/PerfectParryFeedback") as PerfectParryFeedback
	feedback.clear()
	feedback.popups_shown = 0
	feedback.set_process(false)
	check(hit(camp.player, 0.061).reflected, "actual damage resolver reflects perfect hit")
	check(feedback.combo_count == 1 and feedback.sprite.visible and feedback.popups_shown == 1, "first perfect immediately shows popup")
	hit(camp.player, 0.061)
	check(feedback.popups_shown == 2 and feedback.sprite.visible, "second perfect replays purple popup")
	feedback._process(0.7)
	hit(camp.player, 0.061)
	check(feedback.popups_shown == 3 and feedback.sprite.visible, "third consecutive perfect replays popup after previous fade")
	hit(camp.player, 0.061)
	check(feedback.popups_shown == 4 and is_zero_approx(feedback._elapsed), "fourth consecutive perfect restarts popup animation")
	hit(camp.player, 0.23)
	check(feedback.combo_count == 0, "normal block breaks chain")
	hit(camp.player, 0.061)
	check(feedback.popups_shown == 5, "first perfect after normal block immediately triggers again")
	hit(camp.player, 0.061)
	check(feedback.popups_shown == 6, "second perfect after normal block triggers again")
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
	check(camp.robot_health == 5 and camp.robots[0].health.current_health == 5 and not camp.sliders.has("speed"), "R preserves selected settings without restoring speed slider")
	check(not feedback.sprite.visible and feedback.combo_count == 0, "scene restart clears popup")
	check(store.get_profile() == saved, "training and reset preserve warehouse save")
	previous = camp.get_instance_id()
	camp.player.health.set_current_health(0)
	root.push_input(heal_key, true)
	camp = await wait_scene(main, TRAINING, previous)
	check(camp != null, "H reloads training safely when player is already dead")
	if camp == null:
		quit(1)
		return
	camp.set_physics_process(false)
	check(camp.player.health.current_health == camp.player.health.max_health and camp.robot_health == 5, "H after death restores health and preserves training settings")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		camp.player.set_physics_process(false)
		camp.player.guard.set_physics_process(false)
		hit(camp.player, 0.061)
		hit(camp.player, 0.061)
		feedback._process(0.1)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/parry_training_ranged.png")
		camp.player.position = camp.MELEE_CENTER
		camp._update_training_zone()
		camp._process(0.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/parry_training_melee.png")
	# Counter damage follows normal health/death rules and only perfects trigger it.
	camp.player.set_physics_process(false)
	camp.player.guard.set_physics_process(false)
	camp.player.set_input_enabled(false)
	melee = camp.melee_robot
	camp.player.position = melee.position + Vector2.LEFT * 40
	melee._target = camp.player
	melee._attack_direction = Vector2.LEFT
	melee.health.set_current_health(2)
	await physics_frame
	camp.player.hurt_box.clear_invulnerability()
	camp.player.guard.reset_to_idle()
	camp.player.guard.begin_guard(Vector2.RIGHT)
	camp.player.guard.advance_timing(0.23)
	var popup_count: int = feedback.popups_shown
	melee.perform_attack()
	check(melee.health.current_health == 2 and feedback.popups_shown == popup_count, "normal melee block neither counters nor triggers PERFECT")
	melee.health.set_current_health(1)
	camp.player.hurt_box.clear_invulnerability()
	camp.player.guard.reset_to_idle()
	camp.player.guard.begin_guard(Vector2.RIGHT)
	camp.player.guard.advance_timing(0.061)
	melee.perform_attack()
	check(melee.health.is_dead() and melee.state == EnemyController.State.DEAD, "lethal counter defeats enemy without replacing death with stun")
	check(feedback.popups_shown == popup_count + 1, "lethal melee parry also shows PERFECT")
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
