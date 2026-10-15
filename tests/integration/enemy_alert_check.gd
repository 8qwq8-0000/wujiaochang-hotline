extends SceneTree
var failures := 0
var room: Node2D
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func enemy_at(parent: Node, location: Vector2) -> EnemyController:
	var enemy: EnemyController = load("res://scenes/actors/enemies/enemy.tscn").instantiate()
	enemy.profile = load("res://resources/enemies/melee_pressure.tres").duplicate()
	enemy.profile.patrol_enabled = false
	enemy.profile.awareness_range = 200
	enemy.profile.hearing_range = 180
	enemy.profile.ally_alert_range = 0
	enemy.profile.alert_memory_seconds = 0.5
	enemy.position = location
	enemy.initial_facing = Vector2.RIGHT
	parent.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy
func wall_at(location: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10, 80)
	collision.shape = shape
	wall.add_child(collision)
	wall.position = location
	room.add_child(wall)
	return wall
func run() -> void:
	room = Node2D.new()
	room.add_to_group("combat_rooms")
	root.add_child(room)
	current_scene = room
	var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	player.position = Vector2(100, 100)
	room.add_child(player)
	player.set_physics_process(false)
	var observer := enemy_at(room, Vector2(200, 100))
	var events := root.get_node("CombatEvents")
	var alerts := [0]
	var count_alert := func(_enemy: Node, _world_position: Vector2) -> void: alerts[0] += 1
	events.enemy_alerted.connect(count_alert)
	await physics_frame
	observer._physics_process(0)
	check(not observer.is_alerted() and observer.state == EnemyController.State.IDLE, "player behind facing does not automatically alert enemy")
	observer.facing = Vector2.LEFT
	observer._physics_process(0)
	check(observer.is_alerted(), "player inside clear vision cone triggers alert")
	check(alerts[0] == 1, "first alert publishes one reinforcement cue event")
	observer._alert_to(player.global_position, true)
	check(alerts[0] == 1, "already-alerted enemy does not repeat reinforcement cue")
	observer._forget_target()
	player.position = Vector2(-100, 100)
	observer._physics_process(0)
	check(not observer.is_alerted(), "vision respects detection distance")
	player.position = Vector2(100, 100)
	observer.position = Vector2(200, 100)
	var wall := wall_at(Vector2(150, 100))
	await physics_frame
	await physics_frame
	observer.facing = Vector2.LEFT
	observer._physics_process(0)
	check(not observer.is_alerted(), "wall blocks sight even inside cone")
	events.publish_noise(player, player.global_position, 180.0)
	check(not observer.is_alerted(), "wall attenuates distant gun noise")
	player.position = Vector2(130, 100)
	events.publish_noise(player, player.global_position, 180.0)
	check(observer.is_alerted(), "nearby noise can be heard through wall")
	observer._forget_target()
	paused = true
	events.publish_noise(player, player.global_position, 180.0)
	check(not observer.is_alerted(), "paused inventory cannot advance hearing")
	paused = false
	wall.queue_free()
	await physics_frame
	await physics_frame
	player.position = Vector2(100, 100)
	events.publish_noise(player, player.global_position, 50.0)
	check(not observer.is_alerted(), "noise outside radius is ignored")
	observer.facing = Vector2.RIGHT
	var packet := DamagePacket.new()
	packet.source = player
	packet.source_position = player.global_position
	packet.source_faction = CombatFaction.Id.PLAYER
	observer.health.apply_damage(1, packet)
	check(observer.is_alerted(), "surviving a hit alerts enemy even behind vision")
	var remembered: Vector2 = observer.get("_last_known_position")
	player.position = Vector2(100, 180)
	observer._physics_process(0.1)
	check(observer.get("_last_known_position") == remembered, "hidden moving player does not update last-known position")
	observer.facing = Vector2.RIGHT
	observer._physics_process(1.0)
	check(not observer.is_alerted(), "lost target expires after memory timeout")
	observer.position = Vector2(200, 100)
	player.position = Vector2(100, 100)
	observer.profile.ally_alert_range = 60
	var nearby := enemy_at(room, Vector2(250, 100))
	nearby.profile.ally_alert_range = 60
	var distant := enemy_at(room, Vector2(300, 100))
	var other_room := Node2D.new()
	other_room.add_to_group("combat_rooms")
	root.add_child(other_room)
	var foreign := enemy_at(other_room, Vector2(225, 100))
	observer._alert_to(player.global_position, true)
	check(nearby.is_alerted(), "alert wakes nearby ally")
	check(not distant.is_alerted(), "ally does not rebroadcast into a map-wide chain")
	check(not foreign.is_alerted(), "alert cannot leak into another combat room")
	foreign._on_noise(player, player.global_position, 1000)
	check(not foreign.is_alerted(), "sound cannot leak into another combat room")
	observer._forget_target()
	nearby._forget_target()
	wall = wall_at(Vector2(225, 100))
	await physics_frame
	await physics_frame
	observer._alert_to(player.global_position, true)
	check(not nearby.is_alerted(), "wall blocks ally alarm propagation")
	wall.queue_free()
	await physics_frame
	observer._forget_target()
	observer.profile.ally_alert_range = 0
	observer.facing = Vector2.RIGHT
	player.inventory.pickup("pistol")
	player.weapons.select_weapon(1)
	var emitted := [0]
	var count_noise := func(_source: Node, _origin: Vector2, _radius: float) -> void: emitted[0] += 1
	events.noise_emitted.connect(count_noise)
	check(player.weapons.try_attack(player.global_position, Vector2.UP, player), "actual pistol fires")
	check(observer.is_alerted() and emitted[0] == 1, "successful gunshot emits one gameplay sound")
	check(not player.weapons.try_attack(player.global_position, Vector2.UP, player), "cooldown rejects next shot")
	check(emitted[0] == 1, "rejected shot emits no sound")
	observer._forget_target()
	player.weapons.select_weapon(0)
	player.weapons.reset_transient_state()
	check(player.weapons.try_attack(player.global_position, Vector2.UP, player), "initial baton attacks")
	check(not observer.is_alerted() and emitted[0] == 1, "quiet melee does not emit gunshot sound")
	events.noise_emitted.disconnect(count_noise)
	events.enemy_alerted.disconnect(count_alert)
	room.queue_free()
	other_room.queue_free()
	await process_frame
	print("Enemy alert failures: ", failures)
	quit(0 if failures == 0 else 1)
