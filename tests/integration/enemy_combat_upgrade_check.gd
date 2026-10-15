extends SceneTree

const ENEMY_SCENE := preload("res://scenes/actors/enemies/enemy.tscn")

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func enemy_at(room: Node2D, profile_path: String, location: Vector2, facing: Vector2 = Vector2.LEFT) -> EnemyController:
	var enemy := ENEMY_SCENE.instantiate() as EnemyController
	enemy.profile = load(profile_path).duplicate()
	enemy.profile.patrol_enabled = false
	enemy.position = location
	enemy.initial_facing = facing
	room.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy


func run() -> void:
	var room := Node2D.new()
	room.add_to_group("combat_rooms")
	root.add_child(room)
	current_scene = room
	var player := load("res://scenes/actors/player/player.tscn").instantiate() as PlayerController
	player.position = Vector2(100, 100)
	room.add_child(player)
	player.set_physics_process(false)
	var settings := root.get_node("GameSettings") as GameSettingsController
	settings.set_high_pressure_alert(false, false)
	settings.set_continuous_precharge(false, false)
	await physics_frame

	var vision := enemy_at(room, "res://resources/enemies/melee_pressure.tres", Vector2(420, 100))
	vision.set("_target", player)
	check(vision.can_see_target(), "camera-width boundary remains visible at 320 pixels")
	vision.position.x = 421
	check(not vision.can_see_target(), "camera-width rectangle rejects targets beyond 320 pixels")

	var observer := enemy_at(room, "res://resources/enemies/melee_pressure.tres", Vector2(100, 300))
	var near_ally := enemy_at(room, "res://resources/enemies/melee_pressure.tres", Vector2(400, 300), Vector2.RIGHT)
	var far_ally := enemy_at(room, "res://resources/enemies/melee_pressure.tres", Vector2(430, 300), Vector2.RIGHT)
	observer._alert_to(player.global_position, true)
	check(near_ally.is_alerted(), "standard alert reaches allies within 320 pixels")
	check(not far_ally.is_alerted(), "standard alert excludes allies beyond 320 pixels")
	observer._forget_target()
	near_ally._forget_target()
	far_ally._forget_target()
	settings.set_high_pressure_alert(true, false)
	observer._alert_to(player.global_position, true)
	check(far_ally.is_alerted(), "high-pressure alert reaches every ally in the same room")

	settings.set_high_pressure_alert(false, false)
	var charger := enemy_at(room, "res://resources/enemies/melee_pressure.tres", Vector2(240, 100))
	charger.set("_target", player)
	charger._physics_process(0.15)
	check(bool(charger.get("_precharge_active")), "first sight starts charge while outside attack range")
	charger._physics_process(0.16)
	check(bool(charger.get("_attack_precharged")), "charge can finish during pursuit")
	charger.position = Vector2(125, 100)
	player.hurt_box.clear_invulnerability()
	var health_before_charge := player.health.current_health
	charger._physics_process(0.01)
	check(player.health.current_health == health_before_charge - 1, "precharged melee attacks immediately after entering range")
	charger.set("_attack_cooldown_remaining", 0.0)
	charger.position = Vector2(200, 100)
	charger._physics_process(0.01)
	check(not bool(charger.get("_precharge_active")), "standard mode does not precharge subsequent attacks")
	settings.set_continuous_precharge(true, false)
	charger._physics_process(0.01)
	check(bool(charger.get("_precharge_active")), "continuous-charge switch enables subsequent precharge")

	var sniper := enemy_at(room, "res://resources/enemies/ranged_sightline.tres", Vector2(170, 100), Vector2.RIGHT)
	var footstep_ignored := enemy_at(room, "res://resources/enemies/melee_pressure.tres", Vector2(170, 130), Vector2.RIGHT)
	var events := root.get_node("CombatEvents")
	events.publish_movement_noise(player, player.global_position, 80.0)
	check(sniper.state != EnemyController.State.INVESTIGATE, "noise at the threshold does not trigger footstep search")
	events.publish_movement_noise(player, player.global_position, 90.0)
	check(sniper.state == EnemyController.State.INVESTIGATE and not sniper.is_alerted(), "sniper investigates audible walking without target lock")
	check(footstep_ignored.state != EnemyController.State.INVESTIGATE, "melee enemy ignores movement-only noise")
	var first_footstep: Vector2 = sniper.get("_investigation_target")
	events.publish_movement_noise(player, player.global_position + Vector2(12, 0), 90.0)
	check(sniper.get("_investigation_target") == first_footstep, "footstep investigation updates are throttled")
	sniper._tick_navigation_state(0.4)
	events.publish_movement_noise(player, player.global_position + Vector2(12, 0), 90.0)
	check(sniper.get("_investigation_target") != first_footstep, "latest footstep refreshes after 0.4 seconds")

	player.health.set_current_health(player.health.max_health)
	player.hurt_box.clear_invulnerability()
	var heavy := enemy_at(room, "res://resources/enemies/heavy_anchor.tres", Vector2(500, 300))
	var blast_ally := enemy_at(room, "res://resources/enemies/melee_pressure.tres", Vector2(500, 325))
	var blast_outsider := enemy_at(room, "res://resources/enemies/melee_pressure.tres", Vector2(500, 335))
	player.position = Vector2(525, 300)
	var defeated := [0]
	heavy.defeated.connect(func(_enemy: EnemyController, _mandatory: bool) -> void: defeated[0] += 1)
	var explosion_noise := [0]
	var explosion_effects := [0]
	var count_explosion := func(source: Node, _origin: Vector2, radius: float) -> void:
		if source == heavy and is_equal_approx(radius, 300.0):
			explosion_noise[0] += 1
	var count_explosion_effect := func(_origin: Vector2, _color: Color, _radius: float, _duration: float) -> void:
		explosion_effects[0] += 1
	events.noise_emitted.connect(count_explosion)
	events.effect_requested.connect(count_explosion_effect)
	heavy.health.apply_damage(heavy.health.max_health, DamagePacket.new())
	check(heavy.state == EnemyController.State.SELF_DESTRUCT and defeated[0] == 0, "heavy defeat waits for the self-destruct warning")
	heavy._physics_process(0.44)
	check(defeated[0] == 0, "self-destruct does not resolve before 0.45 seconds")
	heavy._physics_process(0.02)
	check(defeated[0] == 1 and explosion_noise[0] == 1, "self-destruct resolves defeat and emits 300-pixel noise")
	check(explosion_effects[0] == 2, "self-destruct requests a procedural flash and expanding ring")
	check(player.health.current_health == player.health.max_health - 1, "self-destruct damages the player inside attack range")
	check(blast_ally.health.current_health == blast_ally.health.max_health - 1, "self-destruct applies enemy friendly fire")
	check(blast_outsider.health.current_health == blast_outsider.health.max_health, "self-destruct radius matches the 34-pixel attack range")
	events.noise_emitted.disconnect(count_explosion)
	events.effect_requested.disconnect(count_explosion_effect)

	settings.set_high_pressure_alert(false, false)
	settings.set_continuous_precharge(false, false)
	room.queue_free()
	await process_frame
	print("Enemy combat upgrade failures: ", failures)
	quit(0 if failures == 0 else 1)
