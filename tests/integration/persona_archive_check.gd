extends SceneTree

const TEST_PATH := "user://persona-archive-integration-test.json"
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func run_checks() -> void:
	var store := root.get_node("WarehouseStore")
	store.save_path = TEST_PATH
	DirAccess.remove_absolute(TEST_PATH)
	check(store.create_new_profile(), "fresh archive profile can be created")
	var player := load("res://scenes/actors/player/player.tscn").instantiate() as PlayerController
	root.add_child(player)
	await process_frame
	var core := player.talent_core
	for _level in 3:
		check(core.consume_persona_drink(TalentCoreController.DEEP_NINJA), "deep ninja drink installs or upgrades")
	check(core.set_talent_choice(TalentCoreController.DEEP_NINJA, 3, &"ceaseless_hunt"), "tier three talent is recorded")
	core.maximize_run_metric(&"highest_marked_kill_chain", 6)
	core.add_run_metric(&"manual_perfect_guards", 4)
	var settlement := player.export_settlement_state(true)
	check(settlement.has("persona_archive"), "settlement extracts current-run persona archive")
	check(int(settlement.talent_core.persona_levels.deep_ninja) == 0, "settlement state clears persona levels for next run")
	check(store.commit([], settlement), "ordinary settlement persists archive")
	var profile: Dictionary = store.get_profile()
	check("deep_ninja" in profile.codex.personas, "ordinary settlement permanently discovers persona")
	check("compute_containment_slip" in profile.codex.semantic_leaks, "level-three semantic leak is permanently indexed")
	check(profile.legacy_drinks.is_empty(), "ordinary settlement never creates a legacy drink")
	check(not profile.loadout.has("persona_archive"), "transient archive payload is removed from safe loadout")
	check(int(profile.loadout.talent_core.persona_levels.deep_ninja) == 0, "saved next-run loadout cannot retain persona level")

	var run := root.get_node("RunManager")
	run.begin_run(73031)
	run.persistent_run = true
	run.floor_index = 4
	run.set_mandatory_enemy_count(0)
	check(run.finish_victory(player), "complete rooftop victory creates one pending record")
	var record: Dictionary = run.victory_result.record
	check(record.personas.size() == 1 and record.personas[0].tier_3_talent == "ceaseless_hunt", "legacy drink records used persona and tier-three talent")
	check(record.last_persona_id == "deep_ninja", "legacy drink keeps the final persona bottle silhouette")
	check(record.highest_marked_kill_chain == 6 and record.manual_perfect_guards == 4, "legacy drink records run metrics")
	check(store.commit([], run.victory_result.player_state, "", record), "victory record commits atomically with loadout")
	check(store.get_legacy_drinks().size() == 1, "full victory mints exactly one legacy drink")
	check(not run.finish_victory(player), "duplicate victory settlement is rejected")

	run.begin_run(73032)
	run.set_mandatory_enemy_count(0)
	check(run.finish_extraction(player), "ordinary extraction still settles")
	profile = store.get_profile()
	check(store.commit(profile.chest, run.extraction_result.player_state), "ordinary extraction commit succeeds")
	check(store.get_legacy_drinks().size() == 1, "extraction cannot mint an additional legacy drink")

	player.queue_free()
	await process_frame
	DirAccess.remove_absolute(TEST_PATH)
	print("Persona archive checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
