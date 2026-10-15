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
	var buff_label: Label = hud.get_node("Overlay/TopLeft/RoomBuff")
	check(not buff_label.visible,"HUD buff row starts hidden")
	var attack_box := box_at(room,Vector2(200,200),1)
	for frame in 4:
		await physics_frame
	await press_e()
	check(attack_box.state == PowerBox.State.CLAIMED and buffs.active_buff == &"attack_speed", "real E interaction claims attack buff")
	check(buff_label.visible and buff_label.text.contains("攻速提升 25%"),"real E claim shows buff effect in top-left HUD")
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
	check(not buff_label.visible,"room clear immediately hides HUD buff")
	check(buffs.active_buff.is_empty() and player.weapons.attack_speed_multiplier == 1, "room clear removes source-room buff")
	var cooling_box := box_at(room,Vector2(200,200),2)
	for frame in 3:
		await physics_frame
	await press_e()
	check(cooling_box.state == PowerBox.State.CLAIMED and player.heat.cooling_multiplier == 1.5, "cooling buff claimed through same E path")
	check(buff_label.visible and buff_label.text.contains("散热提升 50%"),"HUD updates when active buff changes")
	player.heat.set_physics_process(false)
	player.heat.current_heat = 80
	player.heat._physics_process(1)
	check(is_equal_approx(player.heat.current_heat,44), "cooling buff changes actual heat dissipation")
	room.room_cleared.emit()
	check(player.heat.cooling_multiplier == 1, "clear restores cooling multiplier")
	var guard_box := box_at(room,Vector2(200,200),3)
	for frame in 3:
		await physics_frame
	await press_e()
	check(guard_box.state == PowerBox.State.CLAIMED and player.guard.recovery_multiplier == 0.7, "guard buff claimed")
	player.guard.set_physics_process(false)
	player.guard.begin_guard(Vector2.RIGHT)
	player.guard.advance_timing(player.guard.startup_seconds+player.guard.perfect_seconds+player.guard.normal_seconds+0.0001)
	check(player.guard.state == GuardComponent.State.RECOVERY and player.guard.get("_time_remaining") < player.guard.recovery_seconds, "guard buff shortens actual recovery phase")
	player.guard.advance_timing(player.guard.recovery_seconds*0.7)
	check(player.guard.state == GuardComponent.State.IDLE, "guard exits recovery at shortened duration")
	# Player and enemies are damaged together; cover, range, and scope stay respected.
	player.position = Vector2(430,200)
	player.health.set_current_health(3)
	player.hurt_box.clear_invulnerability()
	var target := enemy_at(room,Vector2(460,200))
	var covered := enemy_at(room,Vector2(460,250))
	var far := enemy_at(room,Vector2(600,200))
	var other_room := TestRoom.new()
	other_room.add_to_group("combat_rooms")
	root.add_child(other_room)
	var isolated := enemy_at(other_room,Vector2(460,200))
	var wall := StaticBody2D.new()
	wall.position = Vector2(430,225)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10,20)
	collider.shape = shape
	wall.add_child(collider)
	room.add_child(wall)
	var danger := box_at(room,Vector2(400,200))
	for frame in 3:
		await physics_frame
	danger.receive_hit(DamagePacket.new())
	danger.interact(player)
	danger.receive_hit(DamagePacket.new())
	await process_frame
	await process_frame
	check(danger.state == PowerBox.State.BROKEN and danger.discharge_count == 1, "attacking reserves one discharge and excludes E claim")
	check(player.health.current_health == 2 and target.health.current_health == 7, "environment discharge damages both player and enemy")
	check(player.statuses.has_status(&"conductive") and target.get_node("StatusComponent").has_status(&"conductive"), "discharge applies conductivity to both actor types")
	check(covered.health.current_health == 8 and far.health.current_health == 8 and isolated.health.current_health == 8, "cover, radius and room scope block discharge")
	player.position = Vector2(20,20)
	var chain_target := enemy_at(room,Vector2(520,200))
	chain_target.get_node("StatusComponent").add_status(&"conductive",6,["negative","electric"])
	var arcs: Array = []
	root.get_node("CombatEvents").electric_arc_requested.connect(func(_a: Vector2,_b: Vector2,_room: Node) -> void: arcs.append(true))
	var second := box_at(room,Vector2(400,200))
	second.receive_hit(DamagePacket.new())
	await process_frame
	check(arcs.size() > 0 and chain_target.health.current_health < 8, "power-box electric discharge triggers real conductive arc damage")
	# Native projectile collision must break the Area2D prop.
	player.position = Vector2(490,100)
	player.hurt_box.clear_invulnerability()
	player.heat.current_heat = 0
	player.weapons.set("_cooldown_remaining",0)
	var shot_box := box_at(room,Vector2(550,100))
	await physics_frame
	await physics_frame
	check(player.weapons.try_attack(Vector2(510,100),Vector2.RIGHT,player), "actual weapon fires toward power box")
	for frame in 20:
		await physics_frame
		if shot_box.state == PowerBox.State.BROKEN:
			break
	check(shot_box.state == PowerBox.State.BROKEN, "real projectile breaks the box")
	# The bound melee weapon can also hit the environment Area2D.
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
	check(melee_box.state == PowerBox.State.BROKEN, "real melee sweep breaks power box")
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
	check(not buff_label.visible,"death immediately hides HUD buff")
	room.cleared = true
	var late_box := box_at(room,Vector2(490,100))
	check(not late_box.can_interact(player), "dead player and cleared room cannot claim a fresh buff")
	room.queue_free()
	other_room.queue_free()
	await process_frame
	print("Power-box checks: ",checks,"; failures: ",failures)
	quit(0 if failures == 0 else 1)
