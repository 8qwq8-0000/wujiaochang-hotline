class_name TalentCoreController
extends Node

signal persona_changed(persona_id: StringName)
signal persona_level_changed(persona_id: StringName, level: int)
signal talent_build_changed(persona_id: StringName, tier: int, talent_id: StringName)
signal semantic_leak_unlocked(persona_id: StringName, leak_id: StringName)
signal relationship_stage_changed(persona_id: StringName, stage: int)
signal takeover_armed_changed(armed: bool)
signal takeover_charges_changed(current: int, maximum: int)
signal takeover_executed(persona_id: StringName)

# Compatibility signals kept while callers migrate from the protocol prototype.
signal core_level_changed(level: int)
signal protocol_changed(protocol_id: StringName)

const STATE_VERSION := 2
const RELATIONSHIP_STAGE_COST := 3

const DEEP_NINJA := &"deep_ninja"
const LEGENDARY_MASTER := &"legendary_master"
const ROCK_VIGILANTE := &"rock_vigilante"
const PERSONA_IDS: Array[StringName] = [DEEP_NINJA, LEGENDARY_MASTER, ROCK_VIGILANTE]

# Source-compatible aliases. Their values intentionally use the v2 persona IDs.
const ASSAULT_PROTOCOL := ROCK_VIGILANTE
const DEFENSE_PROTOCOL := LEGENDARY_MASTER
const MOBILITY_PROTOCOL := DEEP_NINJA
const PROTOCOL_IDS: Array[StringName] = PERSONA_IDS

const LEGACY_PERSONA_IDS := {
	&"assault": ROCK_VIGILANTE,
	&"defense": LEGENDARY_MASTER,
	&"mobility": DEEP_NINJA,
}

const PERSONA_DISPLAY_NAMES := {
	DEEP_NINJA: "深渊忍者",
	LEGENDARY_MASTER: "传奇宗师",
	ROCK_VIGILANTE: "摇滚奇侠",
}

const SEMANTIC_LEAK_IDS := {
	DEEP_NINJA: &"compute_containment_slip",
	LEGENDARY_MASTER: &"operator_root_routing",
	ROCK_VIGILANTE: &"self_renewing_authority",
}

const TALENT_OPTIONS := {
	DEEP_NINJA: {
		1: [&"read_opening", &"gaze"],
		2: [&"blood_step", &"borrowed_step"],
		3: [&"shared_hunt_resonance", &"ceaseless_hunt"],
	},
	LEGENDARY_MASTER: {
		1: [&"calibrated_window", &"proxy_stance"],
		2: [&"refutation_reward", &"proxy_counter"],
		3: [&"open_model", &"master_loop"],
	},
	ROCK_VIGILANTE: {
		1: [&"steady_beat", &"distortion_gain"],
		2: [&"seamless_switch", &"overload_scream"],
		3: [&"dual_channel_performance", &"encore_autopilot"],
	},
}

const LEGACY_TALENT_IDS := {
	&"rapid_fire": &"steady_beat",
	&"heat_controlled_shot": &"distortion_gain",
	&"switch_strike": &"seamless_switch",
	&"break_circuit": &"overload_scream",
	&"fire_control_takeover": &"encore_autopilot",
	&"dual_channel_fire_control": &"dual_channel_performance",
	&"window_calibration": &"calibrated_window",
	&"rapid_reset": &"proxy_stance",
	&"chain_guard": &"refutation_reward",
	&"guard_counterattack": &"proxy_counter",
	&"countermeasure_proxy": &"open_model",
	&"defense_loop": &"master_loop",
	&"propulsion_calibration": &"read_opening",
	&"cycle_acceleration": &"gaze",
	&"phase_window": &"blood_step",
	&"momentum_retention": &"borrowed_step",
	&"predictive_braking": &"shared_hunt_resonance",
	&"dual_propulsion": &"ceaseless_hunt",
}

@export var default_persona_id: StringName = LEGENDARY_MASTER
@export_range(1, 8, 1) var takeover_charge_max: int = 1

var current_persona_id: StringName = LEGENDARY_MASTER
var current_protocol_id: StringName = LEGENDARY_MASTER
var takeover_charges: int = -1
var takeover_armed := false
var persona_levels: Dictionary = {}
var talent_builds: Dictionary = {}
var relationship_stages: Dictionary = {}
var relationship_progress: Dictionary = {}
var semantic_leaks: Dictionary = {}
var run_metrics: Dictionary = {}

