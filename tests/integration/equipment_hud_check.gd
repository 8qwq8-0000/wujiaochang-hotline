extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func run_checks() -> void:
	root.get_node("WarehouseStore").save_path = "user://equipment-hud-check.json"
	var main: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	var player: PlayerController
	var hud := main.get_node("CombatHUD")
	for frame in 600:
		await process_frame
		player = get_first_node_in_group("player") as PlayerController
		if player != null and hud.get("_player") == player and not main.get_node("SceneFlow").get("_is_loading"):
			break
	if player == null:
		check(false, "combat player loads")
		quit(1)
		return
	player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var row: HBoxContainer = hud.get("_cyberware_preview")
	var weapon: TextureRect = hud.get("_weapon_preview")
	var rng := RandomNumberGenerator.new()
	rng.seed = 916
	player.inventory.cyberware_slot.clear()
	player.inventory._apply_equipment()
	await process_frame
	check(row.get_child_count() == 0 and not row.visible, "empty cyberware slot leaves no icon placeholders")
	var spare := ComponentRolls.create("optical_intruder", 1, rng)
	player.inventory.backpack.add_item(spare)
	player.inventory._apply_equipment()
	check(row.get_child_count() == 0, "backpack cyberware does not appear as equipped")
	for modules in [
		PackedStringArray(["smart_fire"]),
		PackedStringArray(["smart_fire", "explosive_magazine"]),
		PackedStringArray(["smart_fire", "explosive_magazine", "kill_heat_sink", "heat_threshold_pulser"]),
		PackedStringArray(["smart_fire", "explosive_magazine"]),
		PackedStringArray(["smart_fire"]),
	]:
		var equipped := ComponentRolls.create("smart_fire", 1, rng)
		equipped.set_property("modules", modules)
		player.inventory.cyberware_slot.clear()
		player.inventory.cyberware_slot.equip(equipped)
		player.inventory._apply_equipment()
		await process_frame
		check(row.get_child_count() == modules.size(), "equipped module count matches HUD icons: %d" % modules.size())
		var active_modules := player.cyberware.modules
		for index in active_modules.size():
			var icon: TextureRect = row.get_child(index)
			var data := load(ComponentRolls.cyberware_resource_path(StringName(active_modules[index]))) as CyberwareData
			check(icon.texture != null and icon.modulate == weapon.modulate, "module icon uses the weapon opacity and tint")
			check(icon.tooltip_text == "%s\n%s" % [data.display_name, data.description], "hover uses the equipped module's real effect description")
		for hud_scale in [1.0, 1.5]:
			hud.set_hud_scale(hud_scale)
			await process_frame
			var bounds: Rect2 = hud.get("overlay").get_global_rect()
			check(bounds.encloses(weapon.get_global_rect()) and bounds.encloses(row.get_global_rect()), "equipment stays on screen at HUD scale %.1f" % hud_scale)
			check(weapon.get_global_rect().end.x < row.get_global_rect().position.x, "gun stays left of icons at HUD scale %.1f" % hud_scale)
		var first_icon: TextureRect = row.get_child(0)
		player.set("_attack_pressed", false)
		for pressed in [true, false]:
			var click := InputEventMouseButton.new()
			click.position = first_icon.get_global_rect().get_center()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			root.push_input(click, true)
		check(player.get("_attack_pressed"), "hoverable icons do not swallow shooting clicks")
		if modules.size() == 2 and DisplayServer.get_name() != "headless" and OS.get_cmdline_user_args().has("--capture"):
			hud.set_hud_scale(1.0)
			await process_frame
			var motion := InputEventMouseMotion.new()
			motion.position = first_icon.get_global_rect().get_center()
			root.push_input(motion, true)
			await create_timer(1.0).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/hotline-equipment-hud.png")
	var momentum := ComponentRolls.create("momentum_recovery_tendon", 1, rng)
	player.inventory.cyberware_slot.clear()
	player.inventory.cyberware_slot.equip(momentum)
	player.inventory._apply_equipment()
	player.dash.dash_damaged_enemy.emit(player)
	await process_frame
	var momentum_label: Label = hud.get("_momentum_ready_label")
	check(momentum_label.visible and momentum_label.text.begins_with("零热待发"), "momentum charge exposes its remaining ready window in the HUD")
	var trajectory := ComponentRolls.create("trajectory_echo_processor", 1, rng)
	player.inventory.cyberware_slot.clear()
	player.inventory.cyberware_slot.equip(trajectory)
	player.inventory._apply_equipment()
	player.cyberware.set("_trajectory_echo_cooldown_remaining", 4.0)
	await process_frame
	var trajectory_icon := row.get_child(0) as TextureRect
	check(trajectory_icon.modulate != weapon.modulate, "trajectory echo icon darkens while its internal cooldown is active")
	player.cyberware._physics_process(4.0)
	await process_frame
	check(trajectory_icon.modulate == weapon.modulate, "trajectory echo icon returns to its normal tint when ready")
	var takeover := ComponentRolls.create("ballistic_takeover_protocol", 1, rng)
	player.inventory.cyberware_slot.clear()
	player.inventory.cyberware_slot.equip(takeover)
	player.inventory._apply_equipment()
	player.cyberware.set("_ballistic_takeover_cooldown_remaining", 6.0)
	await process_frame
	var takeover_icon := row.get_child(0) as TextureRect
	check(takeover_icon.modulate != weapon.modulate, "ballistic takeover icon darkens during its internal cooldown")
	player.cyberware._physics_process(6.0)
	await process_frame
	check(takeover_icon.modulate == weapon.modulate, "ballistic takeover icon returns to its normal tint when ready")
	var arc_cortex := ComponentRolls.create("arc_ballistic_cortex", 1, rng)
	player.inventory.cyberware_slot.clear()
	player.inventory.cyberware_slot.equip(arc_cortex)
	player.inventory._apply_equipment()
	await process_frame
	var arc_icon := row.get_child(0) as TextureRect
	check(arc_icon.modulate == weapon.modulate, "always-on arc ballistic cortex icon stays at its normal tint")
	var inverter := ComponentRolls.create("inertial_inversion_vertebra", 1, rng)
	player.inventory.cyberware_slot.clear()
	player.inventory.cyberware_slot.equip(inverter)
	player.inventory._apply_equipment()
	player.cyberware.set("_inertial_inversion_cooldown_remaining", 3.0)
	await process_frame
	var inverter_icon := row.get_child(0) as TextureRect
	check(inverter_icon.modulate != weapon.modulate, "inertial inversion icon darkens during its internal cooldown")
	player.cyberware._physics_process(3.0)
	await process_frame
	check(inverter_icon.modulate == weapon.modulate, "inertial inversion icon returns to its normal tint when ready")
	var recycler := ComponentRolls.create("axon_recycler", 1, rng)
	player.inventory.cyberware_slot.clear()
	player.inventory.cyberware_slot.equip(recycler)
	player.inventory._apply_equipment()
	await process_frame
	var recycler_icon := row.get_child(0) as TextureRect
	check(recycler_icon.modulate == weapon.modulate, "always-on axon recycler icon stays at its normal tint")
	var micro_rotor := ComponentRolls.create("micro_rotor_reflex_bundle", 1, rng)
	player.inventory.cyberware_slot.clear()
	player.inventory.cyberware_slot.equip(micro_rotor)
	player.inventory._apply_equipment()
	await process_frame
	var micro_rotor_icon := row.get_child(0) as TextureRect
	check(micro_rotor_icon.modulate == weapon.modulate, "always-on micro rotor reflex bundle icon stays at its normal tint")
	var predatory_ring := ComponentRolls.create("predatory_vestibular_ring", 1, rng)
	player.inventory.cyberware_slot.clear()
	player.inventory.cyberware_slot.equip(predatory_ring)
	player.inventory._apply_equipment()
	await process_frame
	var predatory_ring_icon := row.get_child(0) as TextureRect
	check(predatory_ring_icon.modulate == weapon.modulate, "always-on predatory vestibular ring icon stays at its normal tint")
	player.inventory.cyberware_slot.clear()
	player.inventory._apply_equipment()
	check(row.get_child_count() == 0 and not row.visible, "unequip immediately clears all module icons")
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://equipment-hud-check.json")
	print("Equipment HUD checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
