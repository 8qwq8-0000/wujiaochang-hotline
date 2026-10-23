@tool
extends McpTestSuite


func suite_name() -> String:
	return "combat_audio"


func test_main_registers_combat_and_hotline_audio() -> void:
	var main := track(load("res://scenes/bootstrap/main.tscn").instantiate())
	var audio := main.get_node_or_null("AudioCueManager") as AudioCueManager
	assert_true(audio != null)
	assert_true(audio.perfect_guard_sound != null)
	assert_true(audio.block_sound != null)
	assert_true(audio.hit_sound != null)
	assert_true(audio.enemy_death_sound != null)
	assert_true(audio.weapon_cues.has(&"cyberware:thermal_pulse"))
	assert_true(audio.reinforcement_approach_sound != null)
	assert_eq(audio.hotline_dial_sounds.size(), 2)
	assert_true(audio.hotline_connect_sound != null)
	assert_true(audio.weapon_cues.has(&"initial_baton:swing"))
	assert_true(audio.weapon_cues.has(&"baton:swing"))
	assert_true(audio.weapon_cues.has(&"service_pistol:fire"))
	assert_eq(audio.service_pistol_fire_sounds.size(), 4)
	assert_eq(audio.scattergun_fire_sounds.size(), 4)
	assert_eq(audio.rail_cannon_fire_sounds.size(), 4)
	assert_eq(audio.block_sounds.size(), 4)
	assert_eq(audio.perfect_guard_energy_sounds.size(), 3)
	assert_eq(audio.player_hurt_sounds.size(), 4)
	assert_eq(audio.heavy_damage_sounds.size(), 2)
	assert_true(audio.low_health_warning_sound != null)
	assert_true(audio.low_health_heartbeat_sound != null)
	assert_eq(audio.kill_confirm_sounds.size(), 3)
	assert_eq(audio.heavy_kill_sounds.size(), 2)
	assert_eq(audio.service_pistol_hit_sounds.size(), 4)
	assert_eq(audio.scattergun_hit_sounds.size(), 4)
	assert_eq(audio.rail_cannon_hit_sounds.size(), 4)
	assert_eq(audio.light_metal_hit_sounds.size(), 4)
	assert_eq(audio.heavy_metal_hit_sounds.size(), 4)
	assert_true(is_equal_approx(audio.hit_merge_window, 0.035))
	assert_eq(audio.max_hit_voices, 4)
	assert_true(is_equal_approx(audio.duck_depth_db, 2.5))
	assert_eq(audio._perfect_guard_stage(1), 1)
	assert_eq(audio._perfect_guard_stage(5), 5)
	assert_eq(audio._perfect_guard_stage(12), 5)
	assert_true(AudioServer.get_bus_index(&"CombatAccent") >= 0)
	assert_true(AudioServer.get_bus_index(&"CombatCue") >= 0)


func test_hit_variant_bag_does_not_repeat_within_cycle() -> void:
	var audio := track(AudioCueManager.new()) as AudioCueManager
	var streams: Array[AudioStream] = [
		AudioStreamWAV.new(),
		AudioStreamWAV.new(),
		AudioStreamWAV.new(),
		AudioStreamWAV.new(),
	]
	var selected := {}
	for index in streams.size():
		var stream := audio._pick_variant(&"test", streams)
		assert_false(selected.has(stream), "variant %d repeated before the bag emptied" % index)
		selected[stream] = true


func test_kill_chain_keeps_weapon_tone_offsets_subtle() -> void:
	var audio := AudioCueManager.new()
	assert_true(audio._weapon_kill_pitch_offset(&"scattergun") < 0.0)
	assert_true(audio._weapon_kill_pitch_offset(&"rail_cannon") > 0.0)
	assert_true(is_equal_approx(audio._weapon_kill_pitch_offset(&"service_pistol"), 0.0))
	audio.free()


func test_priority_duck_restores_existing_mix_levels() -> void:
	var audio := track(AudioCueManager.new()) as AudioCueManager
	var sfx_index := AudioServer.get_bus_index(&"SFX")
	var music_index := AudioServer.get_bus_index(&"Music")
	var original_sfx := AudioServer.get_bus_volume_db(sfx_index)
	var original_music := AudioServer.get_bus_volume_db(music_index)
	audio._duck_priority_mix()
	assert_true(is_equal_approx(AudioServer.get_bus_volume_db(sfx_index), original_sfx - audio.duck_depth_db))
	assert_true(is_equal_approx(AudioServer.get_bus_volume_db(music_index), original_music - audio.duck_depth_db))
	audio._tick_priority_duck(audio.duck_hold_seconds + audio.duck_recovery_seconds)
	assert_true(is_equal_approx(AudioServer.get_bus_volume_db(sfx_index), original_sfx))
	assert_true(is_equal_approx(AudioServer.get_bus_volume_db(music_index), original_music))


func test_enemy_profiles_use_two_metal_impact_classes() -> void:
	var melee := load("res://resources/enemies/melee_pressure.tres") as EnemyProfile
	var ranged := load("res://resources/enemies/ranged_sightline.tres") as EnemyProfile
	var heavy := load("res://resources/enemies/heavy_anchor.tres") as EnemyProfile
	assert_eq(melee.impact_material, EnemyProfile.ImpactMaterial.LIGHT_METAL)
	assert_eq(ranged.impact_material, EnemyProfile.ImpactMaterial.LIGHT_METAL)
	assert_eq(heavy.impact_material, EnemyProfile.ImpactMaterial.HEAVY_METAL)


func test_player_has_spatial_flight_audio_socket() -> void:
	var player := track(load("res://scenes/actors/player/player.tscn").instantiate()) as PlayerController
	var movement := player.get_node_or_null("AudioSockets/MovementLoop") as AudioStreamPlayer2D
	assert_true(movement != null)
	assert_true(load("res://assets/audio/sfx/mobility/flight_loop.wav") is AudioStreamWAV)
	assert_true(load("res://assets/audio/sfx/enemies/reinforcement_approach.wav") is AudioStreamWAV)
