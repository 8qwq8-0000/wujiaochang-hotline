extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame in 3:
		await physics_frame
	await process_frame

func freeze_enemies() -> void:
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)

func clear_active() -> void:
	var enemies := get_nodes_in_group("enemies")
	for enemy in enemies:
		enemy.health.apply_damage(enemy.health.max_health, DamagePacket.new())
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.state == EnemyController.State.SELF_DESTRUCT:
			enemy._physics_process(enemy.profile.self_destruct_delay + 0.01)
	await settle()

func walk_right(player: PlayerController, frames: int) -> void:
	for frame in frames:
		await physics_frame
		player.velocity = Vector2(180, 0)
		player.move_and_slide()
	player.velocity = Vector2.ZERO
	await settle()

func run_checks() -> void:
	var main: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	main.get_node("SceneFlow").fade_duration = 0
	root.add_child(main)
	current_scene = main
	for frame in 600:
		await process_frame
		if get_nodes_in_group("enemies").size() == 3 and not main.get_node("SceneFlow").get("_is_loading"):
			break
	var player := get_first_node_in_group("player") as PlayerController
	check(player != null, "main loads a player")
	if player == null:
		quit(1)
		return
	player.set_physics_process(false)
	player.heat.set_physics_process(false)
	freeze_enemies()
	var assembler := main.find_child("FloorAssembler", true, false) as FloorAssembler
	var first: CombatRoom = assembler.generated_rooms[0]
	var second: CombatRoom = assembler.generated_rooms[1]
	var run := root.get_node("RunManager")
	var ui := main.get_node("ExtractionFlow")
	var hud := main.find_child("CombatHUD", true, false)
	check(assembler.generated_rooms.size() == 2 and assembler.passages.size() == 1, "one floor contains two connected areas")
	check(first.active and not second.active and not second.spawner._spawned, "only first area is active before entry")
	check(run.mandatory_enemies_remaining == 6 and get_nodes_in_group("enemies").size() == 3, "pending area contributes to floor objectives without spawning early")
	for room in [first, second]:
		check(room.find_children("*", "PowerBox", true, false).size() == 1, "each area has one power box")
		check(room.find_children("*", "FuelBarrel", true, false).size() == 1, "each area has one bomb box")
		check(room.find_children("*", "AutomaticDoor", true, false).is_empty(), "formal areas have no automatic doors")
	player.global_position = first.to_global(Vector2(600,180))
	await settle()
	await walk_right(player, 40)
	check(player.global_position.x < second.global_position.x and not second.active, "real collision blocks passage until first clear")
	var box := first.find_child("PowerBox", true, false) as PowerBox
	player.global_position = box.global_position + Vector2(0,-35)
	await settle()
	box.interact(player)
	var buffs := player.get_node("RoomBuffComponent") as RoomBuffComponent
	check(not buffs.active_buff.is_empty(), "first area grants its own power buff")
	await clear_active()
	check(first.cleared and not second.cleared and assembler._rooms_remaining == 1, "clearing first area does not clear the floor")
	check(run.mandatory_enemies_remaining == 3 and buffs.active_buff.is_empty(), "first clear removes only its buff and leaves pending objectives")
	check(str(hud.objective_label.text).contains("1/2 已清场"), "HUD directs player to the next area")
	check(first.reward_count == 1 and assembler.passages[0].unlocked, "first clear grants one supply and unlocks the passage")
	check(player.inventory.can_change_equipment(), "cleared area allows equipment changes despite pending next area")
	first._on_all_required_defeated()
	check(first.reward_count == 1 and assembler._rooms_remaining == 1, "repeated clear cannot duplicate supply or floor progress")
	ui.open_exit()
	check(not ui.get("_overlay").visible and not run.finish_extraction(player), "first clear cannot extract")
	var identity := player.get_instance_id()
	var state := player.export_run_state()
	var health := player.health.current_health
	player.heat.try_add_heat(20)
	var heat := player.heat.current_heat
	player.global_position = first.to_global(Vector2(600,180))
	await settle()
	await walk_right(player, 46)
	freeze_enemies()
	check(str(hud.objective_label.text).contains("2/2"), "HUD switches to second area objectives")
	check(player.global_position.x > second.global_position.x and second.active and assembler.active_area_index == 1, "actual walking through passage activates second area")
	check(get_nodes_in_group("enemies").size() == 3 and run.mandatory_enemies_remaining == 3, "second enemies spawn once without resetting total objectives")
	check(player.get_instance_id() == identity and player.export_run_state() == state and run.floor_index == 0, "area traversal preserves player, inventory and floor")
	check(player.health.current_health == health and is_equal_approx(player.heat.current_heat,heat), "area traversal preserves health and heat")
	check(EnvironmentArea.for_actor(player) == second and not player.inventory.can_change_equipment(), "area scope and combat equipment lock switch on entry")
	var enemy := get_first_node_in_group("enemies") as EnemyController
	player.global_position = first.to_global(Vector2(600,180))
	check(not enemy._same_room(player), "second-area AI does not pursue into cleared first area")
	player.global_position = second.to_global(Vector2(74,180))
	var box2 := second.find_child("PowerBox",true,false) as PowerBox
	player.global_position = box2.global_position+Vector2(0,-35)
	await settle()
	box2.interact(player)
	check(not buffs.active_buff.is_empty() and buffs.source_room == second, "second power box grants an independent area buff")
	await clear_active()
	check(second.cleared and run.mandatory_enemies_remaining == 0 and assembler._rooms_remaining == 0, "both cleared areas complete the floor")
	check(buffs.active_buff.is_empty() and second.reward_count == 1, "second clear expires its buff and grants one supply")
	check(str(hud.objective_label.text).contains("本层已清理"), "HUD shows floor completion only after both clears")
	check(not first.exit_elevator.enabled and second.exit_elevator.enabled, "only final exit becomes enabled")
	var rewards := 0
	for pickup in get_nodes_in_group("component_pickups"):
		if pickup.has_meta("clear_reward"):
			rewards += 1
	check(rewards == 2, "exactly one supply per area")
	player.global_position = second.exit_elevator.global_position
	await settle()
	check(ui.get("_overlay").visible and not paused, "actual final exit opens non-pausing extraction choice")
	ui.close_exit()
	main.queue_free()
	await process_frame
	print("Dual area checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
