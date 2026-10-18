extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func run_checks() -> void:
	var arena := load("res://scenes/levels/bosses/rooftop_boss_arena.tscn").instantiate() as RooftopBossArena
	arena.attack_loop_enabled = false
	root.add_child(arena)
	await process_frame
	await process_frame
	check(arena.phase == RooftopBossArena.Phase.MINIONS, "arena starts with dormant phase")
	check(arena.boss.state == RooftopWhaleGoddess.State.DORMANT, "boss is dormant during minion wave")
	check(arena.spawner.required_remaining == 3, "phase one spawns three mandatory guards")
	check(arena.player.camera.limit_right == 960 and arena.player.camera.limit_bottom == 540, "expanded room configures follow camera limits")
	check(arena.room_lighting.phase_light == 0.0, "phase one keeps the chapel lighting dormant")

	var packet := DamagePacket.new()
	packet.base_damage = 99
	packet.source_faction = CombatFaction.Id.PLAYER
	packet.source_position = arena.player.global_position
	for enemy in arena.get_node("Enemies").get_children():
		enemy.health.apply_damage(99, packet)
	# The heavy guard completes its authored self-destruct before reporting defeat.
	await create_timer(0.6).timeout
	check(arena.phase == RooftopBossArena.Phase.AWAKENING, "clearing guards starts awakening")
	await create_timer(arena.boss.awakening_duration + 0.1).timeout
	check(arena.phase == RooftopBossArena.Phase.BOSS_ACTIVE, "awakening enters phase two")
	check(arena.boss.state == RooftopWhaleGoddess.State.ACTIVE, "boss hurtbox activates in phase two")
	check(arena.boss.hurt_box.monitorable, "active boss can receive weapon hits")
	check(arena.boss.body_sprite.texture == arena.boss.dormant_texture, "phase two keeps the dormant statue base texture")
	check(arena.boss.glow_sprite.visible, "phase two is communicated by the colored glow overlay")
	check(arena.room_lighting.phase_light > 0.98, "phase two raises the chapel gold-light layer")

	arena.boss.health.apply_damage(5, packet)
	check(arena.boss.get_halo_segments_remaining() == 0, "five damage breaks all halo segments")
	check(arena.boss.is_core_exposed(), "last health point represents exposed core")
	arena.boss.health.apply_damage(1, packet)
	await process_frame
	check(arena.phase == RooftopBossArena.Phase.CLEARED, "destroying exposed core clears arena")
	check(arena.exit_elevator.enabled, "boss defeat unlocks rooftop exit")

	arena.queue_free()
	await process_frame
	print("Rooftop boss failures: ", failures)
	quit(0 if failures == 0 else 1)
