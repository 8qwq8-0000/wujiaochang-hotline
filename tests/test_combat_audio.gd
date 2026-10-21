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


func test_player_has_spatial_flight_audio_socket() -> void:
	var player := track(load("res://scenes/actors/player/player.tscn").instantiate()) as PlayerController
	var movement := player.get_node_or_null("AudioSockets/MovementLoop") as AudioStreamPlayer2D
	assert_true(movement != null)
	assert_true(load("res://assets/audio/sfx/mobility/flight_loop.wav") is AudioStreamWAV)
	assert_true(load("res://assets/audio/sfx/enemies/reinforcement_approach.wav") is AudioStreamWAV)
