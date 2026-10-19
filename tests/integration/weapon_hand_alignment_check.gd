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
	root.add_child(room)
	current_scene = room
	var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	room.add_child(player)
	player.set_physics_process(false)
	player.get_node("Camera2D").enabled = false
	for id in ["service_pistol", "scattergun", "rail_cannon"]:
		var data := WeaponComponentData.new()
		data.id = id
		data.view_scene = load("res://scenes/weapons/"+id+".tscn")
		player.weapons.equip_weapon(data)
		var mount := player.visuals.weapon_pivot
		mount.current_view.cancel_feedback()
		for moving in [false,true]:
			for step in 8:
				var direction := Vector2.RIGHT.rotated(step*PI/4)
				var target := player.global_position + direction*240
				player.visuals.update_visual(direction,Vector2(100,0) if moving else Vector2.ZERO,GuardComponent.State.IDLE,120,0,target)
				var expected_direction: String = player.visuals._direction_name(direction)
				check(player.visuals.body_sprite.animation == StringName("walk_" + expected_direction), "standing and moving body face the aim direction")
				check(player.visuals.wrist_socket.facing == StringName(expected_direction), "wrist uses the same direction as the body")
				check(player.visuals.body_sprite.is_playing() == moving, "only moving plays the locomotion animation")
				player.visuals.body_sprite.pause()
				for frame in (6 if moving else 1):
					if moving:
						player.visuals.body_sprite.frame = frame
					player.visuals.update_visual(direction,Vector2(100,0) if moving else Vector2.ZERO,GuardComponent.State.IDLE,120,0,target)
					check(mount.current_view.global_position.is_equal_approx(player.visuals.wrist_socket.global_position),id+" wrist lock follows animated wrist in every direction")
					var muzzle := mount.get_muzzle_global_position()
					var axis := mount.global_transform.x.normalized()
					check(absf(axis.cross((target-muzzle).normalized())) < 0.001 and axis.dot(target-muzzle)>0,id+" barrel points at target from real muzzle")
					var shot := player._get_attack_transform()
					check(shot.origin.is_equal_approx(muzzle) and shot.x.is_equal_approx(axis),id+" shot uses actual muzzle and barrel axis")
					check(mount.scale.abs().is_equal_approx(Vector2.ONE),id+" pivot mirrors without resizing")
	var visuals := player.visuals
	visuals.update_visual(Vector2.UP, Vector2.ZERO, GuardComponent.State.IDLE, 120)
	visuals.update_visual(Vector2.UP, Vector2.RIGHT * 100, GuardComponent.State.IDLE, 120)
	check(visuals.body_sprite.is_playing(), "walking resumes after standing with the same facing")
	visuals.body_sprite.frame = 3
	visuals.update_visual(Vector2.UP, Vector2.ZERO, GuardComponent.State.IDLE, 120)
	check(not visuals.body_sprite.is_playing() and visuals.body_sprite.frame == 0, "stopping freezes the planted directional pose")
	room.queue_free()
	await process_frame
	print("Weapon wrist checks: ",checks,"; failures: ",failures)
	quit(0 if failures==0 else 1)