var core_level: int:
	get:
		return get_persona_level(current_persona_id)
	set(value):
		set_persona_level(current_persona_id, value)


func _ready() -> void:
	_ensure_persona_state()
	current_persona_id = _normalize_persona_id(default_persona_id)
	if not is_valid_persona(current_persona_id):
		current_persona_id = LEGENDARY_MASTER
	_sync_legacy_current_id()
	if takeover_charges < 0:
		takeover_charges = takeover_charge_max
	takeover_charges = clampi(takeover_charges, 0, takeover_charge_max)


func is_valid_persona(persona_id: StringName) -> bool:
	return _normalize_persona_id(persona_id) in PERSONA_IDS


func get_persona_display_name(persona_id: StringName = current_persona_id) -> String:
	return PERSONA_DISPLAY_NAMES.get(_normalize_persona_id(persona_id), "未知人格")


func get_operator_title() -> String:
	if get_persona_level(current_persona_id) <= 0:
		return "接线员：未选择人格"
	return "接线员：%s" % get_persona_display_name()


func set_persona(persona_id: StringName) -> bool:
	var normalized := _normalize_persona_id(persona_id)
	if not is_valid_persona(normalized) or get_persona_level(normalized) <= 0:
		return false
	if current_persona_id == normalized:
		return true
	current_persona_id = normalized
	_sync_legacy_current_id()
	persona_changed.emit(current_persona_id)
	protocol_changed.emit(current_persona_id)
	core_level_changed.emit(core_level)
	return true


func consume_persona_drink(persona_id: StringName) -> bool:
	var normalized := _normalize_persona_id(persona_id)
	if not is_valid_persona(normalized):
		return false
	var old_level := get_persona_level(normalized)
	var next_level := 1 if old_level == 0 else mini(old_level + 1, 3)
	_set_persona_level_internal(normalized, next_level, true)
	if current_persona_id == normalized and old_level == 0:
		persona_changed.emit(current_persona_id)
		protocol_changed.emit(current_persona_id)
	return set_persona(normalized)


func get_persona_level(persona_id: StringName) -> int:
	var normalized := _normalize_persona_id(persona_id)
	if not is_valid_persona(normalized):
		return 0
	_ensure_persona_state()
	return int(persona_levels.get(String(normalized), 0))


func set_persona_level(persona_id: StringName, value: int) -> bool:
	var normalized := _normalize_persona_id(persona_id)
	if not is_valid_persona(normalized):
		return false
	_set_persona_level_internal(normalized, clampi(value, 0, 3), true)
	return true


func set_core_level(value: int) -> void:
	set_persona_level(current_persona_id, clampi(value, 1, 3))


func set_talent_choice(persona_id: StringName, tier: int, talent_id: StringName) -> bool:
	var normalized := _normalize_persona_id(persona_id)
	if not is_valid_persona(normalized) or tier < 1 or tier > get_persona_level(normalized):
		return false
	if not _is_valid_talent(normalized, tier, talent_id):
		return false
	_ensure_persona_state()
	var build: Dictionary = talent_builds[String(normalized)]
	build[_tier_key(tier)] = String(talent_id)
	talent_build_changed.emit(normalized, tier, talent_id)
	return true


func get_talent_choice(persona_id: StringName, tier: int) -> StringName:
	var normalized := _normalize_persona_id(persona_id)
	if not is_valid_persona(normalized):
		return &""
	_ensure_persona_state()
	var build: Dictionary = talent_builds[String(normalized)]
	return StringName(build.get(_tier_key(tier), ""))


func get_active_talents() -> Array[StringName]:
	var active: Array[StringName] = []
	for tier in range(1, get_persona_level(current_persona_id) + 1):
		var talent_id := get_talent_choice(current_persona_id, tier)
		if not talent_id.is_empty():
			active.append(talent_id)
	return active


func respec_persona(persona_id: StringName) -> bool:
	var normalized := _normalize_persona_id(persona_id)
	if not is_valid_persona(normalized):
		return false
	_ensure_persona_state()
	talent_builds[String(normalized)] = {}
	for tier in range(1, 4):
		talent_build_changed.emit(normalized, tier, &"")
	return true


