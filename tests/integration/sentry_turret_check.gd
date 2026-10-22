extends SceneTree

class Arena extends Node2D:
	signal room_cleared
	var active := true
	var cleared := false
	var obstacle_removed := false
	func _enter_tree() -> void:
		add_to_group("environment_areas")
	func contains_world_point(point: Vector2) -> bool:
		return Rect2(Vector2.ZERO, Vector2(1000, 700)).has_point(to_local(point))
	func remove_sentry_obstacle(_turret: Node2D) -> void:
		obstacle_removed = true

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	for frame in 3:
		await physics_frame
	await process_frame

func run() -> void:
	root.get_node("WarehouseStore").save_path = "user://sentry-turret-check.json"
	root.get_node("RunManager").begin_run(931)
	var world := Node2D.new()
	world.add_to_group("combat_rooms")
	root.add_child(world)
	current_scene = world
	var arena := Arena.new()
	world.add_child(arena)
	var other := Arena.new()
	other.position.x = 1200
	world.add_child(other)
	var turret: SentryTurret = load("res://scenes/environment/sentry_turret.tscn").instantiate()
	turret.position = Vector2(400, 300)
	arena.add_child(turret)
	turret.set_physics_process(false)
	var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	player.heat.set_physics_process(false)
	player.health.configure_max_health(100)
	check(turret.get_node("CollisionShape2D").shape.size.is_equal_approx(Vector2(86.4, 86.4)), "turret solid footprint follows ten percent size reduction")
	for index in 8:
		var heading := Vector2.from_angle(index * PI / 4)
		player.position = turret.position + heading * 220
		await settle()
		turret._cooldown = 100
		for step in 40:
			turret._physics_process(0.05)
		check(absf(angle_difference(Vector2.DOWN.rotated(turret.gun.rotation).angle(), heading.angle())) < 0.02, "gun tracks target direction %d" % index)
		check(is_zero_approx(turret.get_node("Visuals/Base").global_rotation), "base remains fixed while gun rotates")
		var shots := turret.fire_volley(heading)
		check(shots.size() == 2, "each volley emits two bullets")
		if shots.size() == 2:
			check(shots[0].direction.is_equal_approx(shots[1].direction) and shots[0].direction.is_equal_approx(heading), "double rows stay parallel to aim")
			var separation := shots[1].global_position - shots[0].global_position
			check(is_equal_approx(separation.length(), 14.4) and absf(separation.dot(heading)) < 0.01, "muzzle separation follows the smaller artwork")
			check(shots[0].source == turret and shots[0].faction == CombatFaction.Id.ENEMY and shots[0].reflectable, "turret uses normal reflectable enemy projectiles")
		for shot in shots:
			shot.queue_free()
		await settle()
	player.position = Vector2(400, 520)
	await settle()
	turret.gun.rotation = 0
	turret._cooldown = 0
	turret._warning = 0
	var count := turret.volleys_fired
	turret._physics_process(0.01)
	check(turret._warning > 0 and turret.volleys_fired == count, "aim warning precedes firing")
	var before := player.health.current_health
	turret._physics_process(turret.warning_seconds + 0.01)
	check(turret.volleys_fired == count + 1, "completed warning emits one double volley")
	for frame in 80:
		await physics_frame
		if player.health.current_health < before:
			break
	check(player.health.current_health < before, "actual turret projectile reaches and damages player")
	turret.stop_firing()
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.position = Vector2(400, 410)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(120, 12)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	wall.add_child(collider)
	world.add_child(wall)
	await settle()
	turret._cooldown = 0
	count = turret.volleys_fired
	for step in 80:
		turret._physics_process(0.05)
	check(turret._warning == 0 and turret.volleys_fired == count, "walls prevent acquisition and firing")
	wall.queue_free()
	await settle()
	paused = true
	check(turret.fire_volley(Vector2.DOWN).is_empty(), "pause prevents firing")
	paused = false
	arena.active = false
	check(turret.fire_volley(Vector2.DOWN).is_empty(), "pending area cannot fire")
	arena.active = true
	player.position = Vector2(1400, 200)
	turret.detection_range = 2000
	check(turret._target() == null, "turret never targets another combat area")
	player.position = Vector2(320, 300)
	await settle()
	for frame in 40:
		player.velocity = Vector2.RIGHT * 180
		player.move_and_slide()
		await physics_frame
	check(player.position.x < 350, "solid base physically blocks player")
	player.velocity = Vector2.ZERO
	var pending := turret.fire_volley(Vector2.UP)
	arena.cleared = true
	arena.room_cleared.emit()
	await settle()
	check(pending.all(func(shot) -> bool: return not is_instance_valid(shot)), "clear removes existing turret projectiles")
	check(turret.fire_volley(Vector2.DOWN).is_empty(), "cleared room remains safe")
	arena.cleared = false
	var hit := DamagePacket.new()
	hit.base_damage = 4
	hit.source_faction = CombatFaction.Id.PLAYER
	turret.get_node("HurtBox").receive_hit(hit)
	await settle()
	check(turret.destroyed and turret.health.is_dead() and not arena.obstacle_removed, "destroyed turret retains its navigation obstacle")
	check(turret.collision_layer == 128 and turret.fire_volley(Vector2.DOWN).is_empty(), "destroyed turret stays solid but cannot fire")
	check(turret.get_node("HurtBox").collision_layer == 0, "wreck cannot receive further attacks")
	for frame in 40:
		player.velocity = Vector2.RIGHT * 180
		player.move_and_slide()
		await physics_frame
	check(player.position.x < 350, "player cannot walk through visible turret wreck")
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		player.position = turret.position - direction * 90
		player.velocity = Vector2.ZERO
		player.dash.reset_transient_state()
		await settle()
		player.dash.start_dash(player, direction, direction)
		for frame in 30:
			await physics_frame
			player.dash.tick(player, direction, direction, 1.0 / 60.0)
		check((player.position - turret.position).dot(direction) < -40, "turret wreck blocks dash from %s" % direction)
	world.queue_free()
	await settle()
	DirAccess.remove_absolute("user://sentry-turret-check.json")
	print("Sentry turret checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
