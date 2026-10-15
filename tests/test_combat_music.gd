@tool
extends McpTestSuite

const EXPECTED_REGULAR := [
	"res://assets/audio/music/combat/combat_regular_01.ogg",
	"res://assets/audio/music/combat/combat_regular_02.ogg",
]
const EXPECTED_BOSS := [
	"res://assets/audio/music/combat/combat_boss_phase_01.ogg",
	"res://assets/audio/music/combat/combat_boss_phase_02.ogg",
]


func suite_name() -> String:
	return "combat_music"


func test_main_registers_all_combat_tracks() -> void:
	var main := track(load("res://scenes/bootstrap/main.tscn").instantiate())
	var music := main.get_node_or_null("CombatMusic") as CombatMusicController
	assert_true(music != null)
	assert_eq(music.regular_tracks.size(), 2)
	assert_eq(music.boss_phase_tracks.size(), 2)
	for index in EXPECTED_REGULAR.size():
		assert_eq(music.regular_tracks[index].resource_path, EXPECTED_REGULAR[index])
	for index in EXPECTED_BOSS.size():
		assert_eq(music.boss_phase_tracks[index].resource_path, EXPECTED_BOSS[index])


func test_controller_exposes_boss_phase_api() -> void:
	var music := track(CombatMusicController.new())
	assert_true(music.has_method("start_boss_phase"))
	assert_true(music.has_method("end_boss_music"))
	assert_true(music.has_method("stop_combat_music"))