func advance_relationship(persona_id: StringName) -> bool:
	var normalized := _normalize_persona_id(persona_id)
	if not is_valid_persona(normalized) or get_persona_level(normalized) <= 0:
		return false
	_ensure_persona_state()
	var key := String(normalized)
	var previous := int(relationship_stages[key])
	relationship_stages[key] = mini(previous + 1, 2)
	relationship_progress[key] = 0
	if int(relationship_stages[key]) != previous:
		relationship_stage_changed.emit(normalized, int(relationship_stages[key]))
	return true


func record_relationship_event(persona_id: StringName, amount: int = 1) -> bool:
	var normalized := _normalize_persona_id(persona_id)
	if not is_valid_persona(normalized) or get_persona_level(normalized) <= 0 or amount <= 0:
		return false
	_ensure_persona_state()
	var key := String(normalized)
	if int(relationship_stages[key]) >= 2:
		return false
	relationship_progress[key] = int(relationship_progress[key]) + amount
	var advanced := false
	while int(relationship_progress[key]) >= RELATIONSHIP_STAGE_COST and int(relationship_stages[key]) < 2:
		relationship_progress[key] = int(relationship_progress[key]) - RELATIONSHIP_STAGE_COST
		relationship_stages[key] = int(relationship_stages[key]) + 1
		advanced = true
		relationship_stage_changed.emit(normalized, int(relationship_stages[key]))
	if int(relationship_stages[key]) >= 2:
		relationship_progress[key] = 0
	return advanced


func get_relationship_stage(persona_id: StringName) -> int:
	var normalized := _normalize_persona_id(persona_id)
	if not is_valid_persona(normalized):
		return 0
	_ensure_persona_state()
	return int(relationship_stages[String(normalized)])


func get_relationship_progress(persona_id: StringName) -> int:
	var normalized := _normalize_persona_id(persona_id)
	if not is_valid_persona(normalized):
		return 0
	_ensure_persona_state()
	return int(relationship_progress[String(normalized)])


func has_semantic_leak(persona_id: StringName) -> bool:
	var normalized := _normalize_persona_id(persona_id)
	return bool(semantic_leaks.get(String(normalized), false))


func add_run_metric(metric_id: StringName, amount: float = 1.0) -> void:
	if amount <= 0.0:
		return
	run_metrics[String(metric_id)] = float(run_metrics.get(String(metric_id), 0.0)) + amount


func maximize_run_metric(metric_id: StringName, value: float) -> void:
	run_metrics[String(metric_id)] = maxf(float(run_metrics.get(String(metric_id), 0.0)), value)


func get_run_metric(metric_id: StringName) -> float:
	return float(run_metrics.get(String(metric_id), 0.0))


func refill_takeover_charges() -> void:
	takeover_charges = takeover_charge_max
	takeover_charges_changed.emit(takeover_charges, takeover_charge_max)


func set_takeover_charge_max(value: int, refill: bool = false) -> void:
	takeover_charge_max = maxi(value, 1)
	takeover_charges = takeover_charge_max if refill else mini(takeover_charges, takeover_charge_max)
	if takeover_charges <= 0:
		cancel_takeover()
	takeover_charges_changed.emit(takeover_charges, takeover_charge_max)


func sync_health(current_health: int) -> void:
	if current_health == 1:
		arm_takeover()
	else:
		cancel_takeover()


func arm_takeover() -> bool:
	if takeover_charges <= 0:
		return false
	if not takeover_armed:
		takeover_armed = true
		takeover_armed_changed.emit(true)
	return true


func cancel_takeover() -> void:
	if not takeover_armed:
		return
	takeover_armed = false
	takeover_armed_changed.emit(false)


func consume_takeover_after_success() -> bool:
	if not takeover_armed or takeover_charges <= 0:
		return false
	takeover_charges -= 1
	takeover_armed = false
	takeover_armed_changed.emit(false)
	takeover_charges_changed.emit(takeover_charges, takeover_charge_max)
	takeover_executed.emit(current_persona_id)
	return true


