extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func run_checks() -> void:
	var run_manager := root.get_node("RunManager")
	run_manager.set_mandatory_enemy_count(0)
	var music := CombatMusicController.new()
	music.regular_tracks = [
		load("res://assets/audio/music/combat/combat_regular_01.ogg"),
		load("res://assets/audio/music/combat/combat_regular_02.ogg"),
	]
	music.boss_phase_tracks = [
		load("res://assets/audio/music/combat/combat_boss_phase_01.ogg"),
		load("res://assets/audio/music/combat/combat_boss_phase_02.ogg"),
	]
	music.crossfade_duration = 0.0
	music.stop_fade_duration = 0.0
	root.add_child(music)
	await process_frame

	run_manager.set_mandatory_enemy_count(1)
	await process_frame
	check(music.get_playback_mode() == CombatMusicController.PlaybackMode.REGULAR, "mandatory combat starts regular music")
	check(music.get_current_track_path().ends_with("combat_regular_01.ogg"), "regular playlist starts at track 1")
	check(root.get_node("SoundManager").is_music_playing(music.regular_tracks[0]), "regular track reaches SoundManager")
	check(AudioServer.get_bus_index("Music") >= 0, "Music audio bus is available")

	music.start_boss_phase(1)
	await process_frame
	check(music.get_playback_mode() == CombatMusicController.PlaybackMode.BOSS, "boss phase enters boss mode")
	check(music.get_boss_phase() == 1, "boss phase 1 is recorded")
	check(music.get_current_track_path().ends_with("combat_boss_phase_01.ogg"), "boss phase 1 track plays")

	run_manager.set_mandatory_enemy_count(0)
	await process_frame
	check(music.get_playback_mode() == CombatMusicController.PlaybackMode.BOSS, "enemy count does not interrupt boss music")
	music.start_boss_phase(2)
	await process_frame
	check(music.get_boss_phase() == 2, "boss phase 2 is recorded")
	check(music.get_current_track_path().ends_with("combat_boss_phase_02.ogg"), "boss phase 2 track plays")

	music.end_boss_music()
	await process_frame
	check(music.get_playback_mode() == CombatMusicController.PlaybackMode.SILENT, "cleared boss combat stops music")
	check(music.get_current_track_path().is_empty(), "stopped music clears the active track")

	music.queue_free()
	await process_frame
	print("Combat music failures: ", failures)
	quit(0 if failures == 0 else 1)
