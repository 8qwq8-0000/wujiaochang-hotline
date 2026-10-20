extends SceneTree

const ENEMY := preload("res://scenes/actors/enemies/enemy.tscn")
const PROFILES := ["melee_pressure", "ranged_sightline", "heavy_anchor"]
const DIRECTIONS := [Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2.RIGHT]
const DIRECTION_NAMES := ["down", "left", "up", "right"]
var checks := 0
var failures := 0
var room: Node2D
var player: PlayerController


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func spawn(role: int, position: Vector2) -> EnemyController:
	var enemy: EnemyController = ENEMY.instantiate()
	enemy.profile = load("res://resources/enemies/" + PROFILES[role] + ".tres").duplicate()
	enemy.profile.patrol_enabled = false
	enemy.position = position
	room.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.visuals.set_process(false)
	return enemy


func capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


func run() -> void:
	root.size = Vector2i(640, 360)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
	room = Node2D.new()
	room.add_to_group("combat_rooms")
	root.add_child(room)
	current_scene = room
	player = load("res://scenes/actors/player/player.tscn").instantiate()
	room.add_child(player)
	player.set_physics_process(false)
	player.camera.enabled = false
	player.health.configure_max_health(100)
	await physics_frame
	for role in 3:
		var enemy := spawn(role, Vector2(320, 180))
		check(enemy.visuals.role_key == ["melee", "ranged", "shield"][role], "each role selects its own animation atlas")
		var offset := enemy.sprite.offset
		var scale := enemy.sprite.scale
		for index in 4:
			var direction: Vector2 = DIRECTIONS[index]
			var name: String = DIRECTION_NAMES[index]
			enemy.state = EnemyController.State.IDLE
			enemy.facing = direction
			enemy.visuals.update_visual(0.0)
			check(enemy.visuals.current_animation == "idle_" + name and not enemy.sprite.flip_h, "authored " + name + " idle preserves weapon hand")
			# Real body displacement selects the walk loop, not velocity into a wall.
			enemy.state = EnemyController.State.CHASE
			for step in 12:
				enemy.position += direction * 0.2
				enemy.visuals.update_visual(0.11)
				check(enemy.visuals.current_animation == "walk_" + name, "movement advances the correct directional walk")
				check(enemy.sprite.offset == offset and enemy.sprite.scale == scale, "all frames keep exactly the same root and scale")
			enemy.visuals.update_visual(0.2)
			check(enemy.visuals.current_animation == "idle_" + name, "stopped body stops walking even in chase state")
			player.position = enemy.position + direction * 22.0
			player.hurt_box.clear_invulnerability()
			enemy._target = player
			enemy._attack_direction = direction
			enemy.state = EnemyController.State.WINDUP
			enemy._windup_remaining = enemy.profile.attack_windup * 0.5
			var before := player.health.current_health
			enemy.visuals.update_visual(0.0)
			check(enemy.visuals.current_animation == "attack_" + name and enemy.visuals.current_frame < 3, "windup shows anticipation, never contact")
			check(player.health.current_health == before, "visual anticipation never applies damage")
			enemy.state = EnemyController.State.ATTACK
			enemy.perform_attack()
			check(enemy.visuals.current_animation == "attack_" + name and enemy.visuals.current_frame == 3, "real hit/shot callback displays the contact frame immediately")
			if role == 1:
				var shots: Array[Node] = []
				for child in room.get_children():
					if child is CombatProjectile and not child.is_queued_for_deletion():
						shots.append(child)
				check(not shots.is_empty(), "firing frame creates a real projectile")
				for shot in shots:
					check(shot.direction.is_equal_approx(direction), "visual firing direction matches actual projectile heading")
					shot.queue_free()
			else:
				check(player.health.current_health == before - 1, "baton/shield contact applies exactly the existing one damage")
			enemy.visuals.update_visual(0.04)
			var frozen_frame := enemy.visuals.current_frame
			var frozen_time: float = enemy.visuals._impact_remaining
			enemy.visuals.set_process(true)
			paused = true
			await physics_frame
			await physics_frame
			check(enemy.visuals.current_frame == frozen_frame and is_equal_approx(enemy.visuals._impact_remaining, frozen_time), "pause freezes the actual visual process and impact clock")
			paused = false
			enemy.visuals.set_process(false)
			enemy.visuals.update_visual(0.5)
			check(enemy.visuals.current_frame == 5, "attack recovers to the authored final frame")
			enemy.apply_stagger(0.2)
			enemy.visuals.update_visual(0.0)
			check(enemy.visuals._impact_remaining == 0.0 and enemy.visuals.current_animation.begins_with("idle_"), "stagger cancels the attack animation")
			enemy._stagger_remaining = 0.0
			await physics_frame
		# A shield is artwork, never an invulnerability source.
		if role == 2:
			check(enemy.health.max_health == 3, "ordinary shield soldier is a three-health enemy")
			for direction in DIRECTIONS:
				enemy.health.set_current_health(3)
				var packet := DamagePacket.new()
				packet.source_faction = CombatFaction.Id.PLAYER
				packet.source_position = enemy.global_position + direction * 30.0
				packet.base_damage = 1
				var result := enemy.hurt_box.receive_hit(packet)
				check(not result.blocked and result.final_damage == 1 and enemy.health.current_health == 2, "shield soldier takes full damage from every side")
		# Actual death signal must interrupt any attack.
		enemy.health.apply_damage(99, DamagePacket.new())
		enemy.visuals.update_visual(0.0)
		check(enemy.visuals._impact_remaining == 0.0, "death cancels attack presentation")
		enemy.queue_free()
		await process_frame
	player.hide()
	await render_review()
	room.queue_free()
	await process_frame
	await real_floor_check()
	print("Enemy animation checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)


func render_review() -> void:
	var background := ColorRect.new()
	background.color = Color("17242e")
	background.size = Vector2(640, 360)
	background.z_index = -10
	room.add_child(background)
	var preview_enemies: Array[EnemyController] = []
	for role in 3:
		var title := Label.new()
		title.text = ["MELEE / BATON", "RANGED / RIFLE", "HEAVY / SHIELD SLAM"][role]
		title.position = Vector2(16, 15 + role * 110)
		title.add_theme_font_size_override("font_size", 10)
		room.add_child(title)
		for index in 4:
			var enemy := spawn(role, Vector2(115 + index * 140, 88 + role * 110))
			enemy.facing = DIRECTIONS[index]
			enemy.visuals.update_visual(0.0)
			preview_enemies.append(enemy)
	await capture("/tmp/hotline-enemy-animation-idle.png")
	for frame in 6:
		for enemy in preview_enemies:
			enemy.visuals._show("attack_" + enemy.visuals.direction_name(enemy.facing), frame)
		await capture("/tmp/hotline-enemy-animation-attack-%d.png" % frame)


func real_floor_check() -> void:
	var run_manager := root.get_node("RunManager")
	run_manager.begin_run(73517)
	var main: Node = load("res://scenes/bootstrap/main.tscn").instantiate()
	main.get_node("SceneFlow").fade_duration = 0.0
	root.add_child(main)
	current_scene = main
	for frame in 600:
		await physics_frame
		if get_nodes_in_group("enemies").size() == 6 and not main.get_node("SceneFlow")._is_loading:
			break
	var enemies := get_nodes_in_group("enemies")
	check(enemies.size() == 6, "production floor retains six enemies in the activated area")
	for enemy: EnemyController in enemies:
		check(enemy.visuals != null and enemy.sprite.sprite_frames != null, "production-spawned enemy has a real animation texture")
	var live_player := get_first_node_in_group("player") as PlayerController
	check(live_player != null, "production main scene finishes loading the real player")
	if live_player == null:
		main.queue_free()
		await process_frame
		return
	live_player.hurt_box.set_invulnerable(5.0)
	# Capture a real encounter after AI has chased/patrolled over real frames.
	live_player.position = Vector2(420, 260)
	for frame in 90:
		await physics_frame
	await capture("/tmp/hotline-enemy-animation-gameplay.png")
	main.queue_free()
	await process_frame
	await process_frame