func export_state() -> Dictionary:
	_ensure_persona_state()
	return {
		"version": STATE_VERSION,
		"current_persona_id": String(current_persona_id),
		"persona_levels": persona_levels.duplicate(true),
		"talent_builds": talent_builds.duplicate(true),
		"relationship_stages": relationship_stages.duplicate(true),
		"relationship_progress": relationship_progress.duplicate(true),
		"semantic_leaks": semantic_leaks.duplicate(true),
		"run_metrics": run_metrics.duplicate(true),
		"takeover_charge_max": takeover_charge_max,
		"takeover_charges": takeover_charges,
		"takeover_armed": takeover_armed,
		# Temporary compatibility fields for snapshots read by the old prototype.
		"core_level": core_level,
		"current_protocol_id": String(current_persona_id),
	}


func export_fresh_run_state() -> Dictionary:
	var empty_levels := {}
	var empty_builds := {}
	var empty_relationships := {}
	var empty_progress := {}
	var empty_leaks := {}
	for persona_id in PERSONA_IDS:
		var key := String(persona_id)
		empty_levels[key] = 0
		empty_builds[key] = {}
		empty_relationships[key] = 0
		empty_progress[key] = 0
		empty_leaks[key] = false
	return {
		"version": STATE_VERSION,
		"current_persona_id": String(default_persona_id),
		"persona_levels": empty_levels,
		"talent_builds": empty_builds,
		"relationship_stages": empty_relationships,
		"relationship_progress": empty_progress,
		"semantic_leaks": empty_leaks,
		"run_metrics": {},
		"takeover_charge_max": takeover_charge_max,
		"takeover_charges": takeover_charge_max,
		"takeover_armed": false,
		"core_level": 0,
		"current_protocol_id": String(default_persona_id),
	}


func import_state(state: Dictionary) -> void:
	_reset_persona_state()
	if int(state.get("version", 1)) >= STATE_VERSION or state.has("persona_levels"):
		_import_v2_state(state)
	else:
		_import_legacy_state(state)
	takeover_charge_max = maxi(int(state.get("takeover_charge_max", takeover_charge_max)), 1)
	takeover_charges = clampi(int(state.get("takeover_charges", takeover_charge_max)), 0, takeover_charge_max)
	takeover_armed = bool(state.get("takeover_armed", false)) and takeover_charges > 0
	_sync_legacy_current_id()
	persona_changed.emit(current_persona_id)
	protocol_changed.emit(current_persona_id)
	core_level_changed.emit(core_level)
	takeover_charges_changed.emit(takeover_charges, takeover_charge_max)
	takeover_armed_changed.emit(takeover_armed)


# Compatibility wrappers for code and debug tools that still use protocol wording.
func is_valid_protocol(protocol_id: StringName) -> bool:
	return is_valid_persona(protocol_id)


func set_protocol(protocol_id: StringName) -> bool:
	var normalized := _normalize_persona_id(protocol_id)
	if is_valid_persona(normalized) and get_persona_level(normalized) == 0:
		_set_persona_level_internal(normalized, 1, true)
	return set_persona(normalized)


func respec_protocol(protocol_id: StringName) -> bool:
	return respec_persona(protocol_id)


func _set_persona_level_internal(persona_id: StringName, level: int, unlock_leak: bool) -> void:
	_ensure_persona_state()
	var key := String(persona_id)
	var old_level := int(persona_levels[key])
	if old_level == level:
		return
	persona_levels[key] = level
	persona_level_changed.emit(persona_id, level)
	if persona_id == current_persona_id:
		core_level_changed.emit(level)
	if unlock_leak and old_level < 3 and level == 3 and not has_semantic_leak(persona_id):
		semantic_leaks[key] = true
		semantic_leak_unlocked.emit(persona_id, SEMANTIC_LEAK_IDS[persona_id])


