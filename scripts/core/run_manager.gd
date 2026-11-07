extends Node

const NORMAL_FLOOR_COUNT := 3

signal run_started(seed: int)
signal scene_payload_changed(payload: Dictionary)
signal mandatory_enemy_count_changed(remaining: int)
signal player_state_changed(state: Dictionary)
signal persona_authorization_changed(pending: bool, floor: int)

var run_seed: int = 0
var floor_index: int = 0
var scene_payload: Dictionary = {}
var mandatory_enemies_remaining: int = 0
var player_state: Dictionary = {}
var extraction_result: Dictionary = {}
var victory_result: Dictionary = {}
var run_finished := false
var persistent_run := false
var codex_medical_supply_used := false
var operator_hack_announced := false
var persona_authorization_floor := -1
var persona_authorization_pending := false
var persona_rest_refilled_floor := -1
var channel_route_active := false
var channel_record_found := false

# Legacy checkpoint fields; no longer gate travel or rooftop takeover.
var channel_key_found := false
var channel_isolated := false
var channel_takeover_complete := false
var codex_companion: Dictionary = {}
var channel_resume: Dictionary = {}
var run_started_msec := 0


func begin_run(seed_value: int = 0) -> void:
	run_seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	floor_index = 0
	mandatory_enemies_remaining = 0
	player_state.clear()
	extraction_result.clear()
	victory_result.clear()
	run_finished = false
	persistent_run = false
	codex_medical_supply_used = false
	operator_hack_announced = false
	persona_authorization_floor = -1
	persona_authorization_pending = false
	persona_rest_refilled_floor = -1
	reset_channel_route()
	run_started_msec = Time.get_ticks_msec()
	run_started.emit(run_seed)


func set_scene_payload(value: Dictionary) -> void:
	scene_payload = value.duplicate(true)
	scene_payload_changed.emit(scene_payload)


func consume_scene_payload() -> Dictionary:
	var payload := scene_payload.duplicate(true)
	scene_payload.clear()
	return payload


func set_mandatory_enemy_count(value: int) -> void:
	mandatory_enemies_remaining = maxi(value, 0)
	mandatory_enemy_count_changed.emit(mandatory_enemies_remaining)


func notify_mandatory_enemy_defeated() -> void:
	set_mandatory_enemy_count(mandatory_enemies_remaining - 1)


func set_player_state(value: Dictionary) -> void:
	player_state = value.duplicate(true)
	player_state_changed.emit(player_state.duplicate(true))


func get_player_state() -> Dictionary:
	return player_state.duplicate(true)


func prepare_persona_rest(floor_value: int = floor_index) -> bool:
	if not persistent_run or floor_value < 0 or floor_value >= NORMAL_FLOOR_COUNT:
		return false
	if persona_authorization_floor != floor_value:
		persona_authorization_floor = floor_value
		persona_authorization_pending = true
		persona_authorization_changed.emit(true, floor_value)
	return persona_authorization_pending


func has_persona_authorization(floor_value: int = floor_index) -> bool:
	return persona_authorization_pending and persona_authorization_floor == floor_value


func consume_persona_authorization(floor_value: int = floor_index) -> bool:
	if not has_persona_authorization(floor_value):
		return false
	persona_authorization_pending = false
	persona_authorization_changed.emit(false, floor_value)
	return true


func consume_persona_rest_refill(floor_value: int = floor_index) -> bool:
	if not persistent_run or floor_value < 0 or floor_value >= NORMAL_FLOOR_COUNT or persona_rest_refilled_floor == floor_value:
		return false
	persona_rest_refilled_floor = floor_value
	return true


func finish_extraction(player: PlayerController) -> bool:
	if run_finished or not is_instance_valid(player) or player.health.is_dead():
		return false
	if channel_route_active or mandatory_enemies_remaining > 0:
		return false
	extraction_result = {
		"seed": run_seed,
		"floor": floor_index + 1,
		"player_state": player.export_settlement_state(true),
		"items": player.inventory.get_extraction_items(),
	}
	run_finished = true
	set_player_state(extraction_result.player_state)
	return true


