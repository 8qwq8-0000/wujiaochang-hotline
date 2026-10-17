extends RefCounted

# Clear each authored area through its real entry trigger before killing its enemies.
static func clear_floor(tree: SceneTree) -> void:
	var player := tree.get_first_node_in_group("player") as PlayerController
	var assembler := tree.current_scene.find_child("FloorAssembler", true, false) as FloorAssembler
	for area in assembler.generated_rooms:
		player.global_position = area.global_position + Vector2(74, 180)
		for frame in 3:
			await tree.physics_frame
		var enemies := tree.get_nodes_in_group("enemies")
		for enemy in enemies:
			enemy.set_physics_process(false)
			enemy.health.apply_damage(enemy.health.max_health, DamagePacket.new())
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.state == EnemyController.State.SELF_DESTRUCT:
				enemy._physics_process(enemy.profile.self_destruct_delay + 0.01)
		await tree.process_frame
		await tree.process_frame