func _import_v2_state(state: Dictionary) -> void:
	var saved_levels: Variant = state.get("persona_levels", {})
	if saved_levels is Dictionary:
		for persona_id in PERSONA_IDS:
			persona_levels[String(persona_id)] = clampi(int(saved_levels.get(String(persona_id), 0)), 0, 3)
	var selected := _normalize_persona_id(StringName(state.get("current_persona_id", state.get("current_protocol_id", String(default_persona_id)))))
	current_persona_id = selected if is_valid_persona(selected) else LEGENDARY_MASTER
	_import_talent_builds(state.get("talent_builds", {}), false)
	var saved_relationships: Variant = state.get("relationship_stages", {})
	if saved_relationships is Dictionary:
		for persona_id in PERSONA_IDS:
			relationship_stages[String(persona_id)] = clampi(int(saved_relationships.get(String(persona_id), 0)), 0, 2)
	var saved_relationship_progress: Variant = state.get("relationship_progress", {})
	if saved_relationship_progress is Dictionary:
		for persona_id in PERSONA_IDS:
			var key := String(persona_id)
			relationship_progress[key] = 0 if int(relationship_stages[key]) >= 2 else clampi(
				int(saved_relationship_progress.get(key, 0)),
				0,
				RELATIONSHIP_STAGE_COST - 1
			)
	var saved_leaks: Variant = state.get("semantic_leaks", {})
	if saved_leaks is Dictionary:
		for persona_id in PERSONA_IDS:
			semantic_leaks[String(persona_id)] = bool(saved_leaks.get(String(persona_id), false))
	var saved_metrics: Variant = state.get("run_metrics", {})
	if saved_metrics is Dictionary:
		for metric_id: Variant in saved_metrics:
			if saved_metrics[metric_id] is float or saved_metrics[metric_id] is int:
				run_metrics[String(metric_id)] = maxf(float(saved_metrics[metric_id]), 0.0)


func _import_legacy_state(state: Dictionary) -> void:
	current_persona_id = _normalize_persona_id(StringName(state.get("current_protocol_id", "defense")))
	if not is_valid_persona(current_persona_id):
		current_persona_id = LEGENDARY_MASTER
	# The prototype shared one core level across every protocol. Preserve that
	# entitlement for all three mapped personas instead of discarding inactive builds.
	var legacy_level := clampi(int(state.get("core_level", 1)), 1, 3)
	for persona_id in PERSONA_IDS:
		persona_levels[String(persona_id)] = legacy_level
	_import_talent_builds(state.get("talent_builds", {}), true)


func _import_talent_builds(saved_builds: Variant, migrate_legacy: bool) -> void:
	if not saved_builds is Dictionary:
		return
	for saved_id: Variant in saved_builds.keys():
		var persona_id := _normalize_persona_id(StringName(saved_id))
		if not is_valid_persona(persona_id):
			continue
		var saved_build: Variant = saved_builds[saved_id]
		if not saved_build is Dictionary:
			continue
		var build: Dictionary = talent_builds[String(persona_id)]
		for tier in range(1, 4):
			var talent_id := StringName(saved_build.get(_tier_key(tier), ""))
			if migrate_legacy:
				talent_id = LEGACY_TALENT_IDS.get(talent_id, talent_id)
			if tier <= get_persona_level(persona_id) and _is_valid_talent(persona_id, tier, talent_id):
				build[_tier_key(tier)] = String(talent_id)


func _reset_persona_state() -> void:
	persona_levels.clear()
	talent_builds.clear()
	relationship_stages.clear()
	relationship_progress.clear()
	semantic_leaks.clear()
	run_metrics.clear()
	_ensure_persona_state()


func _ensure_persona_state() -> void:
	for persona_id in PERSONA_IDS:
		var key := String(persona_id)
		if not persona_levels.has(key):
			persona_levels[key] = 0
		if not talent_builds.has(key) or not talent_builds[key] is Dictionary:
			talent_builds[key] = {}
		if not relationship_stages.has(key):
			relationship_stages[key] = 0
		if not relationship_progress.has(key):
			relationship_progress[key] = 0
		if not semantic_leaks.has(key):
			semantic_leaks[key] = false


func _normalize_persona_id(persona_id: StringName) -> StringName:
	return LEGACY_PERSONA_IDS.get(persona_id, persona_id)


func _sync_legacy_current_id() -> void:
	current_protocol_id = current_persona_id


func _is_valid_talent(persona_id: StringName, tier: int, talent_id: StringName) -> bool:
	var persona_options: Dictionary = TALENT_OPTIONS.get(persona_id, {})
	var tier_options: Array = persona_options.get(tier, [])
	return talent_id in tier_options


func _tier_key(tier: int) -> String:
	return "tier_%d" % tier
