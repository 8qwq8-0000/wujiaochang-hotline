@tool
extends McpTestSuite


func suite_name() -> String:
	return "enemy_combat_upgrade"


func test_confirmed_role_values_are_data_driven() -> void:
	var melee: EnemyProfile = load("res://resources/enemies/melee_pressure.tres")
	var sniper: EnemyProfile = load("res://resources/enemies/ranged_sightline.tres")
	var heavy: EnemyProfile = load("res://resources/enemies/heavy_anchor.tres")
	assert_eq(melee.move_speed, 100.0)
	assert_eq(melee.attack_windup, 0.3)
	assert_eq(melee.attack_cooldown, 0.82)
	assert_true(is_equal_approx(melee.move_speed * melee.patrol_speed_ratio, 38.0))
	assert_eq(sniper.display_name, "狙击手")
	assert_eq(heavy.attack_knockback, 220.0)
	assert_true(heavy.self_destruct_enabled)
	assert_eq(heavy.self_destruct_delay, 0.45)
	assert_eq(heavy.self_destruct_knockback, 260.0)
	assert_eq(heavy.self_destruct_noise_radius, 300.0)


func test_ai_test_settings_keep_independent_switches() -> void:
	var settings := GameSettingsController.new()
	assert_eq(settings.get_alert_response_distance(), 320.0)
	assert_false(settings.continuous_precharge)
	settings.set_high_pressure_alert(true, false)
	assert_true(is_inf(settings.get_alert_response_distance()))
	assert_false(settings.continuous_precharge)
	settings.set_continuous_precharge(true, false)
	assert_true(settings.continuous_precharge)
	settings.free()


func test_pause_settings_scene_exposes_confirmed_resolutions() -> void:
	assert_true(load("res://scenes/ui/pause_settings_menu.tscn") != null)
	assert_eq(PauseSettingsMenu.RESOLUTIONS.size(), 4)
	assert_eq(PauseSettingsMenu.RESOLUTIONS[0], Vector2i(1280, 720))
	assert_eq(PauseSettingsMenu.RESOLUTIONS[3], Vector2i(2560, 1440))
	assert_eq(PauseSettingsMenu.CAMERA_SHAKE_STRENGTHS, [0.0, 0.5, 1.0])
