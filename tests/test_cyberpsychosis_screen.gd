@tool
extends McpTestSuite


func suite_name() -> String:
	return "cyberpsychosis_screen"


func test_film_pass_covers_inventory_and_keeps_psychosis_below_ui() -> void:
	var screen := CyberpsychosisScreen.new()
	track(screen)
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	var film_layer := screen.get_node("FilmOverUI") as CanvasLayer
	assert_true(film_layer != null)
	assert_true(film_layer.layer > 110)
	assert_eq(screen.layer, 10)
	assert_eq(screen._material.get_shader_parameter("film_strength"), 0.0)
	assert_eq(screen._film_material.get_shader_parameter("film_strength"), 1.0)
	assert_eq(screen._film_overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_module_thresholds_cue_music_and_peak_only_when_insert_starts() -> void:
	var screen := CyberpsychosisScreen.new()
	var peaks: Array[StringName] = []
	var music_cues: Array[int] = []
	screen.peak_started.connect(func(source: StringName) -> void: peaks.append(source))
	screen.music_cue_requested.connect(func() -> void: music_cues.append(1))
	for index in 29:
		screen._on_module_triggered(&"smart_fire")
	assert_eq(screen.get_window_counts().modules, 29)
	assert_true(peaks.is_empty())
	assert_true(music_cues.is_empty())
	screen._on_module_triggered(&"smart_fire")
	assert_eq(screen.get_window_counts().modules, 30)
	for index in 44:
		screen._on_module_triggered(&"smart_fire")
	assert_eq(screen.get_window_counts().modules, 74)
	assert_eq(screen._onset_started_usec, 0)
	screen._on_module_triggered(&"smart_fire")
	assert_true(screen._onset_started_usec > 0)
	for index in 74:
		screen._on_module_triggered(&"smart_fire")
	assert_eq(screen.get_window_counts().modules, 149)
	assert_true(music_cues.is_empty())
	screen._on_module_triggered(&"smart_fire")
	assert_eq(music_cues.size(), 1)
	assert_true(peaks.is_empty())
	assert_false(screen._peak_active)
	screen._on_music_started()
	assert_eq(peaks, [&"modules"])
	assert_true(screen._peak_active)
	assert_eq(screen.get_window_counts().modules, 150)
	for index in 300:
		screen._on_module_triggered(&"smart_fire")
	assert_eq(peaks.size(), 1)
	assert_eq(music_cues.size(), 1)
	assert_eq(screen.get_window_counts().modules, 150)
	screen._on_music_ended()
	assert_false(screen._peak_active)
	assert_true(screen._cooldown_until_usec > Time.get_ticks_usec())
	for index in 10:
		screen._on_module_triggered(&"smart_fire")
	assert_eq(screen.get_window_counts().modules, 0)
	assert_eq(screen._cooldown_uses, 10)
	screen.free()


func test_module_window_discards_uses_older_than_one_minute() -> void:
	var screen := CyberpsychosisScreen.new()
	screen._module_times.append(Time.get_ticks_usec() - CyberpsychosisScreen.WINDOW_USEC - 1)
	screen._on_module_triggered(&"smart_fire")
	assert_eq(screen.get_window_counts().modules, 1)
	screen.free()


func test_five_distinct_enemy_kills_do_not_unlock_peak() -> void:
	var screen := CyberpsychosisScreen.new()
	var player := PlayerController.new()
	var enemies: Array[EnemyController] = []
	var peaks: Array[StringName] = []
	screen.peak_started.connect(func(source: StringName) -> void: peaks.append(source))
	for index in 5:
		var enemy := EnemyController.new()
		enemies.append(enemy)
		var result := DamageResult.new()
		result.packet = DamagePacket.new()
		result.packet.source = player
		result.packet.source_faction = CombatFaction.Id.PLAYER
		result.target = enemy
		result.target_defeated = true
		screen._on_damage_resolved(result)
		if index == 0:
			screen._on_damage_resolved(result)
	assert_eq(screen.get_window_counts().kills, 5)
	assert_true(peaks.is_empty())
	for enemy in enemies:
		enemy.free()
	player.free()
	screen.free()
