extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var runner := preload("res://addons/godot_ai/testing/test_runner.gd").new()
	var suites: Array = []
	for path in ["test_combat_core", "test_mobility", "test_floor_assembler", "test_player_scene", "test_weapon_scenes", "test_projectile_scene", "test_combat_music", "test_combat_audio", "test_combat_notice_queue", "test_afterimage_vfx", "test_procedural_vfx", "test_enemy_navigation", "test_enemy_tactical_brain", "test_enemy_combat_upgrade", "test_cyber_ui", "test_rooftop_boss"]:
		suites.append(load("res://tests/" + path + ".gd").new())
	var result: Dictionary = runner.run_suites(suites, "", "", {}, true)
	print(JSON.stringify(result))
	for suite in suites:
		suite._free_tracked()

	suites.clear()
	quit(0 if int(result.get("failed", 0)) == 0 else 1)
