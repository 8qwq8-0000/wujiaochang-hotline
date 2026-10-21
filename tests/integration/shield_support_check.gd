extends SceneTree

const ENEMY := preload("res://scenes/actors/enemies/enemy.tscn")
const PLAYER := preload("res://scenes/actors/player/player.tscn")
const SHOT := preload("res://scenes/combat/projectile.tscn")
var checks := 0
var failures := 0
var room: Node2D


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame


func capture(heading: String) -> void:
	if DisplayServer.get_name() == "headless" or not "--capture" in OS.get_cmdline_user_args():
		return
	DirAccess.make_dir_recursive_absolute("/tmp/hotline-barrier-v2")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/hotline-barrier-v2/" + heading + ".png")


func robot(profile_id: String, point: Vector2, initial_cooldown: float = 0.0) -> EnemyController:
	var enemy := ENEMY.instantiate() as EnemyController
	enemy.profile = load("res://resources/enemies/" + profile_id + ".tres").duplicate()
	enemy.profile.barrier_initial_cooldown = initial_cooldown
	enemy.profile.self_destruct_enabled = false
	enemy.position = point
	room.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy


func run() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
	room = Node2D.new()
	room.add_to_group("combat_rooms")
	root.add_child(room)
	current_scene = room
	var background := ColorRect.new()
	background.color = Color("17242e")
	background.size = Vector2(800, 600)
	background.z_index = -20
	room.add_child(background)
	var region := NavigationRegion2D.new()
	var polygon := NavigationPolygon.new()
	polygon.vertices = PackedVector2Array([Vector2.ZERO, Vector2(800, 0), Vector2(800, 600), Vector2(0, 600)])
	polygon.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_polygon = polygon
	room.add_child(region)
	await frames(3)
	var target := Node2D.new()
	room.add_child(target)
	for heading in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		var enemy := robot("heavy_anchor", Vector2(320, 240))
		target.position = enemy.position + heading * 120
		var skill := enemy.barrier_skill
		var direction_name := enemy.visuals.direction_name(heading)
		check(skill.try_cast(target), "cardinal cast starts " + direction_name)
		check(skill.visual.animation == StringName("cast_barrier_" + direction_name), "body animation follows actual heading")
		check(skill.flight_visual.animation == StringName("flight_" + direction_name), "detached effect follows actual heading")
		check(skill.visual.sprite_frames.get_frame_count(skill.visual.animation) == 8, "each direction has eight casting frames")
		check(skill.barrier.collision_layer == 0, "windup has no invisible blocking")
		skill.tick(0.4)
		var origin := skill.barrier.global_position
		skill.tick(0.2)
		check(skill.barrier.global_position.is_equal_approx(origin + heading * 12), "shield travels independently at configured speed")
		check(enemy.position.is_equal_approx(Vector2(320, 240)), "caster remains planted while shield flies")
		check(skill.barrier.visible and skill.barrier.collision_layer == 256, "flight art and collision are active together")
		check(not skill.visual.visible and enemy.sprite.visible, "launch replaces cut-sheet recovery with clean native idle body")
		await capture(direction_name)
		var flight_point := skill.barrier.global_position
		enemy.position += Vector2(13, 7)
		check(skill.barrier.global_position.is_equal_approx(flight_point), "barrier world transform is detached from caster")
		var wall := StaticBody2D.new()
		wall.collision_layer = 1
		var collider := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(160, 8) if absf(heading.y) > 0 else Vector2(8, 160)
		collider.shape = box
		wall.add_child(collider)
		wall.position = flight_point + heading * 65
		room.add_child(wall)
		await frames(2)
		skill.tick(1.0)
		check(not skill.casting and not skill.barrier.visible and skill.barrier.collision_layer == 0, "full-width wall sweep ends flying shield")
		check((skill.barrier.global_position - flight_point).dot(heading) < 65, "flying shield does not tunnel through wall")
		wall.queue_free()
		enemy.queue_free()
		await frames(2)
	# A ranged unit must actually reach the rear slot before attacking.
	var shield := robot("heavy_anchor", Vector2(320, 240), 2.0)
	target.position = Vector2(320, 130)
	shield._target = target
	shield.facing = Vector2.UP
	check(not shield.barrier_skill.try_cast(target), "initial two-second cooldown prevents immediate cast")
	var ranged := robot("ranged_sightline", Vector2(385, 275))
	ranged._target = target
	ranged.facing = Vector2.UP
	ranged.profile.full_room_awareness = true
	shield.barrier_skill.cooldown = 1.01
	check(not ranged._tick_shield_cover(0.01, true), "ranged does not seek cover before final cooldown second")
	shield.barrier_skill.tick(0.02)
	check(ranged._tick_shield_cover(0.01, true), "ranged starts moving during final second before cast")
	shield.barrier_skill.tick(1.0)
	check(shield.barrier_skill.try_cast(target), "initial cooldown expires before first cast")
	var start := ranged.position
	# Advance real movement callbacks; no teleporting the ranged unit into cover.
	for i in 150:
		ranged._physics_process(1.0 / 60.0)


		await frames(1)
	check(ranged.position.distance_to(start) > 20, "ranged robot physically runs into cover")
	check(ranged._cover_shield == shield and ranged.position.distance_to(ranged._cover_goal) <= 23, "ranged reaches a rear shield slot")
	check((ranged.position - shield.position).dot(Vector2.UP) < -24, "cover is behind soldier relative to player")
	var fired := false
	for child in room.get_children():
		if child is CombatProjectile and child.source == ranged:
			fired = true
	check(fired, "ranged fires at player after reaching rear cover")
	shield.barrier_skill.cancel()
	shield.barrier_skill.cooldown = 5.0
	ranged._physics_process(0.02)
	check(ranged._cover_shield == null, "ranged returns to ordinary tactics when shield ends")
	# Same-faction immunity covers health, knockback and non-consuming bullets.
	var packet := DamagePacket.new()
	packet.base_damage = 20
	packet.source_faction = CombatFaction.Id.ENEMY
	packet.knockback = Vector2(200, 0)
	var hp := shield.health.current_health
	shield.velocity = Vector2.ZERO
	var result := shield.hurt_box.receive_hit(packet)
	check(result.final_damage == 0 and shield.health.current_health == hp and shield.velocity == Vector2.ZERO, "enemy friendly fire cannot damage or knock back allies")
	var player := PLAYER.instantiate() as PlayerController
	room.add_child(player)
	player.set_physics_process(false)
	player.position = Vector2(600, 120)
	player.health.configure_max_health(20)
	player.hurt_box.clear_invulnerability()
	shield.position = Vector2(600, 210)
	ranged.position = Vector2(650, 270)
	var bullet := SHOT.instantiate() as CombatProjectile
	room.add_child(bullet)
	bullet.position = Vector2(600, 280)
	bullet.setup(ranged, CombatFaction.Id.ENEMY, Vector2.UP, 1, 500)
	await frames(30)
	check(shield.health.current_health == hp, "enemy bullet passes through shield soldier without ally damage")
	check(player.health.current_health == 19, "same bullet continues through ally and damages player")
	packet.source_faction = CombatFaction.Id.PLAYER
	packet.base_damage = 1
	shield.hurt_box.receive_hit(packet)
	check(shield.health.current_health == hp - 1, "player damage against enemies is retained")
	room.queue_free()
	await frames(2)
	print("Shield support checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
