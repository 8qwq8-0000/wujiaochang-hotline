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
	for turret in get_nodes_in_group("sentry_turrets"):
		turret.set_physics_process(false)

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
	root.get_node("WarehouseStore").save_path = "user://bc_dual_area_check.json"
	DirAccess.remove_absolute("user://bc_dual_area_check.json")
	var main: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	main.get_node("SceneFlow").fade_duration = 0
	root.add_child(main)
	current_scene = main
	for frame in 600:
		await process_frame
		if get_nodes_in_group("enemies").size() == 6 and not main.get_node("SceneFlow").get("_is_loading"):
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
	assembler.enemy_drop_chance = 0.0
	var first: CombatRoom = assembler.generated_rooms[0]
	var second: CombatRoom = assembler.generated_rooms[1]
	var run := root.get_node("RunManager")
	var ui := main.get_node("ExtractionFlow")
	check(assembler.generated_rooms.size() == 2 and assembler.passages.size() == 1, "one floor contains two connected areas")
	check(first.active and not second.active and not second.spawner._spawned, "only first area is active before entry")
	check(run.mandatory_enemies_remaining == 12 and get_nodes_in_group("enemies").size() == 6, "pending area contributes to floor objectives without spawning early")
	for room in [first, second]:
		check(room.find_children("*", "PowerBox", true, false).size() == 1, "each area has one power box")
		check(room.find_children("*", "FuelBarrel", true, false).size() == 3, "each area has three bomb boxes")
		check(room.find_children("*", "AutomaticDoor", true, false).size() == room.layout.doors.size(), "formal areas instantiate their authored doors; open halls need none")
	player.global_position = first.to_global(Vector2(900,270))
	await settle()
	await walk_right(player, 40)
	check(player.global_position.x < second.global_position.x and not second.active, "real collision blocks passage until first clear")
	var box := first.find_child("PowerBox", true, false) as PowerBox
	player.global_position = box.global_position + Vector2(0,-35)
	await settle()
	box.interact(player)
	var buffs := player.get_node("RoomBuffComponent") as RoomBuffComponent
	check(not buffs.active_buff.is_empty(), "first area grants its own power buff")
	var first_enemy: EnemyController = get_first_node_in_group("enemies")
	first.spawner._on_enemy_defeated(first_enemy, true)
	first.spawner._on_enemy_defeated(first_enemy, true)
	check(first.spawner.required_remaining == 5 and not first.cleared and first.reward_count == 0, "duplicate death signals cannot prematurely clear area or issue guarantee")
	await clear_active()
	check(first.cleared and not second.cleared and assembler._rooms_remaining == 1, "clearing first area does not clear the floor")
	check(run.mandatory_enemies_remaining == 6 and buffs.active_buff.is_empty(), "first clear removes only its buff and leaves pending objectives")
	check(assembler.passages[0].get_node("PassageSign").text == "前往下一区 →", "cleared area sign directs player onward")
	check(first.reward_count == 1 and assembler.passages[0].unlocked, "first clear grants one supply and unlocks the passage")
	var passage := assembler.passages[0]
	var sign := passage.get_node("PassageSign") as Label
	check(sign.get_theme_font("font") == CyberUITheme.FONT and sign.position.x + sign.size.x <= 0, "passage sign uses HUD pixel font and fits inside the current room")
	check(is_zero_approx(sign.position.y + sign.size.y * 0.5), "passage text aligns with the entrance center")
	check(passage.y_sort_enabled and passage.get_node("PassageFloor").z_index < player.z_index, "passage ground renders behind the player and walls sort by feet")
	for direction in [Vector2.UP, Vector2.DOWN]:
		player.global_position = passage.to_global(Vector2(passage.length * 0.5, 0))
		await settle()
		for frame in 24:
			await physics_frame
			player.velocity = direction * 180
			player.move_and_slide()
		check(absf(passage.to_local(player.global_position).y) < 40, "passage wall physically stops vertical movement")
	player.velocity = Vector2.ZERO
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
	player.global_position = first.to_global(Vector2(900,270))
	await settle()
	await walk_right(player, 46)
	freeze_enemies()
	check(assembler.active_area_index == 1, "objectives switch to the second area")
	check(player.global_position.x > second.global_position.x and second.active and assembler.active_area_index == 1, "actual walking through passage activates second area")
	check(get_nodes_in_group("enemies").size() == 6 and run.mandatory_enemies_remaining == 6, "second enemies spawn once without resetting total objectives")
	check(player.get_instance_id() == identity and player.export_run_state() == state and run.floor_index == 0, "area traversal preserves player, inventory and floor")
	check(player.health.current_health == health and is_equal_approx(player.heat.current_heat,heat), "area traversal preserves health and heat")
	check(EnvironmentArea.for_actor(player) == second, "area scope switches on entry")
	check(player.inventory.can_change_equipment(), "living player can change equipment in combat under current rules")
	check(assembler.passages[0].return_sealed, "entering second area permanently seals return route")
	player.global_position = second.to_global(Vector2(30, 270))
	await settle()
	for frame in 50:
		await physics_frame
		player.velocity = Vector2(-180, 0)
		player.move_and_slide()
	player.velocity = Vector2.ZERO
	check(player.global_position.x > first.global_position.x + CombatRoom.ROOM_SIZE.x, "real collision prevents walking back into first area")
	assembler.passages[0].unlock()
	await settle()
	check(not assembler.passages[0].get("_barrier").disabled, "later unlock cannot reopen sealed return gate")
	var enemy := get_first_node_in_group("enemies") as EnemyController
	player.global_position = first.to_global(Vector2(900,270))
	check(not enemy._same_room(player), "second-area AI does not pursue into cleared first area")
	player.global_position = second.to_global(Vector2(111,270))
	var box2 := second.find_child("PowerBox",true,false) as PowerBox
	player.global_position = box2.global_position+Vector2(0,-35)
	await settle()
	box2.interact(player)
	check(not buffs.active_buff.is_empty() and buffs.source_room == second, "second power box grants an independent area buff")
	await clear_active()
	check(second.cleared and run.mandatory_enemies_remaining == 0 and assembler._rooms_remaining == 0, "both cleared areas complete the floor")
	check(assembler.passages[0].return_sealed and not assembler.passages[0].get("_barrier").disabled, "clearing second room never reopens return route")
	check(buffs.active_buff.is_empty() and second.reward_count == 1, "second clear expires its buff and issues independent area guarantee")
	check(run.mandatory_enemies_remaining == 0, "floor objectives complete only after both clears")
	check(not first.exit_elevator.enabled and second.exit_elevator.enabled, "only final exit becomes enabled")
	var rewards := 0
	for pickup in get_nodes_in_group("component_pickups"):
		if pickup.has_meta("area_guarantee"):
			rewards += 1
	check(rewards == 2, "exactly one independent guarantee per area")
	second._on_all_required_defeated()
	assembler._on_room_cleared(second)
	check(get_nodes_in_group("component_pickups").size() == 2 and assembler._rooms_remaining == 0, "duplicate final clear cannot issue another area guarantee")
	var guarantee: ComponentPickup = get_first_node_in_group("component_pickups")
	var item := guarantee.rolled_item
	var valid_drop := not ComponentRolls.cyberware_modules(item).is_empty() if str(item.get_property("slot", "")) == "cyberware" else ComponentRolls.quality(item) >= 1 and not ComponentRolls.affixes(item).is_empty()
	check(valid_drop, "area guarantee contains a real rolled component or fixed-effect cyberware")
	player.global_position = second.exit_elevator.global_position
	await settle()
	check(ui.get("_overlay").visible and not paused, "actual final exit opens non-pausing extraction choice")
	ui.close_exit()
	main.queue_free()
	await process_frame
	print("Dual area checks: ", checks, "; failures: ", failures)
	DirAccess.remove_absolute("user://bc_dual_area_check.json")
	quit(0 if failures == 0 else 1)
