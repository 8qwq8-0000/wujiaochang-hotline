extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var room := Node2D.new()
	room.add_to_group("combat_rooms")
	root.add_child(room)
	current_scene = room
	var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	room.add_child(player)
	player.global_position = Vector2(400,300)
	player.set_physics_process(false)
	player.weapons.set_physics_process(false)
	player.health.configure_max_health(100)
	var enemy: EnemyController = load("res://scenes/actors/enemies/enemy.tscn").instantiate()
	enemy.profile = load("res://resources/enemies/melee_pressure.tres").duplicate()
	enemy.profile.max_health = 20
	room.add_child(enemy)
	enemy.set_physics_process(false)
	for weapon_id in ["service_pistol", "scattergun", "rail_cannon"]:
		var weapon: WeaponComponentData
		if weapon_id == "rail_cannon":
			weapon = WeaponComponentData.new()
			weapon.id = &"rail_cannon"
			weapon.view_scene = load("res://scenes/weapons/rail_cannon.tscn")
			weapon.attack_kind = WeaponComponentData.AttackKind.PROJECTILE
			weapon.projectile_speed = 520
		else:
			weapon = load("res://resources/weapons/" + weapon_id + ".tres")
		player.equip_weapon(weapon)
		for index in 8:
			var heading := Vector2.RIGHT.rotated(index * PI / 4)
			enemy.global_position = player.global_position + heading * 20
			player.visuals.weapon_pivot.cancel_feedback()
			player.visuals.update_visual(heading, Vector2.ZERO, GuardComponent.State.IDLE, 120, 0, enemy.global_position)
			enemy.health.set_current_health(20)
			enemy.hurt_box.clear_invulnerability()
			player.weapons.reset_transient_state()
			player.heat.current_heat = 0
			await physics_frame
			await physics_frame
			var attack := player._get_attack_transform()
			check(player.weapons.try_attack(attack.origin, attack.x, player), "weapon fires " + weapon_id)
			for frame in 5:
				await physics_frame
			check(enemy.health.current_health < 20, "point blank hit: %s direction %d" % [weapon_id,index])
			check(player.health.current_health == 100, "point blank shot ignores its shooter")
			for child in room.get_children():
				if child is CombatProjectile:
					child.queue_free()
			await process_frame
	# Wall between grip and target must still stop a shot, even at close range.
	player.equip_weapon(load("res://resources/weapons/service_pistol.tres"))
	player.visuals.weapon_pivot.cancel_feedback()
	player.visuals.update_visual(Vector2.RIGHT, Vector2.ZERO, GuardComponent.State.IDLE, 120, 0, player.global_position + Vector2(200,0))
	var grip := player.visuals.get_weapon_mount_global_position()
	var muzzle := player.visuals.get_weapon_muzzle_global_position()
	enemy.global_position = grip.lerp(muzzle, 0.9)
	enemy.health.set_current_health(20)
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(3,40)
	collider.shape = rectangle
	wall.add_child(collider)
	room.add_child(wall)
	wall.global_position = grip.lerp(muzzle, 0.25)
	await physics_frame
	await physics_frame
	player.weapons.reset_transient_state()
	player.heat.current_heat = 0
	var attack := player._get_attack_transform()
	player.weapons.try_attack(attack.origin, attack.x, player)
	for frame in 5:
		await physics_frame
	check(enemy.health.current_health == 20, "point blank origin correction cannot shoot through a wall")
	room.queue_free()
	await process_frame
	print("Point blank shooting checks: ",checks,"; failures: ",failures)
	quit(0 if failures == 0 else 1)
