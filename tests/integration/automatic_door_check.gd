extends SceneTree
var failures := 0
var checks := 0
var room: Node2D
func _initialize() -> void:
	call_deferred("run_checks")
func check(value: bool,message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func enemy_at(point: Vector2,parent: Node = null) -> EnemyController:
	var enemy: EnemyController = load("res://scenes/actors/enemies/enemy.tscn").instantiate()
	enemy.position = point
	enemy.profile = load("res://resources/enemies/melee_pressure.tres").duplicate()
	enemy.profile.max_health = 8
	(parent if parent != null else room).add_child(enemy)
	enemy.set_physics_process(false)
	return enemy
func door_at(point: Vector2, opening_width: float = 64.0) -> AutomaticDoor:
	var door: AutomaticDoor = load("res://scenes/environment/automatic_door.tscn").instantiate()
	door.position = point
	door.configure_opening_width(opening_width)
	room.add_child(door)
	return door
func approach(player: PlayerController,door: AutomaticDoor,direction: Vector2) -> void:
	for frame in 90:
		player.mobility.tick(player,direction,direction,1.0/60)
		await physics_frame
		if door.opened:
			break
	await process_frame
func run_checks() -> void:
	root.get_node("WarehouseStore").save_path = "user://bc_automatic_door_check.json"
	DirAccess.remove_absolute("user://bc_automatic_door_check.json")
	room = Node2D.new()
	room.add_to_group("combat_rooms")
	root.add_child(room)
	current_scene = room
	var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	player.position = Vector2(140,350)
	room.add_child(player)
	player.set_physics_process(false)
	var walking := door_at(Vector2(200,350))
	var walk_target := enemy_at(Vector2(240,350))
	var breach_radii: Array[float] = []
	root.get_node("CombatEvents").noise_emitted.connect(func(source: Node, origin: Vector2, radius: float) -> void:
		if source == player and origin.distance_to(walking.global_position) < 2.0:
			breach_radii.append(radius)
	)
	await physics_frame
	await physics_frame
	player.weapons.set_equipped_weapon(load("res://resources/weapons/service_pistol.tres"))
	player.weapons.try_attack(Vector2(155,350),Vector2.RIGHT,player)
	await create_timer(0.3).timeout
	check(not walking.opened and walk_target.health.current_health == 8,"closed door blocks projectile without damage/destruction")
	await approach(player,walking,Vector2.RIGHT)
	check(walking.opened and not walking.slammed and walking.knocked_count == 0,"real walking contact opens door without knockdown")
	check(breach_radii == [96.0], "ordinary breach emits only the restrained 96-pixel investigation noise")
	check(walking.find_children("DoorFragment*", "Sprite2D", true, false).size() >= 4, "breach uses cut pieces of the closed door texture")
	await physics_frame
	check(walking.get_node("Body/Shape").disabled,"open door removes blocking collider")
	player.weapons.try_attack(Vector2(205,350),Vector2.RIGHT,player)
	await create_timer(0.2).timeout
	check(walk_target.health.current_health == 7,"open doorway permits projectile")
	var dash := door_at(Vector2(400,150))
	var behind := enemy_at(Vector2(435,150))
	var front := enemy_at(Vector2(365,180))
	var side := enemy_at(Vector2(430,220))
	var far := enemy_at(Vector2(480,150))
	var covered := enemy_at(Vector2(435,125))
	var other := Node2D.new()
	other.add_to_group("combat_rooms")
	root.add_child(other)
	var isolated := enemy_at(Vector2(435,150),other)
	var wall := StaticBody2D.new()
	wall.position = Vector2(420,125)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(8,20)
	collider.shape = shape
	wall.add_child(collider)
	room.add_child(wall)
	player.position = Vector2(350,150)
	player.velocity = Vector2.ZERO
	player.equip_mobility(load("res://resources/mobility/wheel.tres"))
	await physics_frame
	await physics_frame
	check(player.mobility.activate_ability(player,Vector2.RIGHT),"real wheel impulse activates")
	await approach(player,dash,Vector2.RIGHT)
	check(dash.opened and dash.slammed and dash.knocked_count == 1,"real dash contact knocks only door-side visible target")
	check(behind.state == EnemyController.State.STAGGERED and behind.health.current_health == 8,"door knockdown interrupts without adding damage")
	check(front.state != EnemyController.State.STAGGERED and side.state != EnemyController.State.STAGGERED and far.state != EnemyController.State.STAGGERED and covered.state != EnemyController.State.STAGGERED and isolated.state != EnemyController.State.STAGGERED,"front, flank, range, walls and room scope excluded")
	var stagger: float = behind.get("_stagger_remaining")
	behind.set_physics_process(true)
	paused = true
	await create_timer(0.3,true).timeout
	check(is_equal_approx(behind.get("_stagger_remaining"),stagger),"knockdown pauses with game")
	paused = false
	await create_timer(0.85).timeout
	check(behind.state != EnemyController.State.STAGGERED,"enemy recovers after knockdown duration")
	dash._on_contact(player)
	check(dash.knocked_count == 1,"open door never repeats knockdown")
	var reverse := door_at(Vector2(600,150))
	var reverse_target := enemy_at(Vector2(565,150))
	player.position = Vector2(650,150)
	player.velocity = Vector2.ZERO
	player.mobility.reset_transient_state()
	await physics_frame
	await physics_frame
	player.mobility.activate_ability(player,Vector2.LEFT)
	await approach(player,reverse,Vector2.LEFT)
	check(reverse.opened and reverse.slammed and reverse_target.state == EnemyController.State.STAGGERED,"dash works from reverse side")
	var enemy_door := door_at(Vector2(800,150), 96.0)
	var approaching := enemy_at(Vector2(750,150))
	await physics_frame
	await physics_frame
	check(enemy_door.scale.is_equal_approx(Vector2.ONE), "wide doorway keeps the door leaf at its authored aspect ratio")
	check((enemy_door.get_node("Body/Shape").shape as RectangleShape2D).size.y == 96.0, "wide doorway expands the blocking collision instead of scaling the art")
	check((enemy_door.get_node("Contact/Shape").shape as RectangleShape2D).size.y == 104.0, "wide doorway expands its contact area with the collision")
	var maximum_enemy_step := 0.0
	for frame in 60:
		var before := approaching.global_position
		approaching.velocity = Vector2(100,0)
		approaching.move_and_slide()
		maximum_enemy_step = maxf(maximum_enemy_step, approaching.global_position.distance_to(before))
		await physics_frame
		if enemy_door.opened:
			break
	check(enemy_door.opened and not enemy_door.slammed,"ordinary enemy contact also opens door")
	check(maximum_enemy_step <= 4.0, "enemy opens a door without an abnormal breach lunge")
	room.queue_free()
	other.queue_free()
	await process_frame
	print("Automatic door checks: ",checks,"; failures: ",failures)
	DirAccess.remove_absolute("user://bc_automatic_door_check.json")
	quit(0 if failures == 0 else 1)
