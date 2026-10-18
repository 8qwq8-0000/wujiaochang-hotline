extends SceneTree
var failures := 0
var checks := 0
var player: PlayerController
var room: Node2D

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func settle() -> void:
	await physics_frame
	await physics_frame
	await process_frame

func ticks(count: int, input := Vector2.ZERO) -> void:
	for index in count:
		await physics_frame
		player.mobility.tick(player, input, Vector2.UP, 1.0 / 60.0)

func reset_player() -> void:
	player.position = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player.mobility.reset_transient_state()

func enemy_at(where: Vector2) -> EnemyController:
	var enemy: EnemyController = load("res://scenes/actors/enemies/enemy.tscn").instantiate()
	enemy.position = where
	enemy.stationary_test_target = true
	enemy.mandatory = false
	room.add_child(enemy)
	enemy.health.configure_max_health(20)
	enemy.set_physics_process(false)
	return enemy

func run() -> void:
	room = Node2D.new()
	root.add_child(room)
	current_scene = room
	player = load("res://scenes/actors/player/player.tscn").instantiate()
	room.add_child(player)
	player.set_physics_process(false)
	player.equip_mobility(load("res://resources/mobility/wheel.tres"))
	var mode := player.mobility.get_current_mode()
	for fps in [30, 60, 120]:
		var velocity := Vector2.ZERO
		velocity = mode.calculate_velocity(Vector2.RIGHT, velocity, Vector2.LEFT, 1.0 / fps)
		check(velocity.x > 0 and is_zero_approx(velocity.y), "start follows input regardless of mouse at %d fps" % fps)
		velocity = Vector2.RIGHT * mode.max_speed
		for index in int(fps * 0.25):
			velocity = mode.calculate_velocity(Vector2.LEFT, velocity, Vector2.RIGHT, 1.0 / fps)
		check(velocity.x < -mode.max_speed * 0.9, "reverse reliably at %d fps" % fps)
		velocity = Vector2.RIGHT * mode.max_speed
		for index in int(fps * 0.15):
			velocity = mode.calculate_velocity(Vector2.ZERO, velocity, Vector2.RIGHT, 1.0 / fps)
		check(velocity.is_zero_approx(), "release stops promptly at %d fps" % fps)
	var enemy := enemy_at(Vector2(40, 0))
	enemy.state = EnemyController.State.WINDUP
	enemy.set("_windup_remaining", 0.4)
	var distant := enemy_at(Vector2(180, 0))
	await settle()
	check(player.mobility.activate_ability(player, Vector2.UP, Vector2.RIGHT), "movement direction starts ram")
	check(player.velocity.x > 0 and is_zero_approx(player.velocity.y), "ram direction uses WASD over aim")
	check(not player.mobility.activate_ability(player, Vector2.LEFT), "cannot spam during cooldown")
	await ticks(6, Vector2.LEFT)
	check(player.position.x > 35 and absf(player.position.y) < 0.1, "ram holds direction against opposite input")
	check(enemy.health.current_health == 20 - mode.ram_damage, "ram inflicts configured damage once")
	check(enemy.state == EnemyController.State.STAGGERED and enemy.get("_stagger_remaining") >= 0.6, "ram interrupts enemy windup")
	check(enemy.get("_windup_remaining") == 0.0, "interrupted attack cannot complete")
	await ticks(8)
	check(enemy.health.current_health == 20 - mode.ram_damage, "same ram never hits enemy twice")
	check(distant.health.current_health == 20, "enemy outside path receives no damage")
	check(not player.mobility.is_ability_active() and player.position.x >= 80 and player.position.x < 100, "ram lasts about 84 pixels then ends")
	check(player.velocity.length() <= mode.max_speed, "no leftover burst speed after ram")
	check(player.mobility.can_attack() and player.mobility.can_guard(), "weapon and guard remain available for combos")
	check(not player.hurt_box.is_invulnerable(), "ram invulnerability expires before charge finishes")
	await ticks(90)
	check(player.mobility.activate_ability(player, Vector2.LEFT), "cooldown permits next ram with stationary aim fallback")
	check(player.velocity.x < 0, "stationary ram follows aim")
	player.mobility.unequip_mode()
	check(not player.mobility.is_ability_active() and not player.mobility.activate_ability(player, Vector2.RIGHT), "unequip cancels ram and restores walking")
	player.equip_mobility(mode)
	reset_player()
	await settle()
	Engine.physics_ticks_per_second = 5
	await settle()
	player.mobility.activate_ability(player, Vector2.RIGHT)
	await physics_frame
	player.mobility.tick(player, Vector2.ZERO, Vector2.UP, 0.20)
	Engine.physics_ticks_per_second = 60
	check(enemy.health.current_health == 20 - mode.ram_damage * 2, "swept charge detects enemy even when one frame spans entire path")
	check(is_equal_approx(player.position.x, 84.0), "charge distance is stable across long physics steps")
	check(not player.mobility.is_ability_active(), "long step ends charge at correct time")
	# Follow the charge with the ordinary equipped baton.
	player.weapons.equip_weapon(load("res://resources/weapons/baton.tres"))
	player.weapons.reset_transient_state()
	enemy.position = player.position + Vector2.RIGHT.rotated(deg_to_rad(-36)) * 30.0
	await settle()
	check(player.weapons.try_attack(player.position, Vector2.RIGHT, player), "baton can immediately follow charge")
	player.weapons.update_attack_pose(player.position, Vector2.RIGHT, player)
	check(enemy.health.current_health == 19 - mode.ram_damage * 2, "follow-up baton lands real additional damage")
	enemy.queue_free()
	distant.queue_free()
	player.equip_mobility(mode)
	reset_player()
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.position = Vector2(35, 0)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(6, 120)
	collider.shape = shape
	wall.add_child(collider)
	room.add_child(wall)
	var behind_wall := enemy_at(Vector2(43, 0))
	await settle()
	player.mobility.activate_ability(player, Vector2.RIGHT)
	await ticks(6)
	check(not player.mobility.is_ability_active(), "wall cancels charge early")
	check(player.position.x < 32 and player.velocity.is_zero_approx(), "wall prevents penetration and leftover slide")
	check(behind_wall.health.current_health == 20, "contact radius cannot damage through wall")
	check(player.mobility.ability_cooldown_remaining > 0.9, "wall impact retains cooldown")
	room.queue_free()
	await process_frame
	print("Wheel ram checks: ", checks, ", failures: ", failures)
	quit(0 if failures == 0 else 1)
