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
	assert_true(player.get_node_or_null("CoreController") is CoreController)
	assert_true(player.get_node_or_null("InteractionDetector") is InteractorComponent)
	assert_true(player.get_node_or_null("VisualRoot/BodyVisual") is AnimatedSprite2D)
	assert_true(player.get_node_or_null("VisualRoot/WeaponPivot/MuzzleSocket") is Marker2D)
	assert_true(player.get_node_or_null("VFXSockets/Foot") is Marker2D)


func test_default_player_config_uses_baton_and_walking() -> void:
	var config: PlayerConfig = load("res://resources/player/default_player_config.tres")
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
	var core := CoreController.new()
	core.equipped_core_id = CoreController.CIRCUIT_BREAKER_ID
	core.circuit_breaker_armed = true
	health.fatal_damage_interceptor = func(_amount: int, _packet: DamagePacket) -> bool:
		return core.try_prevent_fatal_damage()
	var packet := DamagePacket.new()
	packet.base_damage = 5
	packet.source_faction = CombatFaction.Id.ENEMY
	health.apply_damage(packet.base_damage, packet)
	assert_eq(health.current_health, 1)
	assert_true(core.circuit_breaker_used)
	health.apply_damage(1, packet)
	assert_true(health.is_dead())
	health.free()
	core.free()


func test_mobility_action_locks_are_data_driven() -> void:
	var wheel: MobilityMode = load("res://resources/mobility/wheel.tres")
	var quadruped: MobilityMode = load("res://resources/mobility/quadruped.tres")
	var flight: MobilityMode = load("res://resources/mobility/flight.tres")
	assert_false(wheel.locks_attack)
	assert_true(quadruped.locks_attack)
	assert_true(quadruped.locks_guard)
	assert_false(flight.locks_guard)
