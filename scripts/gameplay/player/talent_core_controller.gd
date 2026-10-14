class_name TalentCoreController
extends Node

signal core_level_changed(level: int)
signal protocol_changed(protocol_id: StringName)
signal talent_build_changed(protocol_id: StringName, tier: int, talent_id: StringName)
signal takeover_armed_changed(armed: bool)
signal takeover_charges_changed(current: int, maximum: int)
signal takeover_executed(protocol_id: StringName)

const ASSAULT_PROTOCOL := &"assault"
const DEFENSE_PROTOCOL := &"defense"
const MOBILITY_PROTOCOL := &"mobility"
const PROTOCOL_IDS: Array[StringName] = [ASSAULT_PROTOCOL, DEFENSE_PROTOCOL, MOBILITY_PROTOCOL]

const TALENT_OPTIONS := {
	ASSAULT_PROTOCOL: {
		1: [&"rapid_fire", &"heat_controlled_shot"],
		2: [&"switch_strike", &"break_circuit"],
		3: [&"fire_control_takeover", &"dual_channel_fire_control"],
	},
	DEFENSE_PROTOCOL: {
		1: [&"window_calibration", &"rapid_reset"],
		2: [&"chain_guard", &"guard_counterattack"],
		3: [&"countermeasure_proxy", &"defense_loop"],
	},
	MOBILITY_PROTOCOL: {
		1: [&"propulsion_calibration", &"cycle_acceleration"],
		2: [&"phase_window", &"momentum_retention"],
		3: [&"predictive_braking", &"dual_propulsion"],
	},
}

@export_range(1, 3, 1) var core_level: int = 1
@export var default_protocol_id: StringName = DEFENSE_PROTOCOL
@export_range(1, 8, 1) var takeover_charge_max: int = 1

var current_protocol_id: StringName = DEFENSE_PROTOCOL
var takeover_charges: int = -1
var takeover_armed: bool = false
var talent_builds: Dictionary = {}


func _ready() -> void:
	_ensure_builds()
	current_protocol_id = default_protocol_id if is_valid_protocol(default_protocol_id) else DEFENSE_PROTOCOL
	if takeover_charges < 0:
		takeover_charges = takeover_charge_max
	takeover_charges = clampi(takeover_charges, 0, takeover_charge_max)


func is_valid_protocol(protocol_id: StringName) -> bool:
	return protocol_id in PROTOCOL_IDS


func set_protocol(protocol_id: StringName) -> bool:
	if not is_valid_protocol(protocol_id):
		return false
	if current_protocol_id == protocol_id:
		return true
	current_protocol_id = protocol_id
	protocol_changed.emit(current_protocol_id)
	return true


func set_core_level(value: int) -> void:
	var next_level := clampi(value, 1, 3)
	if core_level == next_level:
		return
	core_level = next_level
	core_level_changed.emit(core_level)


func set_talent_choice(protocol_id: StringName, tier: int, talent_id: StringName) -> bool:
	if not is_valid_protocol(protocol_id) or tier < 1 or tier > core_level:
		return false
	if not _is_valid_talent(protocol_id, tier, talent_id):
		return false
	_ensure_builds()
	var build: Dictionary = talent_builds[String(protocol_id)]
	build[_tier_key(tier)] = String(talent_id)
	talent_build_changed.emit(protocol_id, tier, talent_id)
	return true


func get_talent_choice(protocol_id: StringName, tier: int) -> StringName:
	if not is_valid_protocol(protocol_id):
		return &""
	_ensure_builds()
	var build: Dictionary = talent_builds[String(protocol_id)]
	return StringName(build.get(_tier_key(tier), ""))


func get_active_talents() -> Array[StringName]:
	var active: Array[StringName] = []
	for tier in range(1, core_level + 1):
		var talent_id := get_talent_choice(current_protocol_id, tier)
		if not talent_id.is_empty():
			active.append(talent_id)
	return active


func respec_protocol(protocol_id: StringName) -> bool:
	if not is_valid_protocol(protocol_id):
		return false
	_ensure_builds()
	talent_builds[String(protocol_id)] = {}
	for tier in range(1, 4):
		talent_build_changed.emit(protocol_id, tier, &"")
	return true


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
	takeover_executed.emit(current_protocol_id)
	return true


func export_state() -> Dictionary:
	_ensure_builds()
	return {
		"core_level": core_level,
		"current_protocol_id": String(current_protocol_id),
		"talent_builds": talent_builds.duplicate(true),
		"takeover_charge_max": takeover_charge_max,
		"takeover_charges": takeover_charges,
		"takeover_armed": takeover_armed,
	}


func import_state(state: Dictionary) -> void:
	core_level = clampi(int(state.get("core_level", core_level)), 1, 3)
	takeover_charge_max = maxi(int(state.get("takeover_charge_max", takeover_charge_max)), 1)
	current_protocol_id = StringName(state.get("current_protocol_id", String(default_protocol_id)))
	if not is_valid_protocol(current_protocol_id):
		current_protocol_id = DEFENSE_PROTOCOL
	talent_builds.clear()
	_ensure_builds()
	var saved_builds: Variant = state.get("talent_builds", {})
	if saved_builds is Dictionary:
		_import_talent_builds(saved_builds)
	takeover_charges = clampi(int(state.get("takeover_charges", takeover_charge_max)), 0, takeover_charge_max)
	takeover_armed = bool(state.get("takeover_armed", false)) and takeover_charges > 0
	core_level_changed.emit(core_level)
	protocol_changed.emit(current_protocol_id)
	takeover_charges_changed.emit(takeover_charges, takeover_charge_max)
	takeover_armed_changed.emit(takeover_armed)


func _ensure_builds() -> void:
	for protocol_id in PROTOCOL_IDS:
		var key := String(protocol_id)
		if not talent_builds.has(key) or not talent_builds[key] is Dictionary:
			talent_builds[key] = {}


func _import_talent_builds(saved_builds: Dictionary) -> void:
	for protocol_id in PROTOCOL_IDS:
		var protocol_key := String(protocol_id)
		var saved_build: Variant = saved_builds.get(protocol_key, {})
		if not saved_build is Dictionary:
			continue
		var build: Dictionary = talent_builds[protocol_key]
		for tier in range(1, 4):
			var talent_id := StringName(saved_build.get(_tier_key(tier), ""))
			if tier <= core_level and _is_valid_talent(protocol_id, tier, talent_id):
				build[_tier_key(tier)] = String(talent_id)


func _is_valid_talent(protocol_id: StringName, tier: int, talent_id: StringName) -> bool:
	var protocol_options: Dictionary = TALENT_OPTIONS.get(protocol_id, {})
	var tier_options: Array = protocol_options.get(tier, [])
	return talent_id in tier_options


func _tier_key(tier: int) -> String:
	return "tier_%d" % tier
