@tool
extends McpTestSuite


func suite_name() -> String:
	return "dash_and_cyberware"


func test_dash_baseline_is_data_driven_and_always_available() -> void:
	var config: DashConfigData = load("res://resources/player/default_dash_config.tres")
	assert_eq(config.walk_speed, 125.0)
	assert_eq(config.dash_speed, 420.0)
	assert_eq(config.dash_duration, 0.2)
	assert_eq(config.dash_cooldown, 1.2)
	assert_eq(config.invulnerability_seconds, 0.15)
	assert_eq(config.collision_damage, 2)
	assert_eq(config.collision_stagger_seconds, 0.65)


func test_cyberware_resources_keep_confirmed_tuning() -> void:
	var smart: CyberwareData = load("res://resources/cyberware/smart_fire.tres")
	var explosive: CyberwareData = load("res://resources/cyberware/explosive_magazine.tres")
	var tactical: CyberwareData = load("res://resources/cyberware/tactical_coprocessor.tres")
	var optical: CyberwareData = load("res://resources/cyberware/optical_intruder.tres")
	var kill_heat_sink: CyberwareData = load("res://resources/cyberware/kill_heat_sink.tres")
	var heat_threshold_pulser: CyberwareData = load("res://resources/cyberware/heat_threshold_pulser.tres")
	assert_eq(smart.module_id, CyberwareController.SMART_FIRE)
	assert_eq(smart.targeting_half_angle_degrees, 25.0)
	assert_eq(smart.homing_turn_degrees_per_second, 360.0)
	assert_eq(explosive.module_id, CyberwareController.EXPLOSIVE_MAGAZINE)
	assert_eq(explosive.explosion_radius, 48.0)
	assert_eq(explosive.explosion_damage, 1)
	assert_eq(tactical.module_id, CyberwareController.TACTICAL_COPROCESSOR)
	assert_eq(optical.module_id, CyberwareController.OPTICAL_INTRUDER)
	assert_eq(optical.optical_reacquire_delay, 0.6)
	assert_eq(kill_heat_sink.module_id, CyberwareController.KILL_HEAT_SINK)
	assert_eq(kill_heat_sink.kill_cooling_ratio, 0.3)
	assert_eq(kill_heat_sink.trigger_cooldown, 0.5)
	assert_eq(heat_threshold_pulser.module_id, CyberwareController.HEAT_THRESHOLD_PULSER)
	assert_eq(heat_threshold_pulser.trigger_cooldown, 8.0)
	assert_eq(heat_threshold_pulser.overheat_pulse_radius, 64.0)
	assert_eq(heat_threshold_pulser.overheat_pulse_stagger_seconds, 0.8)


func test_player_scene_uses_new_runtime_controllers() -> void:
	var player := track(load("res://scenes/actors/player/player.tscn").instantiate()) as PlayerController
	assert_true(player.get_node_or_null("DashController") is DashController)
	assert_true(player.get_node_or_null("CyberwareController") is CyberwareController)
	assert_true(player.get_node_or_null("MobilityController") == null)
