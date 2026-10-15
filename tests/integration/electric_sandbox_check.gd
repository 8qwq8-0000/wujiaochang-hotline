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
	var scene = load("res://scenes/debug/electric_reaction_sandbox.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	var player = scene.get_node("Player")
	player.set_physics_process(false)
	check(player.inventory.weapon_slot.get_item().get_prototype().get_prototype_id() == "test_conductive_pistol", "sandbox equips conductive weapon")
	check(player.inventory.secondary_weapon_slot.get_item().get_prototype().get_prototype_id() == "test_electric_pistol", "sandbox equips electric weapon")
	var targets = scene.get_node("Targets").get_children()
	check(targets.size() == 3, "three stationary targets available")
	for target in targets:
		target.get_node("StatusComponent").add_status(&"conductive",6,["negative","electric"])
	await process_frame
	await process_frame
	check(targets[0].get_node("StatusIndicator").visible, "conductive countdown visible")
	var packet := DamagePacket.new()
	packet.source = player
	packet.source_faction = CombatFaction.Id.PLAYER
	packet.damage_type = &"electric"
	targets[0].hurt_box.receive_hit(packet)
	await process_frame
	var effects = scene.get_node("VFXManager").get("_active_arcs")
	check(effects.size() == 2, "three targets show two secondary arcs")
	check(targets[1].health.current_health == 7 and targets[2].health.current_health == 7, "visible arcs carry actual damage")
	paused = true
	await create_timer(0.35,true).timeout
	check(scene.get_node("VFXManager").get("_active_arcs").size() == 2, "arc lifetime pauses with game")
	paused = false
	await create_timer(0.4).timeout
	check(scene.get_node("VFXManager").get("_active_arcs").is_empty(), "arcs clean up after expiry")
	var buffs = player.get_node("RoomBuffComponent")
	buffs.apply_buff(&"cooling",scene)
	for target in targets:
		target.health.apply_damage(100,DamagePacket.new())
	check(scene.cleared and buffs.active_buff.is_empty(), "last target clears room and removes buff")
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.physical_keycode = KEY_R
	key.pressed = true
	root.push_input(key,true)
	for frame in 5:
		await process_frame
	check(current_scene != scene and current_scene.remaining_targets == 3 and not current_scene.cleared, "real R reloads fresh sandbox")
	scene = current_scene
	scene.queue_free()
	await process_frame
	print("Electric sandbox checks: ",checks,"; failures: ",failures)
	quit(0 if failures == 0 else 1)
