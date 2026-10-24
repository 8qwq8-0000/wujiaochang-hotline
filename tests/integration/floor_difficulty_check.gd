extends SceneTree

const MAPS := ["interlinked_apartment", "loading_workshop", "freight_atrium", "dual_track_depot"]
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	await physics_frame
	await physics_frame
	await process_frame

func run() -> void:
	var manager := root.get_node("RunManager")
	for map_name in MAPS:
		for step in 3:
			for seed_value in 3:
				manager.begin_run(400 + seed_value)
				manager.floor_index = step
				var floor_node := Node2D.new()
				root.add_child(floor_node)
				current_scene = floor_node
				var assembler := FloorAssembler.new()
				assembler.room_count = 2
				assembler.sequential_progression = true
				assembler.room_pool.append(load("res://resources/rooms/templates/" + map_name + ".tres"))
				floor_node.add_child(assembler)
				await settle()
				check(manager.mandatory_enemies_remaining == (6 + step) * 2, "%s floor %d includes both regions in objective count" % [map_name, step + 1])
				for room: CombatRoom in assembler.generated_rooms:
					check(room.spawner.remaining_objectives() == 6 + step, "%s floor %d region %d has planned 6/7/8 enemies" % [map_name, step + 1, room.area_index + 1])
					room.activate()
					var navigation_map := room.get_world_2d().navigation_map
					var region: NavigationRegion2D = room.get_node("NavigationRegion2D")
					var entrance := room.to_global(Vector2(111, 270))
					for frame in 60:
						if NavigationServer2D.map_get_closest_point_owner(navigation_map, entrance) == region.get_rid():
							break
						await physics_frame
					var enemies := room.get_node("Enemies").get_children()
					check(enemies.size() == 6 + step, "actual spawn count matches plan")
					var markers := room.get_node("EnemySpawnPoints").get_children()
					for index in enemies.size():
						var enemy: EnemyController = enemies[index]
						enemy.set_physics_process(false)
						var base_profile: EnemyProfile = markers[index].profile
						check(enemy.health.max_health == base_profile.max_health + step and enemy.health.current_health == enemy.health.max_health, "spawned enemy has floor-scaled full health")
						if index >= 6:
							var map_rid := room.get_world_2d().navigation_map
							var path := NavigationServer2D.map_get_path(map_rid, room.to_global(Vector2(111, 270)), enemy.global_position, true)
							check(path.size() >= 2 and path[-1].distance_to(enemy.global_position) < 5, "%s seed %d floor %d region %d extra spawn %s reachable; path=%s" % [map_name, seed_value, step + 1, room.area_index, enemy.position, path])
					for turret in get_nodes_in_group("sentry_turrets"):
						turret.set_physics_process(false)
					# All planned enemies must die before this region clears.
					for index in enemies.size():
						var enemy: EnemyController = enemies[index]
						var packet := DamagePacket.new()
						packet.source_faction = CombatFaction.Id.PLAYER
						packet.base_damage = 100
						packet.blockable = false
						enemy.hurt_box.receive_hit(packet)
						if enemy.state == EnemyController.State.SELF_DESTRUCT:
							enemy._tick_self_destruct(1.0)
						check(room.cleared == (index == enemies.size() - 1), "clear waits for every additional enemy")
				check(manager.mandatory_enemies_remaining == 0, "all region kills clear floor objectives")
				floor_node.queue_free()
				await settle()
	# Shared source assets must remain at their original values after higher floors.
	check(load("res://resources/enemies/melee_pressure.tres").max_health == 1, "melee source profile unchanged")
	check(load("res://resources/enemies/heavy_anchor.tres").max_health == 3, "shield source profile unchanged")
	print("Floor difficulty checks: ", checks, "; failures: ", failures)
	quit(1 if failures else 0)
