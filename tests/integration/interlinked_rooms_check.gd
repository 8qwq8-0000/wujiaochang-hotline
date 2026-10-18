extends SceneTree

const SAVE := "user://interlinked_rooms_check.json"
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
	root.get_node("WarehouseStore").save_path = SAVE
	DirAccess.remove_absolute(SAVE)
	root.get_node("RunManager").begin_run(531)
	for id in ["interlinked_apartment", "loading_workshop"]:
		var room: CombatRoom = load("res://scenes/levels/rooms/variants/" + id + ".tscn").instantiate()
		room.configure_stage(0, 2)
		root.add_child(room)
		current_scene = room
		room.activate()
		for enemy in room.get_node("Enemies").get_children():
			enemy.set_physics_process(false)
		check(room.spawner.required_remaining == 6, id + " spawns exactly six mandatory enemies")
		var ranged := 0
		for enemy in room.get_node("Enemies").get_children():
			if enemy.profile.role == EnemyProfile.Role.RANGED_SIGHTLINE:
				ranged += 1
		check(ranged == 2, id + " mixes four melee and two ranged roles")
		var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
		player.position = Vector2(74, 180)
		room.add_child(player)
		player.set_physics_process(false)
		player.heat.set_physics_process(false)
		var camera := Camera2D.new()
		camera.position = Vector2(320, 180)
		room.add_child(camera)
		camera.make_current()
		await settle()
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/hotline-bc-" + id + ".png")
		var doors: Array[Node] = room.find_children("*", "AutomaticDoor", true, false)
		check(doors.size() == (10 if id == "interlinked_apartment" else 9), id + " instantiates every authored doorway")
		for door: AutomaticDoor in doors:
			# Real physics contact, including rotated openings; alternate approach side.
			var normal: Vector2 = door.global_transform.x.normalized()
			if checks % 2 == 0:
				normal = -normal
			player.global_position = door.global_position - normal * 28
			player.velocity = Vector2.ZERO
			await settle()
			for frame in 36:
				player.velocity = normal * 120
				player.move_and_slide()
				await physics_frame
			player.velocity = Vector2.ZERO
			check(door.opened and door.get_node("Body/Shape").disabled, id + " physical contact opens door at " + str(door.position))
			check((player.global_position - door.global_position).dot(normal) > 10, id + " player physically crosses doorway")
		if id == "loading_workshop":
			var window: StaticBody2D = room.get_node("LayoutGeometry/ObservationWindow")
			var center := window.global_position
			var ray := PhysicsRayQueryParameters2D.create(center - Vector2(25,0), center + Vector2(25,0), 1)
			check(room.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(), "observation window allows vision and projectile rays")
			ray.collision_mask = 128
			check(not room.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(), "observation window has a solid actor barrier")
			player.global_position = center - Vector2(25,0)
			await settle()
			for frame in 30:
				player.velocity = Vector2(120,0)
				player.move_and_slide()
				await physics_frame
			check(player.global_position.x < center.x - 5, "player cannot walk through observation window")
			var enemy: EnemyController = load("res://scenes/actors/enemies/enemy.tscn").instantiate()
			enemy.profile = load("res://resources/enemies/melee_pressure.tres")
			enemy.position = center + Vector2(35,0)
			room.get_node("Enemies").add_child(enemy)
			enemy.set_physics_process(false)
			await settle()
			var before := enemy.health.current_health
			var shot: CombatProjectile = load("res://scenes/combat/projectile.tscn").instantiate()
			shot.position = center - Vector2(20,0)
			shot.setup(player, CombatFaction.Id.PLAYER, Vector2.RIGHT, 1, 420)
			room.add_child(shot)
			await create_timer(0.25).timeout
			check(enemy.health.current_health == before - 1, "actual projectile crosses observation window and damages enemy")
		room.queue_free()
		await settle()
	DirAccess.remove_absolute(SAVE)
	print("Interlinked room checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
