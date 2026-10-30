@tool
extends McpTestSuite


func suite_name() -> String:
	return "combat_core"


func test_enemy_friendly_fire_multiplier() -> void:
	assert_true(is_equal_approx(CombatFaction.damage_multiplier(CombatFaction.Id.ENEMY, CombatFaction.Id.ENEMY), 0.0))
	assert_true(is_equal_approx(CombatFaction.damage_multiplier(CombatFaction.Id.ENEMY, CombatFaction.Id.ENEMY, true), 0.0))
	assert_true(is_zero_approx(CombatFaction.damage_multiplier(CombatFaction.Id.PLAYER, CombatFaction.Id.PLAYER)))


func test_perfect_guard_reflects_front_projectile() -> void:
	var guard := GuardComponent.new()
	guard.begin_guard(Vector2.RIGHT)
	guard.advance_timing(0.061)
	assert_eq(guard.state, GuardComponent.State.PERFECT)
	var target := Node2D.new()
	var packet := DamagePacket.new()
	packet.base_damage = 1
	packet.source_faction = CombatFaction.Id.ENEMY
	packet.source_position = Vector2(20.0, 0.0)
	packet.travel_direction = Vector2.LEFT
	packet.is_projectile = true
	packet.reflectable = true
	var result := guard.try_resolve(packet, target, CombatFaction.Id.PLAYER)
	assert_true(result != null)
	assert_eq(result.outcome, DamageResult.Outcome.REFLECTED)
	assert_eq(result.packet.source_faction, CombatFaction.Id.PLAYER)
	assert_eq(result.packet.travel_direction, Vector2.RIGHT)
	target.free()
	guard.free()


func test_guard_rejects_back_attack() -> void:
	var guard := GuardComponent.new()
	guard.begin_guard(Vector2.RIGHT)
	guard.advance_timing(0.061)
	var target := Node2D.new()
	var packet := DamagePacket.new()
	packet.source_position = Vector2(-20.0, 0.0)
	packet.is_melee = true
	assert_true(guard.try_resolve(packet, target, CombatFaction.Id.PLAYER) == null)
	target.free()
	guard.free()


func test_damage_resolver_applies_integer_damage() -> void:
	var target := Node2D.new()
	var health := HealthComponent.new()
	health.max_health = 5
	health.current_health = 5
	var packet := DamagePacket.new()
	packet.base_damage = 2
	packet.source_faction = CombatFaction.Id.ENEMY
	var result := DamageResolver.resolve(packet, target, CombatFaction.Id.PLAYER, health)
	assert_eq(result.final_damage, 2)
	assert_eq(health.current_health, 3)
	health.free()
	target.free()


func test_projectile_discards_freed_source_reference() -> void:
	var projectile := CombatProjectile.new()
	var source := Node.new()
	projectile.setup(source, CombatFaction.Id.ENEMY, Vector2.LEFT, 2, 310.0)
	projectile.weapon_id = &"service_pistol"
	projectile.allows_trajectory_echo = true
	source.free()
	var packet := projectile._make_damage_packet()
	assert_true(packet.source == null)
	assert_eq(packet.source_faction, CombatFaction.Id.ENEMY)
	assert_eq(packet.weapon_id, &"service_pistol")
	assert_eq(packet.base_damage, 2)
	assert_true(packet.allows_trajectory_echo)
	projectile.free()


func test_enemy_projectile_takeover_is_single_use_and_clears_status() -> void:
	var projectile := CombatProjectile.new()
	var enemy_source := Node.new()
	var player_source := Node.new()
	var target := Node2D.new()
	target.position = Vector2(80.0, 0.0)
	projectile.setup(enemy_source, CombatFaction.Id.ENEMY, Vector2.LEFT, 2, 310.0)
	projectile.status_tags = PackedStringArray(["burn", "shock"])
	assert_true(projectile.can_be_taken_over())
	assert_true(projectile.take_over(player_source, target, 720.0))
	assert_eq(projectile.faction, CombatFaction.Id.PLAYER)
	assert_eq(projectile.source, player_source)
	assert_eq(projectile.homing_target, target)
	assert_true(projectile.status_tags.is_empty())
	assert_true(projectile.takeover_consumed)
	assert_false(projectile.can_be_taken_over())
	assert_false(projectile.take_over(player_source, target, 720.0))
	projectile.free()
	target.free()
	player_source.free()
	enemy_source.free()


func test_area_projectile_cannot_be_taken_over() -> void:
	var projectile := CombatProjectile.new()
	var enemy_source := Node.new()
	projectile.setup(enemy_source, CombatFaction.Id.ENEMY, Vector2.LEFT, 2, 310.0)
	projectile.configure_explosion(32.0, 1)
	assert_false(projectile.can_be_taken_over())
	projectile.free()
	enemy_source.free()


func test_damage_packet_duplicate_preserves_weapon_identity() -> void:
	var packet := DamagePacket.new()
	packet.weapon_id = &"rail_cannon"
	packet.feedback_group_id = 42
	packet.is_continuous_damage = true
	packet.allows_trajectory_echo = true
	var copy := packet.duplicate_packet()
	assert_eq(copy.weapon_id, &"rail_cannon")
	assert_eq(copy.feedback_group_id, 42)
	assert_true(copy.is_continuous_damage)
	assert_true(copy.allows_trajectory_echo)


func test_damage_result_marks_prevented_fatal_damage_for_presentation() -> void:
	var target := Node2D.new()
	var health := HealthComponent.new()
	health.max_health = 3
	health.current_health = 1
	health.fatal_damage_interceptor = func(_amount: int, _packet: DamagePacket) -> bool: return true
	var packet := DamagePacket.new()
	packet.base_damage = 3
	packet.source_faction = CombatFaction.Id.ENEMY
	var result := DamageResolver.resolve(packet, target, CombatFaction.Id.PLAYER, health)
	assert_true(result.fatal_damage_prevented)
	assert_eq(result.final_damage, 0)
	assert_eq(health.current_health, 1)
	health.free()
	target.free()


func test_weapon_controller_stamps_weapon_identity_on_direct_packets() -> void:
	var controller := track(WeaponController.new()) as WeaponController
	var rail := load("res://resources/weapons/rail_cannon.tres") as WeaponComponentData
	var packet := controller._make_packet(rail, Vector2.ZERO, Vector2.RIGHT, controller)
	assert_eq(packet.weapon_id, &"rail_cannon")
	assert_true(packet.allows_trajectory_echo)
	var pistol := load("res://resources/weapons/service_pistol.tres") as WeaponComponentData
	assert_false(controller._make_packet(pistol, Vector2.ZERO, Vector2.RIGHT, controller).allows_trajectory_echo)


func test_perfect_window_reflects_multiple_projectiles_without_extending() -> void:
	var guard := GuardComponent.new()
	var target := Node2D.new()
	var packet := DamagePacket.new()
	packet.source_faction = CombatFaction.Id.ENEMY
	packet.source_position = Vector2(20, 0)
	packet.travel_direction = Vector2.LEFT
	packet.is_projectile = true
	packet.reflectable = true
	guard.begin_guard(Vector2.RIGHT)
	guard.advance_timing(0.021)
	assert_true(guard.try_resolve(packet, target, CombatFaction.Id.PLAYER).reflected)
	guard.advance_timing(0.19)
	assert_true(guard.try_resolve(packet, target, CombatFaction.Id.PLAYER).reflected)
	guard.advance_timing(0.01)
	assert_eq(guard.state, GuardComponent.State.NORMAL)
	assert_false(guard.try_resolve(packet, target, CombatFaction.Id.PLAYER).reflected)
	target.free()
	guard.free()
