extends SceneTree
class TestRoom extends Node2D:
	signal room_cleared
	var cleared := false
var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("run_checks")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func press_e() -> void:
	for pressed in [true,false]:
		var key := InputEventKey.new()
		key.keycode = KEY_E
		key.physical_keycode = KEY_E
		key.pressed = pressed
		root.push_input(key,true)
		await process_frame
func box_at(room: Node, point: Vector2, choice: int = 0) -> PowerBox:
	var box: PowerBox = load("res://scenes/environment/power_box.tscn").instantiate()
	box.position = point
	box.buff_choice = choice
	room.add_child(box)
	return box
func enemy_at(room: Node, point: Vector2) -> EnemyController:
	var enemy: EnemyController = load("res://scenes/actors/enemies/enemy.tscn").instantiate()
	enemy.profile = load("res://resources/enemies/melee_pressure.tres").duplicate()
	enemy.profile.max_health = 8
	enemy.position = point
	room.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy
func run_checks() -> void:
	var room := TestRoom.new()
	room.add_to_group("combat_rooms")
	root.add_child(room)
	current_scene = room
	var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	player.position = Vector2(200,240)
	room.add_child(player)
	player.set_physics_process(false)
	var buffs: RoomBuffComponent = player.get_node("RoomBuffComponent")
	var hud: CanvasLayer = load("res://scenes/ui/combat_hud.tscn").instantiate()
	room.add_child(hud)
	check(hud.get_node_or_null("Overlay/TopLeft/RoomBuff") == null,"minimal HUD omits the persistent room-buff row")
	var attack_box := box_at(room,Vector2(200,200),1)
	for frame in 4:
		await physics_frame
	await press_e()
	check(attack_box.state == PowerBox.State.CLAIMED and buffs.active_buff == &"attack_speed", "real E interaction claims attack buff")
	check(attack_box.get_node("RefinedArt").draw_size.is_equal_approx(Vector2(57.6,57.6)), "station artwork is ten percent smaller than two by two tiles")
	check_popup(attack_box, &"attack_speed")
	var original_popup := attack_box.get_node_or_null("ChargingBuffFeedback")
	attack_box.interact(player)
	check(get_nodes_in_group("charging_buff_feedback").size() == 1 and attack_box.get_node_or_null("ChargingBuffFeedback") == original_popup, "claimed station cannot spawn duplicate feedback")
	var weapon: WeaponComponentData = load("res://resources/weapons/service_pistol.tres")
	var original_cooldown := weapon.cooldown
	player.weapons.set_equipped_weapon(weapon)
	check(player.weapons.try_attack(Vector2(20,20),Vector2.LEFT,player), "buffed weapon fires")
	check(is_equal_approx(player.weapons.get("_cooldown_remaining"),weapon.cooldown/1.25), "attack buff affects actual attack cooldown")
	check(weapon.cooldown == original_cooldown, "buff never mutates shared weapon resource")
	attack_box.receive_hit(DamagePacket.new())
	await process_frame
	check(attack_box.discharge_count == 0, "claimed box cannot be destroyed for a second reward")
	room.room_cleared.emit()
	check(buffs.active_buff.is_empty() and player.weapons.attack_speed_multiplier == 1, "room clear removes source-room buff")
	var cooling_box := box_at(room,Vector2(200,200),2)
	for frame in 3:
		await physics_frame
	await press_e()
	check(cooling_box.state == PowerBox.State.CLAIMED and player.heat.cooling_multiplier == 1.5, "cooling buff claimed through same E path")
	check_popup(cooling_box, &"cooling")
	player.heat.set_physics_process(false)
	player.heat.current_heat = 80
	player.heat._physics_process(1)
	check(is_equal_approx(player.heat.current_heat,62), "12/s base cooling with a 50% buff dissipates 18 heat per second")
	room.room_cleared.emit()
	check(player.heat.cooling_multiplier == 1, "clear restores cooling multiplier")
	var guard_box := box_at(room,Vector2(200,200),3)
	for frame in 3:
		await physics_frame
	await press_e()
	check(guard_box.state == PowerBox.State.CLAIMED and player.guard.recovery_multiplier == 0.7, "guard buff claimed")
	check_popup(guard_box, &"guard_recovery")
	player.guard.set_physics_process(false)
	player.guard.begin_guard(Vector2.RIGHT)
	player.guard.advance_timing(player.guard.startup_seconds+player.guard.perfect_seconds+player.guard.normal_seconds+0.0001)
	check(player.guard.state == GuardComponent.State.RECOVERY and player.guard.get("_time_remaining") < player.guard.recovery_seconds, "guard buff shortens actual recovery phase")
	player.guard.advance_timing(player.guard.recovery_seconds*0.7)
	check(player.guard.state == GuardComponent.State.IDLE, "guard exits recovery at shortened duration")
	# The station is immune to direct hits, bullets and real melee sweeps.
	player.position = Vector2(430,200)
	player.health.set_current_health(3)
	player.hurt_box.clear_invulnerability()
	var target := enemy_at(room,Vector2(460,200))
	var other_room := TestRoom.new()
	other_room.add_to_group("combat_rooms")
	root.add_child(other_room)
	var arcs: Array = []
	root.get_node("CombatEvents").electric_arc_requested.connect(func(_a: Vector2,_b: Vector2,_room: Node) -> void: arcs.append(true))
	var danger := box_at(room,Vector2(400,200))
	check(danger.get_node("ActiveSigil").visible, "ready station projects its floor sigil")
	check(danger.collision_layer == 32, "station keeps interaction layer and leaves damage target layer")
	var impact := DamagePacket.new()
	impact.base_damage = 100
	impact.damage_type = &"electric"
	for attempt in 3:
		var result := danger.receive_hit(impact)
		check(result.final_damage == 0 and not result.target_defeated, "attacks cannot damage or destroy charging station")
	await process_frame
	check(danger.state == PowerBox.State.READY and danger.discharge_count == 0 and arcs.is_empty(), "attacks never discharge station or consume its buff")
	check(player.health.current_health == 3 and target.health.current_health == 8, "station attacks do not cause surrounding blast damage")
	danger.interact(player)
	check(danger.state == PowerBox.State.CLAIMED and not danger.get_node("ActiveSigil").visible, "E still claims attacked station and immediately extinguishes sigil")
	player.position = Vector2(490,100)
	player.hurt_box.clear_invulnerability()
	player.heat.current_heat = 0
	player.weapons.set("_cooldown_remaining",0)
	var shot_box := box_at(room,Vector2(550,100))
	var behind := enemy_at(room,Vector2(600,100))
	await physics_frame
	await physics_frame
	check(player.weapons.try_attack(Vector2(510,100),Vector2.RIGHT,player), "actual weapon fires toward charging station")
	for frame in 25:
		await physics_frame
	check(shot_box.state == PowerBox.State.READY and shot_box.discharge_count == 0, "real projectile cannot break station")
	check(behind.health.current_health < 8, "projectile passes through station and can hit an enemy behind it")
	player.weapons.set_equipped_weapon(load("res://resources/weapons/initial_baton.tres"))
	player.weapons.reset_transient_state()
	player.heat.current_heat = 0
	player.position = Vector2(100,100)
	var melee_box := box_at(room,Vector2(130,100))
	await physics_frame
	await physics_frame
	check(player.weapons.try_attack(player.position,Vector2.RIGHT,player), "melee attack begins")
	for frame in 12:
		player.weapons.update_attack_pose(player.position,Vector2.RIGHT,player)
		await physics_frame
	check(melee_box.state == PowerBox.State.READY and melee_box.discharge_count == 0, "real melee sweep cannot break station")
	var sigil := melee_box.get_node("ActiveSigil") as ChargingSigil
	var phase := sigil.phase
	paused = true
	var feedback := guard_box.get_node_or_null("ChargingBuffFeedback") as Node2D
	var feedback_position := feedback.position if feedback != null else Vector2.ZERO
	await create_timer(0.1, true).timeout
	check(sigil.phase == phase, "paused game freezes sigil animation")
	check(feedback == null or feedback.position == feedback_position, "paused game freezes buff popup")
	paused = false
	await create_timer(1.4).timeout
	check(get_nodes_in_group("charging_buff_feedback").is_empty(), "buff popups expire without leaving persistent effects")
	buffs.apply_buff(&"cooling",other_room)
	other_room.queue_free()
	await process_frame
	check(buffs.active_buff.is_empty() and player.heat.cooling_multiplier == 1, "source scene exit removes buff")
	other_room = TestRoom.new()
	root.add_child(other_room)
	# Source-room ownership prevents an unrelated room from clearing the buff.
	check(buffs.apply_buff(&"cooling",room), "apply replacement buff without stacking")
	other_room.room_cleared.emit()
	check(buffs.active_buff == &"cooling" and player.weapons.attack_speed_multiplier == 1 and player.guard.recovery_multiplier == 1, "unrelated room clear does not remove buff and replaced buffs do not stack")
	player.set_circuit_breaker_equipped(false)
	player.health.apply_damage(100,DamagePacket.new())
	check(player.health.is_dead() and buffs.active_buff.is_empty() and player.heat.cooling_multiplier == 1, "death clears room buff")
	room.cleared = true
	var late_box := box_at(room,Vector2(490,100))
	late_box.get_node("ActiveSigil").refresh()
	check(not late_box.can_interact(player) and not late_box.get_node("ActiveSigil").visible, "cleared room hides floor sigil and rejects fresh buffs")
	room.queue_free()
	other_room.queue_free()
	await process_frame
	print("Power-box checks: ",checks,"; failures: ",failures)
	quit(0 if failures == 0 else 1)

func check_popup(box: PowerBox, id: StringName) -> void:
	var feedback := box.get_node_or_null("ChargingBuffFeedback") as Node2D
	check(feedback != null, "successful %s claim shows arcade popup" % id)
	if feedback == null:
		return
	check((feedback.get_child(0) as Sprite2D).texture == PowerBox.BUFF_ART[id], "popup uses the matching buff artwork")
	check((feedback.get_child(1) as Label).text == "本区域清场后失效", "popup explains expiration")
