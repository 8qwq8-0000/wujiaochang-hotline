extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func run_checks() -> void:
	var scene: Node = load("res://scenes/levels/inventory_test_room.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var player := get_first_node_in_group("player") as PlayerController
	if player == null:
		quit(1)
		return
	player.set_physics_process(false)
	player.weapons.set_physics_process(false)
	player.heat.set_physics_process(false)
	var mount := player.get_node("VisualRoot/WeaponPivot") as WeaponMount
	check(mount != null and mount.current_view != null, "player mounts a weapon view")
	check(mount.current_view.scene_file_path == mount.current_data.view_scene.resource_path, "initially equipped weapon uses its configured view")
	check(mount.get_child_count() == 1, "only the active weapon view is instantiated")

	check(player.inventory.pickup("pistol"), "pistol enters reserve slot")
	player.weapons.select_weapon(1)
	await process_frame
	check(mount.current_data.id == &"service_pistol", "switch replaces the active weapon view")
	check(mount.current_view.name == "ServicePistolView", "pistol uses its configured scene")
	check(mount.get_child_count() == 1, "old weapon view is removed immediately")

	var mount_origin := mount.global_position
	var muzzle_origin := mount.get_muzzle_global_position()
	check(muzzle_origin.distance_to(mount_origin) > 20.0, "configured muzzle is offset from the grip")
	player.weapons.reset_transient_state()
	player.heat.current_heat = 0.0
	check(player.weapons.try_attack(muzzle_origin, Vector2.RIGHT, player), "pistol fires from configured muzzle")
	var projectile: CombatProjectile
	for child in scene.get_children():
		if child is CombatProjectile:
			projectile = child
	check(projectile != null, "pistol creates a projectile")
	if projectile != null:
		check(projectile.global_position.is_equal_approx(muzzle_origin), "projectile begins at muzzle socket")
		projectile.queue_free()
	var heat_after_attack := player.heat.current_heat
	var cooldown_after_attack: float = player.weapons.get("_cooldown_remaining")
	mount.play_attack()
	check(is_equal_approx(player.heat.current_heat, heat_after_attack), "visual feedback does not alter heat")
	check(is_equal_approx(player.weapons.get("_cooldown_remaining"), cooldown_after_attack), "visual feedback does not alter cooldown")

	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(4, 20)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	scene.add_child(wall)
	wall.global_position = mount_origin.lerp(muzzle_origin, 0.5)
	await physics_frame
	var clamped := player.weapons.clamp_projectile_origin(mount_origin, muzzle_origin)
	check(clamped.distance_to(mount_origin) < muzzle_origin.distance_to(mount_origin), "wall clamps muzzle origin")
	wall.queue_free()

	var missing := WeaponComponentData.new()
	missing.id = &"missing_view_fixture"
	mount.set_weapon(missing)
	check(mount.current_view != null, "missing scene uses fallback view")
	check(mount.current_view.name == "WeaponView", "fallback is the generic weapon view")

	scene.queue_free()
	await process_frame
	print("Weapon scene failures: ", failures)
	quit(0 if failures == 0 else 1)
