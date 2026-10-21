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
		player.dash.tick(player, input, Vector2.UP, 1.0 / 60.0)


func reset_player() -> void:
	player.position = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player.dash.reset_transient_state()


func enemy_at(where: Vector2) -> EnemyController:
	var enemy := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
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
	var config := player.dash.config
	var enemy := enemy_at(Vector2(40, 0))
	enemy.state = EnemyController.State.WINDUP
	enemy.set("_windup_remaining", 0.4)
	var distant := enemy_at(Vector2(180, 0))
	await settle()
	check(player.dash.start_dash(player, Vector2.UP, Vector2.RIGHT), "movement direction starts fixed dash")
	check(player.velocity.x > 0 and is_zero_approx(player.velocity.y), "dash uses WASD over aim")
	check(not player.dash.start_dash(player, Vector2.LEFT), "dash cannot be spammed during cooldown")
	await ticks(6, Vector2.LEFT)
	check(player.position.x > 35 and absf(player.position.y) < 0.1, "dash holds direction against opposite input")
	check(enemy.health.current_health == 20 - config.collision_damage, "dash inflicts configured damage once")
	check(enemy.state == EnemyController.State.STAGGERED and enemy.get("_stagger_remaining") >= 0.6, "dash interrupts enemy windup")
	await ticks(8)
	check(enemy.health.current_health == 20 - config.collision_damage, "same dash never hits one enemy twice")
	check(distant.health.current_health == 20, "enemy outside path receives no damage")
	check(not player.dash.is_dashing() and player.position.x >= 80 and player.position.x < 100, "dash lasts about 84 pixels")
	check(player.velocity.length() <= config.walk_speed, "dash leaves no burst speed")
	check(player.dash.can_attack() and player.dash.can_guard(), "weapon and guard stay available")
	await ticks(90)
	check(player.dash.start_dash(player, Vector2.LEFT), "cooldown permits the next dash")
	check(player.velocity.x < 0, "stationary dash follows aim")

	reset_player()
	await settle()
	Engine.physics_ticks_per_second = 5
	await settle()
	player.dash.start_dash(player, Vector2.RIGHT)
	await physics_frame
	player.dash.tick(player, Vector2.ZERO, Vector2.UP, 0.20)
	Engine.physics_ticks_per_second = 60
	check(enemy.health.current_health == 20 - config.collision_damage * 2, "swept dash detects targets across a long physics step")
	check(is_equal_approx(player.position.x, 84.0), "dash distance is stable across long steps")
	check(not player.dash.is_dashing(), "long step ends dash at the correct time")

	enemy.queue_free()
	distant.queue_free()
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
	player.dash.start_dash(player, Vector2.RIGHT)
	await ticks(6)
	check(not player.dash.is_dashing(), "wall cancels dash early")
	check(player.position.x < 32 and player.velocity.is_zero_approx(), "wall prevents penetration and leftover slide")
	check(behind_wall.health.current_health == 20, "dash radius cannot damage through a wall")
	check(player.dash.cooldown_remaining > 0.9, "wall impact retains cooldown")
	room.queue_free()
	await process_frame
	print("Dash checks: ", checks, ", failures: ", failures)
	quit(0 if failures == 0 else 1)
