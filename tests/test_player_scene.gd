@tool
extends McpTestSuite


func suite_name() -> String:
	return "player_scene"


func test_player_scene_has_required_components() -> void:
	var scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player := track(scene.instantiate()) as PlayerController
	assert_true(player != null)
	assert_true(player.get_node_or_null("HealthComponent") is HealthComponent)
	assert_true(player.get_node_or_null("StatusComponent") is StatusComponent)
	assert_true(player.get_node_or_null("TalentCoreController") is TalentCoreController)
	assert_true(player.get_node_or_null("CircuitBreakerComponent") is CircuitBreakerComponent)
	assert_true(player.get_node_or_null("InteractionDetector") is InteractorComponent)
	assert_true(player.get_node_or_null("VisualRoot/BodyVisual") is AnimatedSprite2D)
	assert_true(player.get_node_or_null("VisualRoot/WeaponPivot") is WeaponMount)
	assert_true(player.get_node_or_null("VFXSockets/Foot") is Marker2D)


func test_default_player_config_uses_baton_and_walking() -> void:
	var config: CombatPlayerConfig = load("res://resources/player/default_player_config.tres")
	assert_eq(config.max_health, 3)
	assert_true(is_equal_approx(config.damage_invulnerability_seconds, 0.18))
	assert_eq(config.default_weapon.id, &"baton")
	assert_eq(config.default_weapon.heat_per_attack, 0.0)
	assert_eq(config.default_mobility.id, &"walk")
	assert_false(config.debug_loadout_enabled)


func test_circuit_breaker_prevents_only_first_fatal_hit() -> void:
	var health := HealthComponent.new()
	health.max_health = 3
	health.current_health = 3
	var breaker := CircuitBreakerComponent.new()
	breaker.set_equipped(true)
	health.fatal_damage_interceptor = func(_amount: int, _packet: DamagePacket) -> bool:
		return breaker.try_prevent_fatal_damage()
	var packet := DamagePacket.new()
	packet.base_damage = 5
	packet.source_faction = CombatFaction.Id.ENEMY
	health.apply_damage(packet.base_damage, packet)
	assert_eq(health.current_health, 1)
	assert_true(breaker.circuit_breaker_used)
	health.apply_damage(1, packet)
	assert_true(health.is_dead())
	health.free()
	breaker.free()


func test_circuit_breaker_re_equipping_does_not_refresh_it() -> void:
	var breaker := CircuitBreakerComponent.new()
	assert_true(breaker.try_prevent_fatal_damage())
	breaker.set_equipped(false)
	breaker.set_equipped(true)
	assert_false(breaker.try_prevent_fatal_damage())
	breaker.free()


func test_talent_core_state_is_independent_and_persistent() -> void:
	var talent_core := TalentCoreController.new()
	talent_core.set_core_level(2)
	assert_true(talent_core.set_protocol(TalentCoreController.ASSAULT_PROTOCOL))
	assert_true(talent_core.set_talent_choice(
		TalentCoreController.ASSAULT_PROTOCOL,
		1,
		&"rapid_fire"
	))
	assert_true(talent_core.set_talent_choice(
		TalentCoreController.ASSAULT_PROTOCOL,
		2,
		&"switch_strike"
	))
	talent_core.refill_takeover_charges()
	assert_true(talent_core.arm_takeover())
	assert_true(talent_core.consume_takeover_after_success())

	var restored := TalentCoreController.new()
	restored.import_state(talent_core.export_state())
	assert_eq(restored.core_level, 2)
	assert_eq(restored.current_protocol_id, TalentCoreController.ASSAULT_PROTOCOL)
	assert_eq(restored.get_talent_choice(TalentCoreController.ASSAULT_PROTOCOL, 1), &"rapid_fire")
	assert_eq(restored.get_talent_choice(TalentCoreController.ASSAULT_PROTOCOL, 2), &"switch_strike")
	assert_eq(restored.takeover_charges, 0)
	talent_core.free()
	restored.free()


func test_mobility_action_locks_are_data_driven() -> void:
	var wheel: MobilityMode = load("res://resources/mobility/wheel.tres")
	var quadruped: MobilityMode = load("res://resources/mobility/quadruped.tres")
	var flight: MobilityMode = load("res://resources/mobility/flight.tres")
	assert_false(wheel.locks_attack)
	assert_true(quadruped.locks_attack)
	assert_true(quadruped.locks_guard)
	assert_false(flight.locks_guard)


func test_player_config_does_not_shadow_menu_plugin() -> void:
	var gameplay: Script = load("res://scripts/gameplay/player/player_config.gd")
	var menu: Script = load("res://addons/maaacks_menus_template/base/nodes/config/player_config.gd")
	assert_false(gameplay.get_global_name() == menu.get_global_name())
	var config_resource: Resource = load("res://resources/player/default_player_config.tres")
	assert_true(config_resource is CombatPlayerConfig)