func finish_victory(player: PlayerController) -> bool:
	if (
		run_finished
		or not persistent_run
		or (channel_boss_ready() and not channel_takeover_complete)
		or floor_index < NORMAL_FLOOR_COUNT
		or mandatory_enemies_remaining > 0
		or not is_instance_valid(player)
		or player.health.is_dead()
	):
		return false
	var talent_state := player.talent_core.export_state()
	var personas: Array = []
	var levels: Dictionary = talent_state.get("persona_levels", {})
	var builds: Dictionary = talent_state.get("talent_builds", {})
	for persona_id in TalentCoreController.PERSONA_IDS:
		var level := int(levels.get(String(persona_id), 0))
		if level <= 0:
			continue
		var build: Dictionary = builds.get(String(persona_id), {})
		personas.append({
			"id": String(persona_id),
			"name": TalentCoreController.PERSONA_DISPLAY_NAMES[persona_id],
			"level": level,
			"tier_3_talent": String(build.get("tier_3", "")) if level >= 3 else "",
		})
	var leaks: Array = []
	var saved_leaks: Dictionary = talent_state.get("semantic_leaks", {})
	for persona_id in TalentCoreController.PERSONA_IDS:
		if bool(saved_leaks.get(String(persona_id), false)):
			leaks.append(String(TalentCoreController.SEMANTIC_LEAK_IDS[persona_id]))
	var metrics: Dictionary = talent_state.get("run_metrics", {}).duplicate(true)
	var last_persona_id := String(talent_state.get("current_persona_id", ""))
	if int(levels.get(last_persona_id, 0)) <= 0:
		last_persona_id = ""
	var elapsed_seconds := maxf(float(Time.get_ticks_msec() - run_started_msec) / 1000.0, 0.0)
	var record := {
		"id": "%d-%d" % [int(Time.get_unix_time_from_system()), run_seed],
		"created_unix": int(Time.get_unix_time_from_system()),
		"ending": "channel_returned" if bool(codex_companion.get("arrived", false)) and channel_takeover_complete else "core_destroyed",
		"run_seed": run_seed,
		"clear_seconds": snappedf(elapsed_seconds, 0.1),
		"last_persona_id": last_persona_id,
		"personas": personas,
		"highest_marked_kill_chain": int(metrics.get("highest_marked_kill_chain", 0)),
		"manual_perfect_guards": int(metrics.get("manual_perfect_guards", 0)),
		"peak_rock_feedback": snappedf(float(metrics.get("peak_rock_feedback", 0.0)), 0.1),
		"rock_attacks": int(metrics.get("rock_attacks", 0)),
		"semantic_leaks": leaks,
	}
	victory_result = {
		"record": record,
		"player_state": player.export_settlement_state(true),
	}
	run_finished = true
	set_player_state(victory_result.player_state)
	return true


func capture_player_state(player: PlayerController, repair_amount: int = 0) -> Dictionary:
	if not is_instance_valid(player):
		return get_player_state()
	var snapshot := player.export_run_state()
	if repair_amount > 0:
		var current := int(snapshot.get("current_health", 1))
		snapshot["current_health"] = mini(current + repair_amount, player.config.max_health)
	set_player_state(snapshot)
	return snapshot.duplicate(true)


func reset_channel_route() -> void:
	channel_route_active = false
	channel_record_found = false
	channel_key_found = false
	channel_isolated = false
	channel_takeover_complete = false
	codex_companion.clear()
	channel_resume.clear()


func activate_channel_route() -> bool:
	if not persistent_run or run_finished or floor_index != 0 or not channel_record_found:
		return false
	if not get_node("/root/WarehouseStore").is_channel_route_unlocked():
		return false
	channel_route_active = true
	return true


func channel_floor_ready() -> bool:
	if not channel_route_active:
		return true
	return channel_record_found and (floor_index != 2 or not codex_is_alive() or bool(codex_companion.get("ambush_failed", false)) or bool(codex_companion.get("ambush_complete", false)))


func channel_boss_ready() -> bool:
	return channel_route_active and channel_record_found and codex_is_alive() and bool(codex_companion.get("arrived", false)) and bool(codex_companion.get("ambush_complete", false))


func export_channel_state() -> Dictionary:
	return {"active": channel_route_active, "record": channel_record_found,
		"key": channel_key_found, "isolated": channel_isolated, "codex": codex_companion.duplicate(true)}


func restore_channel_checkpoint(data: Dictionary) -> bool:
	if data.is_empty() or not data.get("route", {}).get("active", false):
		return false
	begin_run(int(data.get("seed", 1)))
	persistent_run = true
	floor_index = int(data.get("floor", 0))
	var route: Dictionary = data.route
	channel_route_active = true
	channel_record_found = bool(route.get("record", false))
	channel_key_found = bool(route.get("key", false))
	channel_isolated = bool(route.get("isolated", false))
	codex_companion = route.get("codex", {}).duplicate(true)
	# Preserve already reached rooftops from the former escort route.
	if floor_index == 3 and bool(codex_companion.get("arrived", false)):
		codex_companion.ambush_complete = true
	codex_medical_supply_used = bool(data.get("medical_used", false))
	persona_authorization_floor = int(data.get("persona_floor", -1))
	persona_authorization_pending = bool(data.get("persona_pending", false))
	persona_rest_refilled_floor = int(data.get("persona_refilled", -1))
	player_state = data.player.duplicate(true)
	channel_resume = data.duplicate(true)
	run_started_msec -= int(float(data.get("elapsed", 0)) * 1000)
	return true


func carries_channel_core(player: PlayerController) -> bool:
	if not is_instance_valid(player):
		return false
	for item in player.inventory.backpack.get_items():
		if player.inventory.is_channel_core(item):
			return true
	return false


func recruit_codex(player: PlayerController) -> bool:
	if not persistent_run or run_finished or floor_index != 1 or not channel_route_active or not carries_channel_core(player) or not codex_companion.is_empty():
		return false
	codex_companion = {"joined": true, "health": 3, "arrived": false, "repaired_areas": [], "ambush_complete": false}
	return true


func codex_is_alive() -> bool:
	return bool(codex_companion.get("joined", false)) and int(codex_companion.get("health", 0)) > 0


func save_codex_progress() -> bool:
	var store := get_node("/root/WarehouseStore")
	var saved: Dictionary = store.get_channel_checkpoint()
	if saved.is_empty():
		return false
	# Keep the last safe room/player snapshot, but never revive an escort by
	# reopening that snapshot after she was injured or killed.
	saved.route = export_channel_state()
	return store.save_channel_progress(saved)
