extends SceneTree

const ENEMY := preload("res://scenes/actors/enemies/enemy.tscn")
const PROJECTILE := preload("res://scenes/combat/projectile.tscn")
var failures := 0
var checks := 0
var room: Node2D
var enemy: EnemyController


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func shot(origin: Vector2, heading: Vector2, faction: CombatFaction.Id = CombatFaction.Id.PLAYER, speed: float = 600.0) -> CombatProjectile:
	var bullet := PROJECTILE.instantiate() as CombatProjectile
	room.add_child(bullet)
	bullet.global_position = origin
	bullet.setup(null, faction, heading, 1, speed)
	return bullet


func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless" or not "--capture" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/shield_skill_" + name + ".png")


func wait_physics(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame


func run() -> void:
	room = Node2D.new()
	room.add_to_group("combat_rooms")
	root.add_child(room)
	current_scene = room
	enemy = ENEMY.instantiate() as EnemyController
	enemy.profile = preload("res://resources/enemies/heavy_anchor.tres").duplicate()
	enemy.profile.self_destruct_enabled = false
	enemy.position = Vector2(200, 200)
	room.add_child(enemy)
	enemy.set_physics_process(false)
	var target := Node2D.new()
	target.position = Vector2(200, 300)
	room.add_child(target)
	var skill := enemy.barrier_skill
	await wait_physics(2)
	check(skill.try_cast(target), "shield can start cast")
	check(not enemy.sprite.visible and skill.visual.visible and skill.visual.is_playing(), "native cast sprite replaces normal body")
	check(skill.barrier.collision_layer == 0, "windup cannot block bullets")
	var seen := {}
	for i in 5:
		await create_timer(0.08).timeout
		seen[skill.visual.frame] = true
	check(seen.size() >= 3, "cast plays through distinct authored frames")
	skill.tick(0.4)
	check(skill.deployed and skill.visual.frame >= 4, "physics deployment matches shield expansion pose")
	await wait_physics(2)
	await capture("deployed")
	var hp := enemy.health.current_health
	var front := shot(Vector2(200, 270), Vector2.UP)
	await wait_physics(12)
	check(not is_instance_valid(front) and enemy.health.current_health == hp, "front shot absorbed before body damage")
	var fast := shot(Vector2(220, 290), Vector2.UP, CombatFaction.Id.PLAYER, 12000)
	await wait_physics(3)
	check(not is_instance_valid(fast), "swept ray blocks a shot crossing entire barrier in one tick")
	var friendly := shot(Vector2(235, 270), Vector2.UP, CombatFaction.Id.ENEMY)
	await wait_physics(9)
	check(is_instance_valid(friendly), "enemy bullet passes barrier")
	if is_instance_valid(friendly):
		friendly.queue_free()
	var rear := shot(Vector2(200, 160), Vector2.DOWN)
	await wait_physics(8)
	check(not is_instance_valid(rear) and enemy.health.current_health == hp - 1, "rear shot hits shield soldier despite active barrier")
	skill.tick(2.99)
	check(skill.casting, "barrier stays active for full three seconds after deployment")
	skill.tick(0.02)
	check(not skill.casting and skill.barrier.collision_layer == 0 and enemy.sprite.visible, "expiry disables physics and restores normal sprite")
	check(not skill.try_cast(target), "cooldown prevents immediate recast")
	await wait_physics(2)
	shot(Vector2(200, 270), Vector2.UP)
	await wait_physics(12)
	check(enemy.health.current_health == hp - 2, "expired barrier lets front shots damage body again")
	skill.tick(3.0)
	check(skill.try_cast(target), "six second cooldown allows recast")
	skill.tick(0.4)
	enemy.apply_stagger(0.2)
	check(not skill.casting and skill.barrier.collision_layer == 0, "stagger interrupts skill and removes collision")
	enemy.state = EnemyController.State.IDLE
	skill.cooldown = 0.0
	skill.try_cast(target)
	skill.tick(0.4)
	await wait_physics(2)
	enemy.profile.self_destruct_enabled = true
	shot(Vector2(200, 160), Vector2.DOWN)
	await wait_physics(8)
	check(enemy.state == EnemyController.State.SELF_DESTRUCT and not skill.casting and skill.barrier.collision_layer == 0, "fatal rear bullet clears shield before delayed self destruction")
	for heading in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var directional := ENEMY.instantiate() as EnemyController
		directional.profile = preload("res://resources/enemies/heavy_anchor.tres").duplicate()
		directional.position = Vector2(400, 200)
		room.add_child(directional)
		directional.set_physics_process(false)
		target.position = directional.position + heading * 100.0
		directional.barrier_skill.try_cast(target)
		directional.barrier_skill.tick(0.4)
		await wait_physics(2)
		var directional_shot := shot(directional.position + heading * 80.0, -heading)
		await wait_physics(10)
		check(not is_instance_valid(directional_shot) and directional.health.current_health == 3, "barrier faces cast target in direction " + str(heading))
		directional.queue_free()
		await process_frame
	# Also exercise real AI acquisition rather than only the component API.
	var auto_enemy := ENEMY.instantiate() as EnemyController
	auto_enemy.profile = preload("res://resources/enemies/heavy_anchor.tres").duplicate()
	auto_enemy.position = Vector2(400, 200)
	auto_enemy.initial_facing = Vector2.DOWN
	room.add_child(auto_enemy)
	auto_enemy.set_physics_process(false)
	target.position = Vector2(400, 280)
	auto_enemy._target = target
	auto_enemy._physics_process(0.02)
	check(auto_enemy.barrier_skill.casting, "visible player triggers skill from enemy AI")
	check(auto_enemy.velocity.is_zero_approx(), "casting stops enemy navigation")
	room.queue_free()
	await process_frame
	await process_frame
	print("Shield barrier checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
