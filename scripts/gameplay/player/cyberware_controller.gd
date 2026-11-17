class_name CyberwareController
extends Node

const CyberwareCircuitStateScript := preload("res://scripts/gameplay/player/cyberware_circuit_state.gd")

signal cyberware_changed(modules: PackedStringArray)
signal module_triggered(module_id: StringName)
signal circuit_changed(state: Dictionary)
signal circuit_round_ready(plan: Dictionary)
signal circuit_queue_changed(queues: Dictionary)
signal circuit_step_started(slot_index: int, module_id: StringName, effect_id: StringName)
signal circuit_round_finished(request_kind: StringName)

const ACTIVE_NEURAL_SWITCH := &"active_neural_switch"
const COMBAT_SYNAPSE_SENSOR := &"combat_synapse_sensor"
const EVENT_STARTER_IDS := {
	1: COMBAT_SYNAPSE_SENSOR,
	2: &"combat_synapse_sensor_dash",
	4: &"combat_synapse_sensor_guard",
	8: &"combat_synapse_sensor_hit",
	16: &"combat_synapse_sensor_kill",
}
const EVENT_STARTER_LABELS := {1: "开火", 2: "突进", 4: "格挡", 8: "命中", 16: "击杀"}
const RHYTHM_PULSER := &"rhythm_pulser"
const SMART_FIRE := &"smart_fire"
const EXPLOSIVE_MAGAZINE := &"explosive_magazine"
const TACTICAL_COPROCESSOR := &"tactical_coprocessor"
const OPTICAL_INTRUDER := &"optical_intruder"
const KILL_HEAT_SINK := &"kill_energy_sink"
const HEAT_THRESHOLD_PULSER := &"shock_pulser"
const MOMENTUM_RECOVERY_TENDON := &"momentum_recovery_tendon"
const TRAJECTORY_ECHO_PROCESSOR := &"trajectory_echo_processor"
const BALLISTIC_TAKEOVER_PROTOCOL := &"ballistic_takeover_protocol"
const ARC_BALLISTIC_CORTEX := &"arc_ballistic_cortex"
const INERTIAL_INVERSION_VERTEBRA := &"inertial_inversion_vertebra"
const AXON_RECYCLER := &"axon_recycler"
const MICRO_ROTOR_REFLEX_BUNDLE := &"micro_rotor_reflex_bundle"
const PREDATORY_VESTIBULAR_RING := &"predatory_vestibular_ring"
const GUARD_COPROCESSOR := &"guard_coprocessor"
const INSTRUCTION_MIRROR_SYNAPSE := &"instruction_mirror_synapse"
const OMNIDIRECTIONAL_REFLECTION_MATRIX := &"omnidirectional_reflection_matrix"
const CALAMITY_FLAME := &"calamity_flame"
const RELAY_STARTER := &"relay_starter"
const WORLD := &"world"
const BALLISTIC_SPLICER := &"ballistic_splicer"
const FISSION_CORE := &"fission_core"
const PENETRATION_BOOSTER := &"penetration_booster"
const ARC_ATTACK_MEMORY_SECONDS := 3.0
const MICRO_ROTOR_ATTACK_MEMORY_SECONDS := 3.0
const PREDATORY_ATTACK_MEMORY_SECONDS := 3.0
const CIRCUIT_STEP_SECONDS := 0.05
const CIRCUIT_MIN_STEP_SECONDS := 0.01
const CIRCUIT_GUARD_PERFECT_SECONDS := 0.08
const CIRCUIT_GUARD_TOTAL_SECONDS := 0.28
const CIRCUIT_REQUEST_PRIORITY := [&"active", &"event", &"timed"]
const CIRCUIT_STARTERS := {
	&"active": ACTIVE_NEURAL_SWITCH,
	&"event": COMBAT_SYNAPSE_SENSOR,
	&"timed": RHYTHM_PULSER,
}
const CIRCUIT_STARTER_INTERVALS := {
	&"active": 0.175,
	&"event": 0.375,
	&"timed": 1.25,
}

var modules: PackedStringArray = []
var circuit = CyberwareCircuitStateScript.new()
var _data_by_module: Dictionary = {}
var _trajectory_echo_cooldown_remaining := 0.0
var _ballistic_takeover_cooldown_remaining := 0.0
var _inertial_inversion_cooldown_remaining := 0.0
var _inertial_inversion_triggered_this_dash := false
var _arc_attack_groups: Dictionary = {}
var _micro_rotor_attack_groups: Dictionary = {}
var _predatory_attack_groups: Dictionary = {}
var _predatory_dash_refresh_pending := false
var _circuit_queues: Dictionary = {}
var _fire_event_serial := 0
var _circuit_cooldowns := {&"active": 0.0, &"event": 0.0, &"timed": 0.0}
var _active_circuit_round: Dictionary = {}
var _circuit_step_remaining := 0.0
var _circuit_modifiers := {&"homing": 0, &"explosion": 0, &"arc": 0, &"echo": 0}
var _pending_weapon_payload: Dictionary = {}
var _weapon_payload_hit_groups: Dictionary = {}
var _circuit_weapon_call_active := false
var _cyber_guard_windows: Array[Dictionary] = []
var _circuit_step_interval := CIRCUIT_STEP_SECONDS
var _circuit_pending_echoes: Array[Dictionary] = []
var _circuit_calamity_layers := 0
var _circuit_current_scale := 1.0
var _signal_attacks: Array[Dictionary] = []
var _signal_group_serial := 0
var _circuit_payload_group_override := 0
var _circuit_current_pierce := 0
var _circuit_current_penetration_boost := false
var _circuit_current_visual_scale := 1.0
var _world_stop_remaining := 0.0
var _world_stop_floor := -1
var _world_stop_uses := 0
var _world_previous_player_mode := Node.PROCESS_MODE_INHERIT
var _world_child_modes: Dictionary = {}
var _circuit_round_serial := 0
var _event_seen: Dictionary = {}
var _circuit_copy_serial := 0
var _circuit_abort_slot := -1
var _circuit_abort_remaining := 0.0
var _nonprojectile_payloads: Dictionary = {}
var _rhythm_remaining := 1.25


func _ready() -> void:
	circuit.configure_definitions(_circuit_definitions())
	ensure_default_starter()
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.damage_resolved.connect(_on_damage_resolved)
		events.perfect_guarded.connect(_on_perfect_guarded)
	var dash := get_parent().get_node_or_null("DashController") as DashController
	if dash != null:
		dash.dash_ended.connect(_on_dash_ended)


func _exit_tree() -> void:
	_end_world_stop()


func _physics_process(delta: float) -> void:
	circuit.advance(delta)
	if _world_stop_remaining > 0.0:
		_world_stop_remaining = maxf(_world_stop_remaining - delta, 0.0)
		_tick_circuit_runtime(delta)
		if _world_stop_remaining <= 0.0:
			_end_world_stop()
		return
	_circuit_abort_remaining = maxf(_circuit_abort_remaining - delta, 0.0)
	_tick_circuit_runtime(delta)
	_trajectory_echo_cooldown_remaining = maxf(_trajectory_echo_cooldown_remaining - delta, 0.0)
	_ballistic_takeover_cooldown_remaining = maxf(_ballistic_takeover_cooldown_remaining - delta, 0.0)
	_inertial_inversion_cooldown_remaining = maxf(_inertial_inversion_cooldown_remaining - delta, 0.0)
	_tick_arc_attack_groups(delta)
	_tick_micro_rotor_attack_groups(delta)
	_tick_predatory_attack_groups(delta)
	_tick_circuit_echoes(delta)
	_try_ballistic_takeover()


func set_equipped_item(item: InventoryItem) -> void:
	modules = ComponentRolls.cyberware_modules(item)
	_data_by_module.clear()
	for module_id in modules:
		var path := ComponentRolls.cyberware_resource_path(module_id)
		if not path.is_empty():
			_data_by_module[StringName(module_id)] = load(path)
	if not has_module(ARC_BALLISTIC_CORTEX):
		_arc_attack_groups.clear()
	if not has_module(INERTIAL_INVERSION_VERTEBRA):
		_inertial_inversion_triggered_this_dash = false
	if not has_module(MICRO_ROTOR_REFLEX_BUNDLE):
		_micro_rotor_attack_groups.clear()
	if not has_module(PREDATORY_VESTIBULAR_RING):
		_predatory_attack_groups.clear()
		_predatory_dash_refresh_pending = false
	cyberware_changed.emit(modules.duplicate())


func clear() -> void:
	set_equipped_item(null)


func has_module(module_id: StringName) -> bool:
	return module_id in modules or (module_id == AXON_RECYCLER and _circuit_has_module(module_id))


func configure_projectile(projectile: CombatProjectile, aim_direction: Vector2, weapon_payload: Dictionary = {}) -> void:
	if projectile == null:
		return
	if has_module(SMART_FIRE):
		var smart := _data(SMART_FIRE)
		var target := _acquire_target(projectile.global_position, aim_direction, smart.targeting_half_angle_degrees)
		if target != null:
			projectile.configure_homing(target, smart.homing_turn_degrees_per_second)
			module_triggered.emit(SMART_FIRE)
	if has_module(EXPLOSIVE_MAGAZINE) and not projectile.has_area_behavior:
		var explosive := _data(EXPLOSIVE_MAGAZINE)
		projectile.configure_explosion(explosive.explosion_radius, explosive.explosion_damage)
	if has_module(ARC_BALLISTIC_CORTEX):
		projectile.configure_electric_arc()
	if _circuit_weapon_call_active:
		projectile.status_tags.append(&"cyberware_chain")
		projectile.circuit_base_explosion_radius = projectile.explosion_radius
		projectile.circuit_base_explosion_damage = projectile.explosion_damage
		projectile.circuit_base_area_behavior = projectile.has_area_behavior
		_apply_circuit_modifiers_to_projectile(projectile, aim_direction, _circuit_modifiers)
		if int(_circuit_modifiers.get(&"explosion", 0)) > 0 or int(_circuit_modifiers.get(&"arc", 0)) > 0 or int(_circuit_modifiers.get(&"echo", 0)) > 0:
			var group_id := _circuit_payload_group_override if _circuit_payload_group_override > 0 else projectile.feedback_group_id
			projectile.circuit_payload_group_id = group_id
			if not _weapon_payload_hit_groups.has(group_id):
				_weapon_payload_hit_groups[group_id] = false
		if _circuit_calamity_layers > 0:
			var player := get_parent() as PlayerController
			var weapon := player.weapons.get_current_weapon() if player != null and player.weapons != null else null
			var blade_range := weapon.attack_range if weapon != null else 0.0
			projectile.configure_calamity_blade(blade_range)
			for layer in range(1, _circuit_calamity_layers):
				var extra := (load("res://scenes/combat/projectile.tscn") as PackedScene).instantiate() as CombatProjectile
				CombatProjectile.room_for_actor(projectile).add_child(extra)
				extra.global_position = projectile.global_position
				extra.setup(get_parent(), CombatFaction.Id.PLAYER, projectile.direction.rotated(deg_to_rad(float(layer) * 2.0)), projectile.damage, projectile.speed)
				extra.weapon_id = projectile.weapon_id
				extra.damage_type = projectile.damage_type
				extra.status_tags = projectile.status_tags.duplicate()
				extra.feedback_group_id = projectile.feedback_group_id
				extra.circuit_arc_chains = projectile.circuit_arc_chains
				extra.circuit_echo_layers = projectile.circuit_echo_layers
				extra.circuit_payload_group_id = projectile.circuit_payload_group_id
				extra.circuit_base_explosion_radius = projectile.circuit_base_explosion_radius
				extra.circuit_base_explosion_damage = projectile.circuit_base_explosion_damage
				extra.circuit_base_area_behavior = projectile.circuit_base_area_behavior
				if is_instance_valid(projectile.homing_target):
					extra.configure_homing(projectile.homing_target, rad_to_deg(projectile.homing_turn_radians_per_second))
				if projectile.has_area_behavior:
					extra.configure_explosion(projectile.explosion_radius, projectile.explosion_damage)
				extra.lifetime = projectile.lifetime
				extra.configure_calamity_blade(blade_range)
				extra.circuit_pierce_remaining = _circuit_current_pierce
				extra.circuit_penetration_boost = _circuit_current_penetration_boost
				extra.circuit_visual_scale = _circuit_current_visual_scale
				extra._sync_visual()
		projectile.circuit_pierce_remaining = _circuit_current_pierce
		projectile.circuit_penetration_boost = _circuit_current_penetration_boost
		projectile.circuit_visual_scale = _circuit_current_visual_scale
		projectile._sync_visual()
	if not weapon_payload.is_empty():
		projectile.circuit_base_explosion_radius = projectile.explosion_radius
		projectile.circuit_base_explosion_damage = projectile.explosion_damage
		projectile.circuit_base_area_behavior = projectile.has_area_behavior
		_apply_circuit_modifiers_to_projectile(projectile, aim_direction, weapon_payload)
		if int(weapon_payload.get(&"explosion", 0)) > 0 or int(weapon_payload.get(&"arc", 0)) > 0 or int(weapon_payload.get(&"echo", 0)) > 0:
			projectile.circuit_payload_group_id = projectile.feedback_group_id


func take_pending_weapon_payload(group_id: int) -> Dictionary:
	if _circuit_weapon_call_active or _pending_weapon_payload.is_empty() or group_id <= 0:
		return {}
	var payload := _pending_weapon_payload.duplicate()
	_pending_weapon_payload.clear()
	if int(payload.get(&"explosion", 0)) > 0 or int(payload.get(&"arc", 0)) > 0 or int(payload.get(&"echo", 0)) > 0:
		_weapon_payload_hit_groups[group_id] = false
		if _weapon_payload_hit_groups.size() > 64:
			var oldest: int = _weapon_payload_hit_groups.keys()[0]
			_weapon_payload_hit_groups.erase(oldest)
	circuit_changed.emit(export_circuit_state())
	return payload


func claim_weapon_payload_hit(group_id: int) -> bool:
	if not _weapon_payload_hit_groups.has(group_id) or bool(_weapon_payload_hit_groups[group_id]):
		return false
	_weapon_payload_hit_groups[group_id] = true
	return true


func is_circuit_weapon_call_active() -> bool:
	return _circuit_weapon_call_active


func supports_automatic_fire(data: WeaponComponentData) -> bool:
	return (
		(has_module(TACTICAL_COPROCESSOR) or (get_parent() as PlayerController).persona_combat.is_nuclear_frenzy_active())
		and data != null
		and data.trigger_mode != WeaponComponentData.TriggerMode.CHARGE
		and (get_parent() as PlayerController).persona_combat.is_nuclear_frenzy_active() or data.attack_kind in [WeaponComponentData.AttackKind.PROJECTILE, WeaponComponentData.AttackKind.SPREAD]
	)


func augment_attack_context(data: WeaponComponentData, context: Dictionary) -> void:
	if _circuit_weapon_call_active:
		context["extra_status_tags"] = PackedStringArray(["cyberware_chain", "cyberware_weapon_call"])


func on_attack_committed(data: WeaponComponentData, context: Dictionary) -> void:
	pass


func reset_transient_state(preserve_queues: bool = false) -> void:
	_end_world_stop()
	circuit.clear_waiting_round()
	if not preserve_queues:
		_circuit_queues.clear()
	else:
		for key in _circuit_queues.keys():
			if String(key).contains("_gravity_"):
				_circuit_queues.erase(key)
	_circuit_cooldowns = {&"active": 0.0, &"event": 0.0, &"timed": 0.0}
	_active_circuit_round.clear()
	_circuit_abort_remaining = 0.0
	_circuit_modifiers = {&"homing": 0, &"explosion": 0, &"arc": 0, &"echo": 0}
	_signal_attacks.clear()
	_circuit_payload_group_override = 0
	_pending_weapon_payload.clear()
	_weapon_payload_hit_groups.clear()
	_event_seen.clear()
	_nonprojectile_payloads.clear()
	_circuit_step_interval = CIRCUIT_STEP_SECONDS
	_circuit_pending_echoes.clear()
	_circuit_calamity_layers = 0
	_circuit_current_scale = 1.0
	_circuit_weapon_call_active = false
	_cyber_guard_windows.clear()
	_rhythm_remaining = CIRCUIT_STARTER_INTERVALS[&"timed"]
	circuit_queue_changed.emit(_circuit_queues.duplicate(true))
	_predatory_dash_refresh_pending = false


func export_circuit_state() -> Dictionary:
	var state: Dictionary = circuit.export_state()
	var saved_queues := _circuit_queues.duplicate(true)
	for key in saved_queues:
		(saved_queues[key] as Dictionary).erase("weapon")
	state["runtime"] = {"queues": saved_queues, "world_floor": _world_stop_floor, "world_uses": _world_stop_uses}
	return state


func set_circuit_library_counts(counts: Dictionary) -> void:
	circuit.set_library_counts(counts)
	circuit_changed.emit(export_circuit_state())


func store_circuit_modules(module_ids: PackedStringArray, amount: int = 1) -> PackedStringArray:
	var stored := PackedStringArray()
	var counts := circuit.get_library_counts()
	for raw_id in module_ids:
		var module_id := StringName(raw_id)
		if module_id.is_empty() or ComponentRolls.cyberware_resource_path(module_id).is_empty():
			continue
		counts[module_id] = int(counts.get(module_id, 0)) + maxi(amount, 1)
		stored.append(String(module_id))
	if not stored.is_empty():
		circuit.set_library_counts(counts)
		circuit_changed.emit(export_circuit_state())
	return stored


func ensure_default_starter() -> bool:
	var counts := circuit.get_library_counts()
	var owns_starter := false
	var starter_to_install := COMBAT_SYNAPSE_SENSOR
	for starter_id in counts:
		if int(counts.get(starter_id, 0)) > 0 and (starter_id in CIRCUIT_STARTERS.values() or event_starter_mask(StringName(starter_id)) > 0):
			owns_starter = true
			starter_to_install = StringName(starter_id)
			break
	var changed := false
	if not owns_starter:
		counts[COMBAT_SYNAPSE_SENSOR] = 1
		circuit.set_library_counts(counts)
		changed = true
	var slots := circuit.get_slots()
	var has_installed_starter := false
	var has_installed_module := false
	for raw_id in slots:
		var module_id := StringName(raw_id)
		has_installed_module = has_installed_module or not module_id.is_empty()
		has_installed_starter = has_installed_starter or module_id in CIRCUIT_STARTERS.values()
		has_installed_starter = has_installed_starter or event_starter_mask(module_id) > 0
	if not has_installed_starter and not has_installed_module:
		slots[0] = String(starter_to_install)
		circuit.set_slots(slots)
		changed = true
	if changed:
		circuit_changed.emit(export_circuit_state())
	return changed


func roll_terminal_module() -> StringName:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var run := get_node_or_null("/root/RunManager")
	var floor_number: int = run.floor_index + 1 if run != null else 1
	var rolled := ComponentRolls.guaranteed_cyberware_drop(
		floor_number, rng, circuit.get_library_counts(), CyberwareData.Grade.MILITARY
	)
	var modules := ComponentRolls.cyberware_modules(rolled)
	return StringName(modules[0]) if not modules.is_empty() else &""


func set_circuit_slots(module_ids: PackedStringArray) -> Dictionary:
	var result: Dictionary = circuit.set_slots(module_ids)
	if bool(result.get("ok", false)):
		_rhythm_remaining = CIRCUIT_STARTER_INTERVALS[&"timed"]
		circuit_changed.emit(export_circuit_state())
	return result


func merge_event_starters(subject_id: StringName, material_id: StringName) -> bool:
	var subject_mask := event_starter_mask(subject_id)
	var material_mask := event_starter_mask(material_id)
	if subject_mask == 0 or material_mask == 0 or subject_mask & material_mask:
		return false
	var counts := circuit.get_library_counts()
	if int(counts.get(subject_id, 0)) <= 0 or int(counts.get(material_id, 0)) <= 0:
		return false
	var slots := circuit.get_slots()
	var subject_slot := -1
	for index in slots.size():
		if StringName(slots[index]) == subject_id:
			subject_slot = index
			break
	if int(counts.get(material_id, 0)) <= circuit.get_installed_count(material_id):
		return false
	var combined_id := event_starter_id(subject_mask | material_mask)
	counts[subject_id] = int(counts[subject_id]) - 1
	counts[material_id] = int(counts[material_id]) - 1
	counts[combined_id] = int(counts.get(combined_id, 0)) + 1
	circuit.set_library_counts(counts)
	if subject_slot >= 0:
		slots[subject_slot] = String(combined_id)
		if not bool(circuit.set_slots(slots).get("ok", false)):
			counts[subject_id] = int(counts[subject_id]) + 1
			counts[material_id] = int(counts[material_id]) + 1
			counts[combined_id] = int(counts[combined_id]) - 1
			circuit.set_library_counts(counts)
			return false
	circuit_changed.emit(export_circuit_state())
	return true


func compile_circuit_plan() -> Dictionary:
	for raw_id in circuit.get_slots():
		var module_id := StringName(raw_id)
		var data := circuit.get_definition(module_id)
		if data != null and data.circuit_kind == CyberwareData.CircuitKind.STARTER and module_id != RELAY_STARTER:
			return circuit.compile_plan(module_id)
	return circuit.compile_plan()


func request_circuit_round() -> Dictionary:
	var result: Dictionary = circuit.request_round()
	if bool(result.get("ok", false)):
		circuit_changed.emit(export_circuit_state())
	return result


func import_circuit_state(state: Dictionary) -> bool:
	var imported: bool = circuit.import_state(state)
	if imported:
		_circuit_queues = (state.get("runtime", {}).get("queues", {}) as Dictionary).duplicate(true)
		_world_stop_floor = int(state.get("runtime", {}).get("world_floor", -1))
		_world_stop_uses = clampi(int(state.get("runtime", {}).get("world_uses", 0)), 0, 10)
		ensure_default_starter()
		circuit_changed.emit(export_circuit_state())
		circuit_queue_changed.emit(_circuit_queues.duplicate(true))
	return imported


func _circuit_definitions() -> Dictionary:
	var result: Dictionary = {}
	for module_id in ComponentRolls.cyberware_resource_paths():
		var path := ComponentRolls.cyberware_resource_path(module_id)
		if path.is_empty():
			continue
		var data := load(path) as CyberwareData
		if data != null:
			result[module_id] = data
	var starter := result.get(COMBAT_SYNAPSE_SENSOR) as CyberwareData
	if starter != null:
		for mask in range(1, 32):
			if EVENT_STARTER_IDS.has(mask):
				continue
			var combined := starter.duplicate(true) as CyberwareData
			combined.module_id = event_starter_id(mask)
			combined.display_name = "战斗突触感应器（复合）"
			var labels := PackedStringArray()
			for flag in EVENT_STARTER_LABELS:
				if mask & int(flag):
					labels.append(EVENT_STARTER_LABELS[flag])
			combined.description = "监听%s事件，回路结束后发动攻击。" % "、".join(labels)
			result[combined.module_id] = combined
	return result


static func event_starter_id(mask: int) -> StringName:
	return EVENT_STARTER_IDS.get(mask, StringName("combat_synapse_sensor_combo_%d" % mask))


static func event_starter_mask(module_id: StringName) -> int:
	for flag in EVENT_STARTER_IDS:
		if EVENT_STARTER_IDS[flag] == module_id:
			return flag
	var raw := String(module_id)
	if raw.begins_with("combat_synapse_sensor_combo_"):
		return clampi(raw.trim_prefix("combat_synapse_sensor_combo_").to_int(), 0, 31)
	return 0


func get_circuit_module_data(module_id: StringName) -> CyberwareData:
	return circuit.get_definition(module_id)


func submit_circuit_request(
	request_kind: StringName,
	direction: Vector2 = Vector2.RIGHT,
	tags: PackedStringArray = []
) -> bool:
	if not CIRCUIT_STARTERS.has(request_kind) or not _circuit_has_module(CIRCUIT_STARTERS[request_kind]):
		return false
	var plan: Dictionary = circuit.compile_plan(CIRCUIT_STARTERS[request_kind])
	var starter := circuit.get_definition(CIRCUIT_STARTERS[request_kind])
	if not bool(plan.get("ok", false)) or starter == null:
		return false
	var player := get_parent() as PlayerController
	var debt_limit := 100.0 if player != null and player.persona_combat.is_nuclear_frenzy_active() else 0.0
	if circuit.current_energy - starter.circuit_energy_cost * player.persona_combat.circuit_energy_multiplier() < -debt_limit - 0.0001:
		_notify_circuit_energy_shortage()
		return false
	_circuit_queues[request_kind] = {
		"kind": request_kind,
		"direction": direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT,
		"tags": tags.duplicate(),
		"starter_id": CIRCUIT_STARTERS[request_kind],
		"weapon": (get_parent() as PlayerController).weapons.get_current_weapon().duplicate(true) if (get_parent() as PlayerController).weapons.get_current_weapon() != null else null,
	}
	circuit_queue_changed.emit(_circuit_queues.duplicate(true))
	return true


func submit_event_starters(event_flag: int, direction: Vector2, tags: PackedStringArray = []) -> bool:
	return _submit_event_starters(event_flag, direction, tags, PackedStringArray(), 0)


func _submit_event_starters(event_flag: int, direction: Vector2, tags: PackedStringArray, path: PackedStringArray, round_token: int, weapon_override: WeaponComponentData = null) -> bool:
	var accepted := false
	var slots := circuit.get_slots()
	for index in slots.size():
		var module_id := StringName(slots[index])
		if event_starter_mask(module_id) & event_flag == 0:
			continue
		var label := String(EVENT_STARTER_LABELS[event_flag])
		if label in path:
			continue
		var seen_key := "%d:%d" % [round_token, index]
		if round_token > 0 and _event_seen.has(seen_key):
			continue
		var cooldown_key := StringName("event_%d" % index)
		var key := cooldown_key
		if event_flag == 1:
			_fire_event_serial += 1
			key = StringName("event_%d_fire_%d" % [index, _fire_event_serial])
		var player := get_parent() as PlayerController
		var can_queue_early := event_flag == 1 and (player.persona_combat.is_nuclear_frenzy_active() or player.persona_combat.can_queue_seamless() and has_active_round())
		if float(_circuit_cooldowns.get(cooldown_key, 0.0)) > 0.0 and not can_queue_early:
			continue
		var plan: Dictionary = circuit.compile_plan()
		var starter := circuit.get_definition(module_id)
		if not bool(plan.get("ok", false)) or starter == null:
			continue
		var debt_limit := 100.0 if player != null and player.persona_combat.is_nuclear_frenzy_active() else 0.0
		if circuit.current_energy - starter.circuit_energy_cost * player.persona_combat.circuit_energy_multiplier() < -debt_limit - 0.0001:
			_notify_circuit_energy_shortage()
			continue
		_circuit_queues[key] = {
			"kind": &"event", "starter_slot": index, "starter_id": module_id,
			"cooldown_key": cooldown_key,
			"gravity_room_id": CombatProjectile.room_for_actor(player).get_instance_id() if weapon_override != null and weapon_override.id == &"gravity_wave" else 0,
			"direction": direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT,
			"tags": tags.duplicate(),
			"weapon": weapon_override.duplicate(true) if weapon_override != null else (player.weapons.get_current_weapon().duplicate(true) if player != null else null),
			"path": path.duplicate(),
		}
		var queued_weapon := _circuit_queues[key]["weapon"] as WeaponComponentData
		if weapon_override == null and queued_weapon != null and queued_weapon.id == &"gravity_wave":
			queued_weapon.charge_seconds = player.weapons.last_manual_charge_seconds
			_circuit_queues[key]["gravity_room_id"] = CombatProjectile.room_for_actor(player).get_instance_id()
		(_circuit_queues[key]["path"] as PackedStringArray).append(label)
		if round_token > 0:
			_event_seen[seen_key] = true
			if _event_seen.size() > 256:
				_event_seen.erase(_event_seen.keys()[0])
		accepted = true
		if event_flag == 1:
			break
	if accepted:
		circuit_queue_changed.emit(_circuit_queues.duplicate(true))
	return accepted


func submit_weapon_fire(direction: Vector2, weapon: WeaponComponentData, automatic: bool = false) -> bool:
	if weapon == null:
		return false
	if automatic:
		for queued in _circuit_queues.values():
			if "开火" in PackedStringArray((queued as Dictionary).get("tags", [])):
				return false
	var accepted := _submit_event_starters(1, direction, PackedStringArray(["开火"]), PackedStringArray(), 0, weapon)
	if accepted and automatic:
		for key in _circuit_queues:
			var queued: Dictionary = _circuit_queues[key]
			if "开火" in PackedStringArray(queued.get("tags", [])):
				queued["automatic"] = true
				_circuit_queues[key] = queued
	return accepted


func cancel_automatic_fire_requests() -> void:
	var changed := false
	for key in _circuit_queues.keys():
		if bool((_circuit_queues[key] as Dictionary).get("automatic", false)):
			_circuit_queues.erase(key)
			changed = true
	if changed:
		circuit_queue_changed.emit(_circuit_queues.duplicate(true))


func has_event_starter(event_flag: int) -> bool:
	for module_id in circuit.get_slots():
		if event_starter_mask(StringName(module_id)) & event_flag != 0:
			return true
	return false


func has_active_round() -> bool:
	return not _active_circuit_round.is_empty()


func get_active_round_token() -> int:
	return int(_active_circuit_round.get("round_token", 0))


func flush_active_round_after_guard(target: Node2D) -> void:
	if _active_circuit_round.is_empty():
		return
	var request: Dictionary = _active_circuit_round.get("request", {})
	if is_instance_valid(target):
		request["direction"] = (get_parent() as PlayerController).global_position.direction_to(target.global_position)
		_active_circuit_round["request"] = request
	_active_circuit_round["guard_release"] = true
	for _index in 128:
		if _active_circuit_round.is_empty():
			break
		var plan: Dictionary = _active_circuit_round.get("plan", {})
		if int(_active_circuit_round.get("step_index", 0)) >= (plan.get("steps", []) as Array).size():
			break
		_execute_next_circuit_step()
	_circuit_step_remaining = 0.0


func on_weapon_attack_performed(direction: Vector2) -> void:
	if _circuit_weapon_call_active:
		return
	# Player input submits the fire event before any attack is performed.


func get_circuit_runtime_state() -> Dictionary:
	return {
		"queues": _circuit_queues.duplicate(true),
		"active": _active_circuit_round.duplicate(true),
		"weapon_payload": _pending_weapon_payload.duplicate(),
		"round_modifiers": _circuit_modifiers.duplicate(),
		"abort_slot": _circuit_abort_slot if _circuit_abort_remaining > 0.0 else -1,
		"step_remaining": _circuit_step_remaining,
		"cyber_guard_count": _cyber_guard_windows.size(),
	}


func get_cyber_guard_windows() -> Array[Dictionary]:
	return _cyber_guard_windows.duplicate(true)


func try_cyberware_guard(packet: DamagePacket) -> DamageResult:
	if packet == null or not packet.blockable or packet.is_area_damage:
		return null
	var player := get_parent() as PlayerController
	if player == null:
		return null
	var selected_window: Dictionary = {}
	var toward_source := packet.source_position - player.global_position
	if toward_source.is_zero_approx() and not packet.travel_direction.is_zero_approx():
		toward_source = -packet.travel_direction
	if toward_source.is_zero_approx():
		return null
	for window in _cyber_guard_windows:
		if float(window.get("remaining", 0.0)) <= 0.0:
			continue
		var guard_direction := Vector2(window.get("direction", Vector2.RIGHT)).normalized()
		if not bool(window.get("omnidirectional", false)) and guard_direction.dot(toward_source.normalized()) < cos(deg_to_rad(60.0)):
			continue
		if selected_window.is_empty() or (
			float(window.get("perfect_remaining", 0.0)) > 0.0
			and float(selected_window.get("perfect_remaining", 0.0)) <= 0.0
		):
			selected_window = window
	if selected_window.is_empty():
		return null
	var result := DamageResult.new()
	result.packet = packet
	result.target = player
	result.blocked = true
	if float(selected_window.get("perfect_remaining", 0.0)) > 0.0:
		result.perfect = true
		if not packet.status_tags.has("cyber_guard"):
			packet.status_tags.append(&"cyber_guard")
		if packet.is_projectile and packet.reflectable:
			result.outcome = DamageResult.Outcome.REFLECTED
			result.reflected = true
			var reflected := packet.duplicate_packet()
			reflected.source = player
			reflected.source_faction = CombatFaction.Id.PLAYER
			reflected.travel_direction = -packet.travel_direction
			reflected.reflected = true
			result.packet = reflected
		else:
			result.outcome = DamageResult.Outcome.PERFECT_BLOCKED
	else:
		result.outcome = DamageResult.Outcome.BLOCKED
	return result


func _tick_circuit_runtime(delta: float) -> void:
	for request_kind in _circuit_cooldowns:
		_circuit_cooldowns[request_kind] = maxf(float(_circuit_cooldowns[request_kind]) - delta, 0.0)
	_tick_cyber_guards(delta)
	if _circuit_has_module(RHYTHM_PULSER):
		_rhythm_remaining -= delta
		if _rhythm_remaining <= 0.0:
			submit_circuit_request(&"timed", _player_aim_direction(), PackedStringArray(["定时"]))
			_rhythm_remaining += CIRCUIT_STARTER_INTERVALS[&"timed"]
	else:
		_rhythm_remaining = CIRCUIT_STARTER_INTERVALS[&"timed"]
	if not _active_circuit_round.is_empty():
		_circuit_step_remaining -= delta
		while not _active_circuit_round.is_empty() and _circuit_step_remaining <= 0.0:
			_execute_next_circuit_step()
	if _active_circuit_round.is_empty():
		_start_next_circuit_request()
	var direct_plan: Dictionary = circuit.take_started_plan()
	if not direct_plan.is_empty() and _active_circuit_round.is_empty():
		_begin_circuit_round(direct_plan, {"kind": &"direct", "direction": _player_aim_direction(), "tags": PackedStringArray()})


func _start_next_circuit_request() -> void:
	var priority: Array[StringName] = [&"active"]
	for index in circuit.get_slots().size():
		priority.append(StringName("event_%d" % index))
	for queued_key in _circuit_queues:
		if String(queued_key).contains("_fire_"):
			priority.append(queued_key)
	priority.append_array([&"event", &"timed"])
	for request_kind in priority:
		if not _circuit_queues.has(request_kind):
			continue
		var queued: Dictionary = _circuit_queues[request_kind]
		var ignore_cooldown := (get_parent() as PlayerController).persona_combat.is_nuclear_frenzy_active() and "开火" in PackedStringArray(queued.get("tags", []))
		var cooldown_key := StringName(queued.get("cooldown_key", request_kind))
		if float(_circuit_cooldowns.get(cooldown_key, 0.0)) > 0.0 and not ignore_cooldown:
			continue
		var request: Dictionary = _circuit_queues[request_kind]
		var player := get_parent() as PlayerController
		if int(request.get("gravity_room_id", 0)) > 0 and int(request.get("gravity_room_id", 0)) != CombatProjectile.room_for_actor(player).get_instance_id():
			_circuit_queues.erase(request_kind)
			circuit_queue_changed.emit(_circuit_queues.duplicate(true))
			continue
		if bool(request.get("automatic", false)) and player.weapons.get_cooldown_remaining() > 0.0:
			continue
		var plan: Dictionary = circuit.compile_plan(StringName(request.get("starter_id", "")))
		if not bool(plan.get("ok", false)):
			_circuit_queues.erase(request_kind)
			circuit_queue_changed.emit(_circuit_queues.duplicate(true))
			return
		var starter := circuit.get_definition(StringName(request.get("starter_id", "")))
		var debt_limit := 100.0 if player != null and player.persona_combat.is_nuclear_frenzy_active() else 0.0
		var starter_cost := starter.circuit_energy_cost * player.persona_combat.circuit_energy_multiplier() if starter != null and player != null else 0.0
		if starter == null or not circuit.try_spend_energy(starter_cost, debt_limit):
			_notify_circuit_energy_shortage()
			if player != null and "开火" in PackedStringArray(request.get("tags", [])):
				player.weapons.set_cooldown_remaining(0.0)
			_circuit_queues.erase(request_kind)
			circuit_queue_changed.emit(_circuit_queues.duplicate(true))
			continue
		if not circuit.start_compiled_plan(plan):
			circuit.add_energy(starter_cost)
			if player != null and "开火" in PackedStringArray(request.get("tags", [])):
				player.weapons.set_cooldown_remaining(0.0)
			_circuit_queues.erase(request_kind)
			circuit_queue_changed.emit(_circuit_queues.duplicate(true))
			continue
		var started_plan: Dictionary = circuit.take_started_plan()
		if bool(request.get("automatic", false)) and player.weapons.get_current_weapon() != null:
			var weapon := player.weapons.get_current_weapon()
			player.weapons.set_cooldown_remaining(0.0 if player.persona_combat.is_nuclear_frenzy_active() else weapon.cooldown / maxf(player.weapons.attack_speed_multiplier + player.weapons.persona_attack_speed_bonus + player.weapons.equipment_attack_speed_bonus, 0.01))
		_circuit_queues.erase(request_kind)
		_circuit_cooldowns[cooldown_key] = (0.25 if int(request.get("gravity_room_id", 0)) > 0 else 0.375) if String(request_kind).begins_with("event") else CIRCUIT_STARTER_INTERVALS[request_kind]
		circuit_queue_changed.emit(_circuit_queues.duplicate(true))
		_begin_circuit_round(started_plan, request)
		return


func _begin_circuit_round(plan: Dictionary, request: Dictionary) -> void:
	var persona := (get_parent() as PlayerController).persona_combat
	var talent_effects := persona.take_circuit_talent_effects()
	_circuit_round_serial += 1
	_circuit_abort_slot = -1
	_circuit_abort_remaining = 0.0
	_active_circuit_round = {
		"plan": plan.duplicate(true),
		"request": request.duplicate(true),
		"step_index": 0,
		"optical_duration": 0.0,
		"round_token": _circuit_round_serial,
		"replay_index": -1,
		"frenzy_debt": (get_parent() as PlayerController).persona_combat.is_nuclear_frenzy_active(),
		"energy_multiplier": persona.circuit_energy_multiplier(),
		"talent_damage_bonus": int(talent_effects.get("damage_bonus", 0)),
		"dual_channel": bool(talent_effects.get("dual_channel", false)),
		"copy_first": bool(talent_effects.get("copy_first", false)),
		"world_stop_total": 0.0,
		"guard_release": persona.can_attack_during_guard() and (get_parent() as PlayerController).guard.state != GuardComponent.State.IDLE,
	}
	_circuit_modifiers = {&"homing": 0, &"explosion": 0, &"arc": 0, &"echo": 0}
	_circuit_step_interval = maxf(CIRCUIT_STEP_SECONDS * float(talent_effects.get("speed", 1.0)), CIRCUIT_MIN_STEP_SECONDS)
	_circuit_calamity_layers = 0
	_initialize_signal_attacks(request, bool(talent_effects.get("dual_channel", false)), bool(talent_effects.get("copy_first", false)))
	_circuit_step_remaining = 0.0
	circuit_round_ready.emit(plan)
	circuit_changed.emit(export_circuit_state())


func _execute_next_circuit_step() -> void:
	if _active_circuit_round.is_empty():
		return
	var plan: Dictionary = _active_circuit_round.get("plan", {})
	var steps: Array = plan.get("steps", [])
	var step_index := int(_active_circuit_round.get("step_index", 0))
	if step_index >= steps.size():
		_finish_circuit_round()
		return
	var step: Dictionary = steps[step_index]
	var request: Dictionary = _active_circuit_round.get("request", {})
	var replay_index := int(step.get("replay_index", -1))
	if replay_index != int(_active_circuit_round.get("replay_index", -1)):
		_emit_round_attack()
		_circuit_modifiers = {&"homing": 0, &"explosion": 0, &"arc": 0, &"echo": 0}
		_initialize_signal_attacks(request, bool(_active_circuit_round.get("dual_channel", false)), bool(_active_circuit_round.get("copy_first", false)))
		_circuit_calamity_layers = 0
		_active_circuit_round["replay_index"] = replay_index
		_circuit_round_serial += 1
		_active_circuit_round["round_token"] = _circuit_round_serial
	var is_paid_starter := StringName(step.get("module_id", "")) == StringName(request.get("starter_id", "")) and not bool(_active_circuit_round.get("starter_step_seen", false)) and not bool(step.get("replay", false))
	var step_data := circuit.get_definition(StringName(step.get("module_id", "")))
	var is_starter_step := step_data != null and step_data.circuit_kind == CyberwareData.CircuitKind.STARTER and StringName(step.get("module_id", "")) != RELAY_STARTER
	if is_paid_starter:
		_active_circuit_round["starter_step_seen"] = true
	var cost := float(step.get("energy_cost", 0.0))
	cost *= float(_active_circuit_round.get("energy_multiplier", 1.0))
	if bool(_active_circuit_round.get("remaining_energy_discount", false)):
		cost *= 0.5
	var pending_effect := StringName(step.get("effect_id", step.get("module_id", "")))
	var no_effect := (pending_effect == BALLISTIC_SPLICER and not _signal_can_splice()) or (pending_effect == WORLD and not _world_stop_available())
	if no_effect:
		cost = 0.0
	if not is_starter_step and not is_paid_starter and not bool(step.get("replay", false)) and not circuit.try_spend_energy(cost, 100.0 if bool(_active_circuit_round.get("frenzy_debt", false)) else 0.0):
		_circuit_abort_slot = int(step.get("slot", -1))
		_circuit_abort_remaining = 0.8
		_notify_circuit_energy_shortage(true)
		_jump_to_round_settlement(step_index)
		return
	var module_id := StringName(step.get("module_id", ""))
	var effect_id := StringName(step.get("effect_id", module_id))
	var scale := float(step.get("scale", 1.0))
	_circuit_current_scale = scale
	circuit_step_started.emit(int(step.get("slot", step_index)), module_id, effect_id)
	module_triggered.emit(module_id)
	match effect_id:
		ACTIVE_NEURAL_SWITCH, COMBAT_SYNAPSE_SENSOR, RHYTHM_PULSER:
			pass
		RELAY_STARTER:
			_append_base_signal_attacks(request)
		SMART_FIRE:
			_circuit_modifiers[&"homing"] = int(_circuit_modifiers[&"homing"]) + 1
			_add_signal_modifier(&"homing")
		EXPLOSIVE_MAGAZINE:
			_circuit_modifiers[&"explosion"] = int(_circuit_modifiers[&"explosion"]) + 1
			_add_signal_modifier(&"explosion")
		TACTICAL_COPROCESSOR:
			_duplicate_signal_attacks()
		FISSION_CORE:
			_fission_signal_attacks()
		BALLISTIC_SPLICER:
			if not no_effect:
				_splice_signal_attacks()
		PENETRATION_BOOSTER:
			for attack in _signal_attacks:
				attack["pierce"] = -1 if int(attack.get("pierce", 0)) < 0 else maxi(int(attack.get("pierce", 0)), 1)
				attack["penetration_boost"] = true
		WORLD:
			if not no_effect:
				_start_world_stop()
		KILL_HEAT_SINK:
			_execute_circuit_heat_sink(scale)
		GUARD_COPROCESSOR:
			_activate_cyber_guard()
		OPTICAL_INTRUDER:
			_execute_circuit_optical(scale)
		HEAT_THRESHOLD_PULSER:
			_execute_circuit_heat_pulse(scale)
		MICRO_ROTOR_REFLEX_BUNDLE:
			_circuit_step_interval = maxf(_circuit_step_interval * 0.25, CIRCUIT_MIN_STEP_SECONDS)
		MOMENTUM_RECOVERY_TENDON:
			circuit.add_energy(40.0)
			_jump_to_round_settlement(step_index + 1)
			return
		AXON_RECYCLER:
			_active_circuit_round["remaining_energy_discount"] = true
		BALLISTIC_TAKEOVER_PROTOCOL:
			_execute_circuit_takeover(scale)
		ARC_BALLISTIC_CORTEX:
			_circuit_modifiers[&"arc"] = int(_circuit_modifiers.get(&"arc", 0)) + 1
			_add_signal_modifier(&"arc")
		OMNIDIRECTIONAL_REFLECTION_MATRIX:
			_activate_cyber_guard(true)
		TRAJECTORY_ECHO_PROCESSOR:
			_circuit_modifiers[&"echo"] = int(_circuit_modifiers.get(&"echo", 0)) + 1
			_add_signal_modifier(&"echo")
		CALAMITY_FLAME:
			_circuit_calamity_layers += 1
			_apply_calamity_signal()
	_active_circuit_round["step_index"] = step_index + 1
	_circuit_step_remaining += _circuit_step_interval


func _notify_circuit_energy_shortage(aborted: bool = false) -> void:
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_notice(&"circuit_energy_shortage", "能量不足 中止" if aborted else "能量不足", Color(0.95, 0.55, 0.28), CombatNotice.Priority.NORMAL, 0.15, 0.55)


func _jump_to_round_settlement(from_index: int) -> void:
	var plan: Dictionary = _active_circuit_round.get("plan", {})
	var steps: Array = plan.get("steps", [])
	for index in range(from_index, steps.size()):
		if bool((steps[index] as Dictionary).get("replay", false)):
			_active_circuit_round["step_index"] = index
			_circuit_step_remaining = 0.0
			return
	_finish_circuit_round()


func _finish_circuit_round() -> void:
	if bool(_active_circuit_round.get("guard_release", false)) and (get_parent() as PlayerController).guard.state != GuardComponent.State.IDLE:
		_circuit_step_remaining = 0.01
		return
	_emit_round_attack()
	var request: Dictionary = _active_circuit_round.get("request", {})
	var request_kind := StringName(request.get("kind", "direct"))
	_active_circuit_round.clear()
	_circuit_modifiers = {&"homing": 0, &"explosion": 0, &"arc": 0, &"echo": 0}
	_circuit_calamity_layers = 0
	_circuit_step_remaining = 0.0
	circuit_round_finished.emit(request_kind)
	circuit_changed.emit(export_circuit_state())


func _emit_round_attack() -> void:
	if _active_circuit_round.is_empty():
		return
	var groups: Dictionary = {}
	for attack in _signal_attacks:
		var group_key := int(attack.get("group_key", 0))
		if not groups.has(group_key):
			_circuit_copy_serial += 1
			groups[group_key] = 1000000 + _circuit_copy_serial
		_circuit_payload_group_override = int(groups[group_key])
		_call_circuit_weapon(attack)
	_circuit_payload_group_override = 0
	var request: Dictionary = _active_circuit_round.get("request", {})
	var path := PackedStringArray(request.get("path", []))
	(get_parent() as PlayerController).persona_combat.on_circuit_attack_emitted("过载嘶鸣" in path)


func _call_circuit_weapon(attack: Dictionary) -> void:
	var player := get_parent() as PlayerController
	if player == null:
		return
	var request: Dictionary = _active_circuit_round.get("request", {})
	var weapon := request.get("weapon", player.weapons.get_current_weapon()) as WeaponComponentData
	if weapon == null:
		weapon = player.weapons.get_current_weapon()
	var base_direction := Vector2(request.get("direction", player.aim_direction))
	if weapon != null and weapon.attack_kind in [WeaponComponentData.AttackKind.PROJECTILE, WeaponComponentData.AttackKind.SPREAD]:
		base_direction = player.get_live_projectile_aim_direction()
	var direction := base_direction.rotated(float(attack.get("angle_offset", 0.0)))
	_circuit_modifiers = (attack.get("modifiers", {}) as Dictionary).duplicate()
	_circuit_calamity_layers = int(attack.get("calamity_layers", 0))
	_circuit_current_pierce = int(attack.get("pierce", 0))
	_circuit_current_penetration_boost = bool(attack.get("penetration_boost", false))
	_circuit_current_visual_scale = float(attack.get("visual_scale", 1.0))
	var extra_scale := float(attack.get("damage_scale", 1.0))
	var prefer_other := bool(attack.get("prefer_other", false))
	if int(_circuit_modifiers.get(&"homing", 0)) > 0:
		var target := _acquire_target(player.global_position, direction, 180.0)
		if target != null:
			direction = player.global_position.direction_to(target.global_position)
	if prefer_other:
		var primary := _acquire_target(player.global_position, direction, 180.0)
		var secondary := _acquire_secondary_target(player.global_position, primary)
		if secondary != null:
			direction = player.global_position.direction_to(secondary.global_position)
	_circuit_weapon_call_active = true
	var tags := PackedStringArray(["circuit_round:%d" % int(_active_circuit_round.get("round_token", 0))])
	_circuit_copy_serial += 1
	tags.append("circuit_copy:%d" % _circuit_copy_serial)
	var talent_damage := int(_active_circuit_round.get("talent_damage_bonus", 0))
	if talent_damage > 0:
		tags.append("talent_direct_bonus:%d" % talent_damage)
	if bool(attack.get("calamity_swing", false)):
		if int(_circuit_modifiers.get(&"explosion", 0)) > 0 or int(_circuit_modifiers.get(&"arc", 0)) > 0 or int(_circuit_modifiers.get(&"echo", 0)) > 0:
			_nonprojectile_payloads[_circuit_copy_serial] = _circuit_modifiers.duplicate()
		_swing_calamity(direction, _circuit_current_scale * extra_scale, tags, weapon)
		_circuit_weapon_call_active = false
		return
	if weapon != null and weapon.attack_kind in [WeaponComponentData.AttackKind.BEAM, WeaponComponentData.AttackKind.MELEE] and _circuit_calamity_layers == 0:
		_nonprojectile_payloads[_circuit_copy_serial] = _circuit_modifiers.duplicate()
		if _nonprojectile_payloads.size() > 128:
			_nonprojectile_payloads.erase(_nonprojectile_payloads.keys()[0])
	var path := PackedStringArray(request.get("path", []))
	for event_label in path:
		tags.append("event_path:%s" % event_label)
	var origin := player.visuals.get_weapon_mount_global_position()
	if String(attack.get("kind", "projectile")) in ["projectile", "beam"]:
		origin += direction.orthogonal() * float(attack.get("origin_offset", 0.0))
	if weapon != null and weapon.attack_kind == WeaponComponentData.AttackKind.SPREAD:
		weapon = weapon.duplicate(true) as WeaponComponentData
		weapon.attack_kind = WeaponComponentData.AttackKind.PROJECTILE
		weapon.projectile_count = 1
		weapon.spread_degrees = 0.0
	if weapon != null and weapon.attack_kind in [WeaponComponentData.AttackKind.PROJECTILE, WeaponComponentData.AttackKind.SPREAD]:
		var muzzle_distance := origin.distance_to(player.visuals.get_weapon_muzzle_global_position())
		origin = player.weapons.clamp_projectile_origin(origin, origin + direction * muzzle_distance)
	player.weapons.perform_circuit_attack(weapon, origin, direction, player, _circuit_current_scale * extra_scale, tags)
	_circuit_weapon_call_active = false


func get_circuit_calamity_layers() -> int:
	return _circuit_calamity_layers if _circuit_weapon_call_active else 0


func get_circuit_pierce_remaining() -> int:
	return _circuit_current_pierce if _circuit_weapon_call_active else 0


func get_circuit_penetration_boost() -> bool:
	return _circuit_current_penetration_boost if _circuit_weapon_call_active else false


func get_circuit_visual_scale() -> float:
	return _circuit_current_visual_scale if _circuit_weapon_call_active else 1.0


func _execute_circuit_heat_sink(scale: float = 1.0) -> void:
	var request: Dictionary = _active_circuit_round.get("request", {})
	var tags := PackedStringArray(request.get("tags", []))
	var has_kill := "击杀" in tags
	circuit.add_energy((30.0 if has_kill else 20.0) * scale)


func _activate_cyber_guard(omnidirectional: bool = false) -> void:
	var request: Dictionary = _active_circuit_round.get("request", {})
	var direction := Vector2(request.get("direction", _player_aim_direction()))
	_cyber_guard_windows.append({
		"direction": direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT,
		"perfect_remaining": 0.16 if omnidirectional else CIRCUIT_GUARD_PERFECT_SECONDS,
		"remaining": 0.16 if omnidirectional else CIRCUIT_GUARD_TOTAL_SECONDS,
		"omnidirectional": omnidirectional,
	})


func _tick_cyber_guards(delta: float) -> void:
	for index in range(_cyber_guard_windows.size() - 1, -1, -1):
		var window: Dictionary = _cyber_guard_windows[index]
		window["perfect_remaining"] = maxf(float(window.get("perfect_remaining", 0.0)) - delta, 0.0)
		window["remaining"] = maxf(float(window.get("remaining", 0.0)) - delta, 0.0)
		if float(window["remaining"]) <= 0.0:
			_cyber_guard_windows.remove_at(index)
		else:
			_cyber_guard_windows[index] = window


func _apply_circuit_modifiers_to_projectile(projectile: CombatProjectile, direction: Vector2, payload: Dictionary) -> void:
	var homing_count := int(payload.get(&"homing", 0))
	if homing_count > 0:
		var target := _acquire_target(projectile.global_position, direction, 180.0)
		if target != null:
			projectile.configure_homing(target, 360.0 * homing_count)
	var explosion_count := int(payload.get(&"explosion", 0))
	if explosion_count > 0:
		projectile.configure_explosion(48.0, explosion_count)
	projectile.circuit_arc_chains = int(payload.get(&"arc", 0)) * 2
	projectile.circuit_echo_layers = int(payload.get(&"echo", 0))


func _count_circuit_module(module_id: StringName) -> int:
	var count := 0
	for raw_id in circuit.get_slots():
		if StringName(raw_id) == module_id:
			count += 1
	return count


func _current_attack_trajectory_count() -> int:
	var total := 0
	for attack in _signal_attacks:
		total += maxi(int(attack.get("calamity_layers", 0)), 1)
	return total


func _initialize_signal_attacks(request: Dictionary, dual_channel: bool, copy_first: bool) -> void:
	_signal_attacks.clear()
	var weapon := request.get("weapon") as WeaponComponentData
	var count := 1
	if weapon != null and weapon.attack_kind == WeaponComponentData.AttackKind.SPREAD:
		count = maxi(weapon.projectile_count, 1)
	_signal_group_serial += 1
	for index in count:
		var offset := 0.0
		if count > 1:
			offset = deg_to_rad(lerpf(-weapon.spread_degrees * 0.5, weapon.spread_degrees * 0.5, float(index) / float(count - 1)))
		_signal_attacks.append({
			"angle_offset": offset,
			"damage_scale": 1.0,
			"modifiers": {&"homing": 0, &"explosion": 0, &"arc": 0, &"echo": 0},
			"calamity_layers": 0,
			"calamity_swing": false,
			"group_key": _signal_group_serial,
			"prefer_other": false,
			"kind": "beam" if weapon != null and weapon.attack_kind == WeaponComponentData.AttackKind.BEAM else ("melee" if weapon != null and weapon.attack_kind == WeaponComponentData.AttackKind.MELEE else "projectile"),
			"pierce": 0,
			"penetration_boost": false,
			"visual_scale": 1.0,
		})
	if dual_channel or copy_first:
		_duplicate_signal_attacks()
		if dual_channel:
			for index in range(count, _signal_attacks.size()):
				_signal_attacks[index]["damage_scale"] = 0.5
				_signal_attacks[index]["prefer_other"] = true


func _add_signal_modifier(key: StringName) -> void:
	for index in _signal_attacks.size():
		var attack: Dictionary = _signal_attacks[index]
		var modifiers: Dictionary = attack.get("modifiers", {})
		modifiers[key] = int(modifiers.get(key, 0)) + 1
		attack["modifiers"] = modifiers
		_signal_attacks[index] = attack


func _duplicate_signal_attacks() -> void:
	var original := _signal_attacks.duplicate(true)
	var cloned_groups: Dictionary = {}
	for raw_attack in original:
		var copy: Dictionary = raw_attack.duplicate(true)
		var old_group := int(copy.get("group_key", 0))
		if not cloned_groups.has(old_group):
			_signal_group_serial += 1
			cloned_groups[old_group] = _signal_group_serial
		copy["group_key"] = int(cloned_groups[old_group])
		_signal_attacks.append(copy)


func is_world_stopped() -> bool:
	return _world_stop_remaining > 0.0


func world_uses_remaining() -> int:
	var run := get_node_or_null("/root/RunManager") as RunManager
	var floor_index := run.floor_index if run != null else 0
	return 10 if floor_index != _world_stop_floor else 10 - _world_stop_uses


func _world_stop_available() -> bool:
	var run := get_node_or_null("/root/RunManager") as RunManager
	var floor_index := run.floor_index if run != null else 0
	if _world_stop_floor != floor_index:
		_world_stop_floor = floor_index
		_world_stop_uses = 0
	return _world_stop_uses < 10 and float(_active_circuit_round.get("world_stop_total", 0.0)) < 3.0 and not get_tree().paused


func _start_world_stop() -> void:
	var player := get_parent() as PlayerController
	if player == null:
		return
	_world_stop_uses += 1
	_active_circuit_round["world_stop_total"] = float(_active_circuit_round.get("world_stop_total", 0.0)) + 1.5
	_world_stop_remaining = 1.5
	_world_previous_player_mode = player.process_mode
	_world_child_modes.clear()
	for child in player.get_children():
		if child == self:
			continue
		_world_child_modes[child] = child.process_mode
		child.process_mode = Node.PROCESS_MODE_ALWAYS if child == player.weapons else Node.PROCESS_MODE_DISABLED
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true


func _end_world_stop() -> void:
	if _world_stop_remaining <= 0.0 and _world_child_modes.is_empty():
		return
	_world_stop_remaining = 0.0
	var player := get_parent() as PlayerController
	if player != null:
		player.process_mode = _world_previous_player_mode
	for child in _world_child_modes:
		if is_instance_valid(child):
			child.process_mode = _world_child_modes[child]
	_world_child_modes.clear()
	get_tree().paused = false


func _append_base_signal_attacks(request: Dictionary) -> void:
	var previous := _signal_attacks.duplicate(true)
	_initialize_signal_attacks(request, false, false)
	var added := _signal_attacks.duplicate(true)
	for attack in added:
		attack["origin_offset"] = 7.0
	_signal_attacks = previous
	_signal_attacks.append_array(added)


func _fission_signal_attacks() -> void:
	var original := _signal_attacks.duplicate(true)
	_signal_attacks.clear()
	for raw_attack in original:
		for angle in [-20.0, 0.0, 20.0]:
			var copy: Dictionary = raw_attack.duplicate(true)
			copy["angle_offset"] = float(copy.get("angle_offset", 0.0)) + deg_to_rad(angle)
			copy["damage_scale"] = float(copy.get("damage_scale", 1.0)) * 0.5
			_signal_group_serial += 1
			copy["group_key"] = _signal_group_serial
			_signal_attacks.append(copy)


func _signal_can_splice() -> bool:
	var kinds: Dictionary = {}
	for attack in _signal_attacks:
		var kind := String(attack.get("kind", "projectile"))
		kinds[kind] = int(kinds.get(kind, 0)) + maxi(int(attack.get("calamity_layers", 0)), 1)
	for count in kinds.values():
		if int(count) > 1:
			return true
	return false


func _splice_signal_attacks() -> void:
	var by_kind: Dictionary = {}
	var ordered: Array[Dictionary] = []
	for attack in _signal_attacks:
		var kind := String(attack.get("kind", "projectile"))
		var count := maxi(int(attack.get("calamity_layers", 0)), 1)
		if not by_kind.has(kind):
			var merged: Dictionary = attack.duplicate(true)
			merged["damage_scale"] = 0.0
			merged["splice_count"] = 0
			merged["angle_offset"] = 0.0
			merged["calamity_layers"] = 1 if kind == "blade" else 0
			by_kind[kind] = merged
			ordered.append(merged)
		var merged: Dictionary = by_kind[kind]
		merged["damage_scale"] = float(merged.damage_scale) + float(attack.get("damage_scale", 1.0)) * count
		merged["angle_offset"] = float(merged.angle_offset) + float(attack.get("angle_offset", 0.0)) * count
		merged["splice_count"] = int(merged.splice_count) + count
		var modifiers: Dictionary = merged.get("modifiers", {})
		for key in (attack.get("modifiers", {}) as Dictionary):
			modifiers[key] = maxi(int(modifiers.get(key, 0)), int((attack.modifiers as Dictionary)[key]))
		merged["modifiers"] = modifiers
	for merged in ordered:
		var count := int(merged.splice_count)
		merged["angle_offset"] = float(merged.angle_offset) / count
		if count > 1:
			merged["pierce"] = -1
			merged["visual_scale"] = minf(3.0, float(count))
			_signal_group_serial += 1
			merged["group_key"] = _signal_group_serial
		merged.erase("splice_count")
	_signal_attacks = ordered


func _apply_calamity_signal() -> void:
	for index in _signal_attacks.size():
		var attack: Dictionary = _signal_attacks[index]
		if not bool(attack.get("calamity_swing", false)):
			attack["calamity_layers"] = int(attack.get("calamity_layers", 0)) + 1
			attack["kind"] = "blade"
			_signal_attacks[index] = attack
	_signal_group_serial += 1
	_signal_attacks.append({
		"angle_offset": 0.0,
		"damage_scale": 1.0,
		"modifiers": {&"homing": 0, &"explosion": 0, &"arc": 0, &"echo": 0},
		"calamity_layers": 0,
		"calamity_swing": true,
		"group_key": _signal_group_serial,
		"prefer_other": false,
		"kind": "melee",
		"pierce": 0,
		"penetration_boost": false,
		"visual_scale": 1.0,
	})


func _execute_circuit_optical(scale: float) -> void:
	var player := get_parent() as PlayerController
	if player == null:
		return
	var count_bonus := 0.2 * floorf(log(float(maxi(_current_attack_trajectory_count(), 1))) / log(2.0))
	var duration := float(_active_circuit_round.get("optical_duration", 0.0)) + minf(0.6 + count_bonus, 1.6) * scale
	_active_circuit_round["optical_duration"] = duration
	for target in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("bosses"):
		if is_instance_valid(target) and target.has_method("apply_optical_disruption") and CombatProjectile.room_for_actor(target) == CombatProjectile.room_for_actor(player):
			target.apply_optical_disruption(player.global_position, duration)


func _execute_circuit_heat_pulse(scale: float) -> void:
	var player := get_parent() as PlayerController
	if player == null:
		return
	var copies := maxi(_count_circuit_module(HEAT_THRESHOLD_PULSER), 1)
	var count_bonus := 16.0 * floorf(log(float(maxi(_current_attack_trajectory_count(), 1))) / log(2.0))
	var radius := (minf(64.0 + count_bonus, 144.0) + 32.0 * float(copies - 1)) * scale
	for target in get_tree().get_nodes_in_group("enemies"):
		if target is EnemyController and is_instance_valid(target) and CombatProjectile.room_for_actor(target) == CombatProjectile.room_for_actor(player) and player.global_position.distance_to(target.global_position) <= radius:
			target.apply_stagger((0.35 + 0.18 * float(copies - 1)) * scale)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.request_effect(player.global_position, Color(1.0, 0.46, 0.12), radius, 0.25)


func _execute_circuit_takeover(scale: float) -> void:
	var player := get_parent() as PlayerController
	if player == null:
		return
	var selected: CombatProjectile
	var search_radius := 96.0 + 24.0 * float(_current_attack_trajectory_count() - 1)
	var nearest := search_radius * search_radius
	for candidate in get_tree().get_nodes_in_group("combat_projectiles"):
		var shot := candidate as CombatProjectile
		if shot == null or not shot.can_be_taken_over() or CombatProjectile.room_for_actor(shot) != CombatProjectile.room_for_actor(player):
			continue
		var distance := player.global_position.distance_squared_to(shot.global_position)
		if distance < nearest:
			nearest = distance
			selected = shot
	var target := _nearest_takeover_target(player.global_position, 512.0, CombatProjectile.room_for_actor(player))
	if selected != null and target != null and selected.take_over(player, target, 720.0):
		selected.damage = maxi(roundi(float(selected.damage) * scale), 1)


func _swing_calamity(direction: Vector2, damage_scale: float, attack_tags: PackedStringArray, locked_weapon: WeaponComponentData = null) -> void:
	var player := get_parent() as PlayerController
	if player == null or player.weapons == null:
		return
	var weapon := locked_weapon if locked_weapon != null else player.weapons.get_current_weapon()
	if weapon == null:
		return
	var room := CombatProjectile.room_for_actor(player)
	var targets := get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("bosses")
	targets.sort_custom(func(a: Node, b: Node) -> bool:
		return (a as Node2D).global_position.distance_squared_to(player.global_position) < (b as Node2D).global_position.distance_squared_to(player.global_position)
	)
	var penetrated_targets := 0
	for target in targets:
		if not target is Node2D or not is_instance_valid(target) or CombatProjectile.room_for_actor(target) != room:
			continue
		var offset: Vector2 = target.global_position - player.global_position
		if offset.length() > 42.0 or absf(direction.angle_to(offset)) > deg_to_rad(75.0):
			continue
		var hurt := target.get_node_or_null("HurtBox") as HurtBox2DComponent
		if hurt == null:
			continue
		var packet := DamagePacket.new()
		packet.base_damage = maxi(roundi(float(weapon.damage) * damage_scale), 1)
		if _circuit_current_penetration_boost:
			packet.base_damage *= 1 + penetrated_targets
		penetrated_targets += 1
		packet.damage_type = weapon.damage_type
		packet.source = player
		packet.source_faction = CombatFaction.Id.PLAYER
		packet.weapon_id = weapon.id
		packet.source_position = player.global_position
		packet.travel_direction = direction
		packet.status_tags = PackedStringArray(["cyberware_chain", "calamity_swing"])
		packet.status_tags.append_array(attack_tags)
		packet.is_melee = true
		hurt.receive_hit(packet)


func on_circuit_projectile_hit(projectile: CombatProjectile, result: DamageResult) -> void:
	if result == null or result.final_damage <= 0 or not result.target is Node2D:
		return
	var origin := result.target as Node2D
	var player := get_parent() as PlayerController
	if player == null:
		return
	var room := CombatProjectile.room_for_actor(player)
	var excluded := {origin.get_instance_id(): true}
	var chain_origin := origin
	for _index in projectile.circuit_arc_chains:
		var chained := _nearest_arc_target(chain_origin.global_position, 64.0, room, excluded)
		if chained == null:
			break
		excluded[chained.get_instance_id()] = true
		_apply_arc_paralysis(chained, 0.2)
		var hurt := chained.get_node_or_null("HurtBox") as HurtBox2DComponent
		if hurt != null:
			var packet := DamagePacket.new()
			packet.base_damage = maxi(ceili(float(result.final_damage) * 0.5), 1)
			packet.source = player
			packet.source_faction = CombatFaction.Id.PLAYER
			packet.weapon_id = projectile.weapon_id
			packet.damage_type = &"electric"
			packet.source_position = chain_origin.global_position
			packet.travel_direction = chain_origin.global_position.direction_to(chained.global_position)
			packet.status_tags = projectile.status_tags.duplicate()
			packet.status_tags.append("circuit_arc")
			packet.is_area_damage = true
			hurt.receive_hit(packet)
		var events := get_node_or_null("/root/CombatEvents")
		if events != null:
			events.electric_arc_requested.emit(chain_origin.global_position, chained.global_position, room)
		chain_origin = chained
	if projectile.circuit_echo_layers > 0:
		for index in projectile.circuit_echo_layers:
			_circuit_pending_echoes.append({
				"remaining": 0.18 * (index + 1),
				"target": origin,
				"position": projectile.global_position - projectile.direction * 24.0,
				"direction": projectile.direction,
				"damage": maxi(ceili(float(projectile.damage) * 0.75), 1),
				"speed": projectile.speed,
				"weapon_id": projectile.weapon_id,
				"damage_type": projectile.damage_type,
				"status_tags": projectile.status_tags.duplicate(),
				"explosion_radius": projectile.explosion_radius if projectile.has_area_behavior else 0.0,
				"explosion_damage": projectile.explosion_damage,
				"arc_chains": projectile.circuit_arc_chains,
				"homing_target": projectile.homing_target,
				"homing_turn": projectile.homing_turn_radians_per_second,
				"calamity_blade": projectile.calamity_blade,
				"calamity_range": projectile.calamity_max_distance,
			})


func _tick_circuit_echoes(delta: float) -> void:
	for index in range(_circuit_pending_echoes.size() - 1, -1, -1):
		var echo: Dictionary = _circuit_pending_echoes[index]
		echo["remaining"] = float(echo.remaining) - delta
		if float(echo.remaining) > 0.0:
			_circuit_pending_echoes[index] = echo
			continue
		_circuit_pending_echoes.remove_at(index)
		var player := get_parent() as PlayerController
		if player == null or not player.is_inside_tree():
			continue
		var shot := (load("res://scenes/combat/projectile.tscn") as PackedScene).instantiate() as CombatProjectile
		CombatProjectile.room_for_actor(player).add_child(shot)
		shot.global_position = Vector2(echo.position)
		var direction := Vector2(echo.direction)
		if is_instance_valid(echo.target):
			direction = shot.global_position.direction_to(echo.target.global_position)
		shot.setup(player, CombatFaction.Id.PLAYER, direction, int(echo.damage), float(echo.speed))
		shot.weapon_id = StringName(echo.weapon_id)
		shot.damage_type = StringName(echo.damage_type)
		shot.status_tags = PackedStringArray(echo.get("status_tags", PackedStringArray(["cyberware_chain"])))
		shot.status_tags.append("circuit_echo")
		if float(echo.get("explosion_radius", 0.0)) > 0.0:
			shot.configure_explosion(float(echo.explosion_radius), int(echo.get("explosion_damage", 0)))
		shot.circuit_arc_chains = int(echo.get("arc_chains", 0))
		if is_instance_valid(echo.get("homing_target", null)) and float(echo.get("homing_turn", 0.0)) > 0.0:
			shot.configure_homing(echo.homing_target, rad_to_deg(float(echo.homing_turn)))
		if bool(echo.get("calamity_blade", false)):
			shot.configure_calamity_blade(float(echo.get("calamity_range", 0.0)))
		shot.tint = Color(0.75, 0.36, 1.0)


func _plan_has_weapon_call(plan: Dictionary) -> bool:
	for raw_step in plan.get("steps", []):
		var step: Dictionary = raw_step
		if StringName(step.get("effect_id", "")) in [TACTICAL_COPROCESSOR, CALAMITY_FLAME]:
			return true
	return false


func _circuit_has_module(module_id: StringName) -> bool:
	return String(module_id) in circuit.get_slots()


func _player_aim_direction() -> Vector2:
	var player := get_parent() as PlayerController
	return player.aim_direction if player != null else Vector2.RIGHT


func get_momentum_charge_remaining() -> float:
	return 0.0


func get_module_readiness(module_id: StringName) -> float:
	if not has_module(module_id):
		return 1.0
	var data := _data(module_id)
	if data == null or data.trigger_cooldown <= 0.0:
		return 1.0
	var remaining := 0.0
	match module_id:
		TRAJECTORY_ECHO_PROCESSOR:
			remaining = _trajectory_echo_cooldown_remaining
		BALLISTIC_TAKEOVER_PROTOCOL:
			remaining = _ballistic_takeover_cooldown_remaining
		INERTIAL_INVERSION_VERTEBRA:
			remaining = _inertial_inversion_cooldown_remaining
		_:
			return 1.0
	return clampf(1.0 - remaining / data.trigger_cooldown, 0.0, 1.0)


func _try_ballistic_takeover() -> void:
	if not has_module(BALLISTIC_TAKEOVER_PROTOCOL) or _ballistic_takeover_cooldown_remaining > 0.0:
		return
	var data := _data(BALLISTIC_TAKEOVER_PROTOCOL)
	var player := get_parent() as PlayerController
	if data == null or player == null:
		return
	var player_room := CombatProjectile.room_for_actor(player)
	var best_projectile: CombatProjectile
	var best_target: Node2D
	var best_distance_squared := data.takeover_radius * data.takeover_radius
	for candidate in get_tree().get_nodes_in_group("combat_projectiles"):
		var projectile := candidate as CombatProjectile
		if (
			projectile == null
			or not is_instance_valid(projectile)
			or projectile.is_queued_for_deletion()
			or not projectile.can_be_taken_over()
			or CombatProjectile.room_for_actor(projectile) != player_room
		):
			continue
		var distance_squared := player.global_position.distance_squared_to(projectile.global_position)
		if distance_squared > best_distance_squared:
			continue
		var target := _nearest_takeover_target(projectile.global_position, data.takeover_target_radius, player_room)
		if target == null:
			continue
		best_distance_squared = distance_squared
		best_projectile = projectile
		best_target = target
	if best_projectile == null or not best_projectile.take_over(player, best_target, data.takeover_homing_turn_degrees_per_second):
		return
	if has_module(ARC_BALLISTIC_CORTEX):
		best_projectile.configure_electric_arc()
	_ballistic_takeover_cooldown_remaining = data.trigger_cooldown
	module_triggered.emit(BALLISTIC_TAKEOVER_PROTOCOL)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.request_glitch_scan(player.global_position, Color(0.35, 1.0, 0.4), data.takeover_radius, player_room)
		events.request_effect(best_projectile.global_position, Color(0.35, 1.0, 0.4), 10.0, 0.16)
		events.electric_arc_requested.emit(player.global_position, best_projectile.global_position, player_room)
		events.publish_notice(&"ballistic_takeover_protocol", "弹道接管", Color(0.35, 1.0, 0.4), CombatNotice.Priority.NORMAL, 0.2, 0.7)


func _nearest_takeover_target(origin: Vector2, radius: float, room: Node) -> Node2D:
	var best: Node2D
	var best_distance_squared := radius * radius
	var player := get_parent() as PlayerController
	var world := player.get_world_2d() if player != null else null
	if world == null:
		return null
	var seen := {}
	for candidate in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("bosses"):
		if not candidate is Node2D or not is_instance_valid(candidate):
			continue
		var target := candidate as Node2D
		var target_id := target.get_instance_id()
		var hurt := target.get_node_or_null("HurtBox") as HurtBox2DComponent
		var health := target.get_node_or_null("HealthComponent")
		if (
			seen.has(target_id)
			or target.is_queued_for_deletion()
			or hurt == null
			or not hurt.monitorable
			or (health != null and health.has_method("is_dead") and bool(health.call("is_dead")))
			or CombatProjectile.room_for_actor(target) != room
		):
			continue
		seen[target_id] = true
		var distance_squared := origin.distance_squared_to(target.global_position)
		if distance_squared > best_distance_squared:
			continue
		var sight := PhysicsRayQueryParameters2D.create(origin, target.global_position, 1)
		if not world.direct_space_state.intersect_ray(sight).is_empty():
			continue
		best_distance_squared = distance_squared
		best = target
	return best


func on_dash_started(last_observed_position: Vector2) -> void:
	_inertial_inversion_triggered_this_dash = false
	if not has_module(OPTICAL_INTRUDER):
		return
	var delay: float = _data(OPTICAL_INTRUDER).optical_reacquire_delay
	var player := get_parent() as PlayerController
	if player != null:
		delay += player.dash.config.dash_duration
	for target in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("bosses"):
		if is_instance_valid(target) and target.has_method("apply_optical_disruption"):
			target.apply_optical_disruption(last_observed_position, delay)
	module_triggered.emit(OPTICAL_INTRUDER)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_notice(&"optical_intruder", "光学入侵：敌方索敌中断", Color(0.35, 0.95, 1.0), CombatNotice.Priority.NORMAL, 0.25, 0.9)


func _on_damage_resolved(result: DamageResult) -> void:
	_resolve_nonprojectile_modifiers(result)
	if result != null and result.packet != null and result.packet.source == get_parent() and result.final_damage > 0 and is_instance_valid(result.target) and (result.target.is_in_group("enemies") or result.target.is_in_group("bosses")):
		var path := PackedStringArray()
		var round_token := 0
		for tag in result.packet.status_tags:
			if tag.begins_with("event_path:"):
				path.append(tag.trim_prefix("event_path:"))
			elif tag.begins_with("circuit_round:"):
				round_token = tag.trim_prefix("circuit_round:").to_int()
		if round_token <= 0:
			round_token = result.get_instance_id()
		if result.target_defeated:
			_submit_event_starters(16, result.packet.travel_direction, PackedStringArray(["击杀"]), path, round_token)
		if (not result.packet.is_area_damage or result.packet.is_beam or result.packet.status_tags.has("rock_overload_wave")) and not result.packet.status_tags.has("circuit_echo"):
			_submit_event_starters(8, result.packet.travel_direction, PackedStringArray(["命中"]), path, round_token)
	_try_inertial_inversion(result)
	_try_arc_ballistic_cortex(result)
	_try_trajectory_echo(result)
	_try_micro_rotor_reflex_bundle(result)
	_try_predatory_vestibular_ring(result)


func _resolve_nonprojectile_modifiers(result: DamageResult) -> void:
	if result == null or result.packet == null or result.final_damage <= 0 or not is_instance_valid(result.target) or not result.target is Node2D:
		return
	if result.packet.status_tags.has("circuit_secondary"):
		return
	var copy_id := 0
	for tag in result.packet.status_tags:
		if tag.begins_with("circuit_copy:"):
			copy_id = tag.trim_prefix("circuit_copy:").to_int()
			break
	if not _nonprojectile_payloads.has(copy_id):
		return
	var payload: Dictionary = _nonprojectile_payloads[copy_id]
	_nonprojectile_payloads.erase(copy_id)
	var player := get_parent() as PlayerController
	if player == null:
		return
	var origin := result.target as Node2D
	var room := CombatProjectile.room_for_actor(player)
	var explosion_count := int(payload.get(&"explosion", 0))
	if explosion_count > 0:
		var shape := CircleShape2D.new()
		shape.radius = 48.0
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = shape
		query.transform = Transform2D(0.0, origin.global_position)
		query.collision_mask = 8 | 16
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var seen: Dictionary = {}
		for hit in origin.get_world_2d().direct_space_state.intersect_shape(query, 128):
			var hurt := hit.collider as HurtBox2DComponent
			if hurt == null or not is_instance_valid(hurt.actor) or hurt.actor == origin or hurt.actor == player or CombatProjectile.room_for_actor(hurt.actor) != room or seen.has(hurt.actor.get_instance_id()):
				continue
			seen[hurt.actor.get_instance_id()] = true
			var packet := DamagePacket.new()
			packet.base_damage = explosion_count
			packet.source = player
			packet.source_faction = CombatFaction.Id.PLAYER
			packet.weapon_id = result.packet.weapon_id
			packet.damage_type = &"explosive"
			packet.source_position = origin.global_position
			packet.travel_direction = origin.global_position.direction_to(hurt.actor.global_position)
			packet.status_tags = result.packet.status_tags.duplicate()
			packet.status_tags.append("circuit_secondary")
			packet.is_area_damage = true
			hurt.receive_hit(packet)
	var excluded := {origin.get_instance_id(): true}
	var chain_origin := origin
	for _index in int(payload.get(&"arc", 0)) * 2:
		var chained := _nearest_arc_target(chain_origin.global_position, 64.0, room, excluded)
		if chained == null:
			break
		excluded[chained.get_instance_id()] = true
		_apply_arc_paralysis(chained, 0.2)
		var hurt := chained.get_node_or_null("HurtBox") as HurtBox2DComponent
		if hurt != null:
			var packet := DamagePacket.new()
			packet.base_damage = maxi(ceili(float(result.final_damage) * 0.5), 1)
			packet.source = player
			packet.source_faction = CombatFaction.Id.PLAYER
			packet.weapon_id = result.packet.weapon_id
			packet.damage_type = &"electric"
			packet.source_position = chain_origin.global_position
			packet.travel_direction = chain_origin.global_position.direction_to(chained.global_position)
			packet.status_tags = result.packet.status_tags.duplicate()
			packet.status_tags.append("circuit_secondary")
			packet.is_area_damage = true
			hurt.receive_hit(packet)
		chain_origin = chained
	for index in int(payload.get(&"echo", 0)):
		_circuit_pending_echoes.append({
			"remaining": 0.18 * (index + 1), "target": origin,
			"position": origin.global_position - result.packet.travel_direction * 24.0,
			"direction": result.packet.travel_direction,
			"damage": maxi(ceili(float(result.final_damage) * 0.75), 1),
			"speed": 360.0, "weapon_id": result.packet.weapon_id,
			"damage_type": result.packet.damage_type,
			"status_tags": result.packet.status_tags.duplicate(),
		})


func _try_micro_rotor_reflex_bundle(result: DamageResult) -> void:
	if (
		not has_module(MICRO_ROTOR_REFLEX_BUNDLE)
		or result == null
		or result.final_damage <= 0
		or result.packet == null
		or result.packet.source != get_parent()
		or result.packet.is_continuous_damage
		or result.packet.is_terrain_damage
		or not (result.packet.is_projectile or result.packet.is_beam or result.packet.is_melee)
		or not is_instance_valid(result.target)
		or not (result.target.is_in_group("enemies") or result.target.is_in_group("bosses"))
	):
		return
	var data := _data(MICRO_ROTOR_REFLEX_BUNDLE)
	var player := get_parent() as PlayerController
	if data == null or player == null or player.weapons == null:
		return
	var attack_key := _arc_attack_key(result.packet)
	var context: Dictionary = _micro_rotor_attack_groups.get(attack_key, {
		"remaining": MICRO_ROTOR_ATTACK_MEMORY_SECONDS,
		"refunded_ratio": 0.0,
	})
	var desired_ratio: float = data.micro_rotor_kill_refund_ratio if result.target_defeated else data.micro_rotor_hit_refund_ratio
	var refunded_ratio := float(context.get("refunded_ratio", 0.0))
	context["remaining"] = MICRO_ROTOR_ATTACK_MEMORY_SECONDS
	if desired_ratio <= refunded_ratio:
		_micro_rotor_attack_groups[attack_key] = context
		return
	var cooldown_duration := player.weapons.get_cooldown_duration_for_weapon_id(result.packet.weapon_id)
	if cooldown_duration <= 0.0:
		return
	var added_ratio := desired_ratio - refunded_ratio
	player.weapons.reduce_cooldown(cooldown_duration * added_ratio)
	context["refunded_ratio"] = desired_ratio
	_micro_rotor_attack_groups[attack_key] = context
	module_triggered.emit(MICRO_ROTOR_REFLEX_BUNDLE)
	var target := result.target as Node2D
	var events := get_node_or_null("/root/CombatEvents")
	if events != null and target != null:
		events.request_effect(target.global_position, Color(0.4, 0.95, 1.0), 9.0, 0.12)
		events.request_effect(player.global_position, Color(1.0, 0.68, 0.22), 10.0, 0.14)
		events.publish_notice(&"micro_rotor_reflex_bundle", "微转子回转  %d%%" % roundi(desired_ratio * 100.0), Color(0.45, 0.95, 1.0), CombatNotice.Priority.NORMAL, 0.15, 0.55)


func _try_predatory_vestibular_ring(result: DamageResult) -> void:
	if (
		not has_module(PREDATORY_VESTIBULAR_RING)
		or result == null
		or not result.target_defeated
		or result.final_damage <= 0
		or result.packet == null
		or result.packet.source != get_parent()
		or result.packet.weapon_id.is_empty()
		or result.packet.is_continuous_damage
		or result.packet.is_terrain_damage
		or not (result.packet.is_projectile or result.packet.is_beam or result.packet.is_melee)
		or not is_instance_valid(result.target)
		or not (result.target.is_in_group("enemies") or result.target.is_in_group("bosses"))
	):
		return
	var attack_key := _arc_attack_key(result.packet)
	if _predatory_attack_groups.has(attack_key):
		return
	_predatory_attack_groups[attack_key] = PREDATORY_ATTACK_MEMORY_SECONDS
	var player := get_parent() as PlayerController
	if player == null or player.dash == null:
		return
	var deferred_refresh := player.dash.is_dashing()
	if deferred_refresh:
		_predatory_dash_refresh_pending = true
	else:
		player.dash.refresh_cooldown()
	module_triggered.emit(PREDATORY_VESTIBULAR_RING)
	_publish_predatory_refresh_feedback(result.target as Node2D, deferred_refresh)


func _on_dash_ended(_cancelled: bool) -> void:
	if not _predatory_dash_refresh_pending:
		return
	_predatory_dash_refresh_pending = false
	if not has_module(PREDATORY_VESTIBULAR_RING):
		return
	var player := get_parent() as PlayerController
	if player == null or player.dash == null:
		return
	if is_zero_approx(player.dash.cooldown_remaining):
		return
	player.dash.refresh_cooldown()
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.request_effect(player.global_position, Color(0.25, 0.95, 1.0), 14.0, 0.16)
		events.publish_notice(&"predatory_vestibular_ring_ready", "突进刷新", Color(0.35, 0.95, 1.0), CombatNotice.Priority.NORMAL, 0.12, 0.5)


func _publish_predatory_refresh_feedback(target: Node2D, deferred_refresh: bool) -> void:
	var player := get_parent() as PlayerController
	var events := get_node_or_null("/root/CombatEvents")
	if events == null or player == null:
		return
	if target != null:
		events.request_effect(target.global_position, Color(1.0, 0.2, 0.18), 10.0, 0.14)
	events.request_effect(player.global_position, Color(0.3, 0.9, 1.0), 12.0, 0.15)
	var notice := "突进待刷新" if deferred_refresh else "突进刷新"
	events.publish_notice(&"predatory_vestibular_ring", notice, Color(0.35, 0.95, 1.0), CombatNotice.Priority.NORMAL, 0.15, 0.55)


func _try_inertial_inversion(result: DamageResult) -> void:
	var player := get_parent() as PlayerController
	if (
		not has_module(INERTIAL_INVERSION_VERTEBRA)
		or _inertial_inversion_cooldown_remaining > 0.0
		or _inertial_inversion_triggered_this_dash
		or result == null
		or result.packet == null
		or result.target != player
		or result.ignore_reason != DamageResult.IgnoreReason.INVULNERABLE
		or result.packet.source_faction != CombatFaction.Id.ENEMY
		or result.packet.is_continuous_damage
		or result.packet.is_terrain_damage
		or player == null
		or not player.dash.provides_invulnerability()
	):
		return
	var data := _data(INERTIAL_INVERSION_VERTEBRA)
	if data == null:
		return
	_inertial_inversion_triggered_this_dash = true
	_inertial_inversion_cooldown_remaining = data.trigger_cooldown
	var player_room := CombatProjectile.room_for_actor(player)
	var seen := {}
	for candidate in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("bosses"):
		if not candidate is Node2D or not is_instance_valid(candidate):
			continue
		var target := candidate as Node2D
		var target_id := target.get_instance_id()
		var hurt := target.get_node_or_null("HurtBox") as HurtBox2DComponent
		var health := target.get_node_or_null("HealthComponent")
		if (
			seen.has(target_id)
			or target.is_queued_for_deletion()
			or hurt == null
			or not hurt.monitorable
			or (health != null and health.has_method("is_dead") and bool(health.call("is_dead")))
			or CombatProjectile.room_for_actor(target) != player_room
			or player.global_position.distance_to(target.global_position) > data.inertia_pulse_radius
		):
			continue
		seen[target_id] = true
		var direction := player.global_position.direction_to(target.global_position)
		if direction.is_zero_approx():
			direction = -player.dash.get_active_direction()
		if direction.is_zero_approx():
			direction = Vector2.RIGHT
		if target.has_method("apply_stagger"):
			target.call("apply_stagger", data.inertia_pulse_stagger_seconds)
		if target.has_method("apply_knockback"):
			target.call("apply_knockback", direction * data.inertia_pulse_knockback)
	module_triggered.emit(INERTIAL_INVERSION_VERTEBRA)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.request_effect(player.global_position, Color(0.35, 0.92, 1.0), data.inertia_pulse_radius, 0.22)
		events.request_effect(player.global_position, Color(0.9, 0.98, 1.0), data.inertia_pulse_radius * 0.55, 0.12)
		events.publish_notice(&"inertial_inversion_vertebra", "惯性逆变", Color(0.35, 0.92, 1.0), CombatNotice.Priority.NORMAL, 0.2, 0.65)


func _try_arc_ballistic_cortex(result: DamageResult) -> void:
	if (
		not has_module(ARC_BALLISTIC_CORTEX)
		or result == null
		or result.final_damage <= 0
		or result.packet == null
		or result.packet.source != get_parent()
		or result.packet.is_continuous_damage
		or not (result.packet.is_projectile or result.packet.is_beam or result.packet.is_melee)
		or not is_instance_valid(result.target)
		or not (result.target.is_in_group("enemies") or result.target.is_in_group("bosses"))
	):
		return
	var data := _data(ARC_BALLISTIC_CORTEX)
	var player := get_parent() as PlayerController
	var origin := result.target as Node2D
	if data == null or player == null or origin == null:
		return
	var attack_key := _arc_attack_key(result.packet)
	var context: Dictionary = _arc_attack_groups.get(attack_key, {
		"remaining": ARC_ATTACK_MEMORY_SECONDS,
		"targets": {},
	})
	context["remaining"] = ARC_ATTACK_MEMORY_SECONDS
	var targets: Dictionary = context.get("targets", {})
	var target_id := origin.get_instance_id()
	if targets.has(target_id):
		_arc_attack_groups[attack_key] = context
		return
	targets[target_id] = true
	_apply_arc_paralysis(origin, data.arc_paralysis_seconds)
	var events := get_node_or_null("/root/CombatEvents")
	var room := CombatProjectile.room_for_actor(player)
	if events != null:
		var from := result.packet.source_position
		if from.is_zero_approx():
			from = player.global_position
		events.electric_arc_requested.emit(from, origin.global_position, room)
		events.request_effect(origin.global_position, Color(0.38, 0.9, 1.0), 8.0, 0.12)
	var chain_origin := origin
	for _index in data.arc_chain_targets:
		var chained := _nearest_arc_target(chain_origin.global_position, data.arc_chain_radius, room, targets)
		if chained == null:
			break
		targets[chained.get_instance_id()] = true
		_apply_arc_paralysis(chained, data.arc_paralysis_seconds)
		if events != null:
			events.electric_arc_requested.emit(chain_origin.global_position, chained.global_position, room)
			events.request_effect(chained.global_position, Color(0.38, 0.9, 1.0), 8.0, 0.12)
		chain_origin = chained
	context["targets"] = targets
	_arc_attack_groups[attack_key] = context
	module_triggered.emit(ARC_BALLISTIC_CORTEX)


func _arc_attack_key(packet: DamagePacket) -> String:
	var group_id := packet.feedback_group_id
	if group_id <= 0:
		group_id = -int(packet.get_instance_id())
	var source_id := packet.source.get_instance_id() if is_instance_valid(packet.source) else 0
	return "%d:%d" % [source_id, group_id]


func _nearest_arc_target(origin: Vector2, radius: float, room: Node, excluded: Dictionary) -> Node2D:
	var best: Node2D
	var best_distance_squared := radius * radius
	var seen := {}
	for candidate in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("bosses"):
		if not candidate is Node2D or not is_instance_valid(candidate):
			continue
		var target := candidate as Node2D
		var id := target.get_instance_id()
		var hurt := target.get_node_or_null("HurtBox") as HurtBox2DComponent
		var health := target.get_node_or_null("HealthComponent")
		if (
			seen.has(id)
			or excluded.has(id)
			or target.is_queued_for_deletion()
			or hurt == null
			or not hurt.monitorable
			or (health != null and health.has_method("is_dead") and bool(health.call("is_dead")))
			or CombatProjectile.room_for_actor(target) != room
		):
			continue
		seen[id] = true
		var distance_squared := origin.distance_squared_to(target.global_position)
		if distance_squared > best_distance_squared:
			continue
		best_distance_squared = distance_squared
		best = target
	return best


func _apply_arc_paralysis(target: Node2D, seconds: float) -> void:
	if target.has_method("apply_paralysis"):
		target.call("apply_paralysis", seconds)
	elif target.has_method("apply_stagger"):
		target.call("apply_stagger", seconds)


func _tick_arc_attack_groups(delta: float) -> void:
	for key in _arc_attack_groups.keys():
		var context: Dictionary = _arc_attack_groups[key]
		context["remaining"] = maxf(float(context.get("remaining", 0.0)) - delta, 0.0)
		if is_zero_approx(float(context["remaining"])):
			_arc_attack_groups.erase(key)
		else:
			_arc_attack_groups[key] = context


func _tick_micro_rotor_attack_groups(delta: float) -> void:
	for key in _micro_rotor_attack_groups.keys():
		var context: Dictionary = _micro_rotor_attack_groups[key]
		context["remaining"] = maxf(float(context.get("remaining", 0.0)) - delta, 0.0)
		if is_zero_approx(float(context["remaining"])):
			_micro_rotor_attack_groups.erase(key)
		else:
			_micro_rotor_attack_groups[key] = context


func _tick_predatory_attack_groups(delta: float) -> void:
	for key in _predatory_attack_groups.keys():
		var remaining := maxf(float(_predatory_attack_groups[key]) - delta, 0.0)
		if is_zero_approx(remaining):
			_predatory_attack_groups.erase(key)
		else:
			_predatory_attack_groups[key] = remaining


func _try_trajectory_echo(result: DamageResult) -> void:
	if (
		not has_module(TRAJECTORY_ECHO_PROCESSOR)
		or _trajectory_echo_cooldown_remaining > 0.0
		or result == null
		or result.final_damage <= 0
		or result.packet == null
		or not result.packet.allows_trajectory_echo
		or result.packet.source != get_parent()
		or not is_instance_valid(result.target)
		or not (result.target.is_in_group("enemies") or result.target.is_in_group("bosses"))
	):
		return
	var data := _data(TRAJECTORY_ECHO_PROCESSOR)
	var player := get_parent() as PlayerController
	var origin := result.target as Node2D
	if data == null or player == null or origin == null:
		return
	var target := _nearest_echo_target(origin, data.trajectory_echo_radius)
	if target == null:
		return
	var hurt := target.get_node_or_null("HurtBox") as HurtBox2DComponent
	if hurt == null:
		return
	var direction := origin.global_position.direction_to(target.global_position)
	var packet := DamagePacket.new()
	packet.base_damage = maxi(int(ceil(float(result.final_damage) * data.trajectory_echo_damage_ratio)), 1)
	packet.source = player
	packet.source_faction = CombatFaction.Id.PLAYER
	packet.weapon_id = result.packet.weapon_id
	packet.damage_type = result.packet.damage_type
	packet.allow_status_reactions = false
	packet.source_position = origin.global_position
	packet.travel_direction = direction
	packet.is_area_damage = true
	hurt.receive_hit(packet)
	_trajectory_echo_cooldown_remaining = data.trigger_cooldown
	module_triggered.emit(TRAJECTORY_ECHO_PROCESSOR)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.electric_arc_requested.emit(
			origin.global_position,
			target.global_position,
			CombatProjectile.room_for_actor(player)
		)
		events.request_effect(origin.global_position, Color(0.68, 0.3, 1.0), 11.0, 0.16)
		events.request_effect(target.global_position, Color(0.25, 0.95, 1.0), 13.0, 0.18)
		events.publish_notice(&"trajectory_echo_processor", "轨迹折射", Color(0.55, 0.55, 1.0), CombatNotice.Priority.NORMAL, 0.2, 0.65)


func _nearest_echo_target(origin: Node2D, radius: float) -> Node2D:
	var best: Node2D
	var best_distance_squared := radius * radius
	var room := CombatProjectile.room_for_actor(origin)
	var world := origin.get_world_2d()
	if world == null:
		return null
	var seen := {}
	for candidate in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("bosses"):
		if not candidate is Node2D or not is_instance_valid(candidate) or candidate == origin:
			continue
		var target := candidate as Node2D
		var target_id := target.get_instance_id()
		var hurt := target.get_node_or_null("HurtBox") as HurtBox2DComponent
		var health := target.get_node_or_null("HealthComponent")
		if (
			seen.has(target_id)
			or target.is_queued_for_deletion()
			or hurt == null
			or not hurt.monitorable
			or (health != null and health.has_method("is_dead") and bool(health.call("is_dead")))
			or CombatProjectile.room_for_actor(target) != room
		):
			continue
		seen[target_id] = true
		var distance_squared := origin.global_position.distance_squared_to(target.global_position)
		if distance_squared > best_distance_squared:
			continue
		var sight := PhysicsRayQueryParameters2D.create(origin.global_position, target.global_position, 1)
		if not world.direct_space_state.intersect_ray(sight).is_empty():
			continue
		best_distance_squared = distance_squared
		best = target
	return best


func _on_perfect_guarded(result: DamageResult) -> void:
	if result == null or result.target != get_parent():
		return
	var tags := PackedStringArray(["完美格挡"])
	if result.packet != null and result.packet.status_tags.has("cyber_guard"):
		tags.append("赛博格挡")
	var direction := _player_aim_direction()
	if result.packet != null and not result.packet.travel_direction.is_zero_approx():
		direction = -result.packet.travel_direction
	# Guard starter is submitted when the guard action begins.


func _data(module_id: StringName) -> CyberwareData:
	if _data_by_module.has(module_id):
		return _data_by_module[module_id] as CyberwareData
	if module_id == AXON_RECYCLER:
		return load(ComponentRolls.cyberware_resource_path(module_id)) as CyberwareData
	return null


func _acquire_secondary_target(origin: Vector2, primary: Node2D) -> Node2D:
	var best: Node2D
	var best_distance := INF
	for candidate in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("bosses") + get_tree().get_nodes_in_group("wing_guards"):
		if not candidate is Node2D or candidate == primary or not is_instance_valid(candidate):
			continue
		var target := candidate as Node2D
		if not _is_homing_target_eligible(target):
			continue
		if CombatProjectile.room_for_actor(target) != CombatProjectile.room_for_actor(get_parent()):
			continue
		var aim_point := CombatProjectile.homing_aim_position(target, origin)
		var distance := origin.distance_squared_to(aim_point)
		if distance >= best_distance:
			continue
		var ray := PhysicsRayQueryParameters2D.create(origin, aim_point, 1)
		if not target.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		best = target
		best_distance = distance
	return best


func _acquire_target(origin: Vector2, aim_direction: Vector2, half_angle_degrees: float) -> Node2D:
	var best: Node2D
	var best_score := INF
	var heading := aim_direction.normalized()
	if heading.is_zero_approx():
		return null
	for candidate in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("bosses") + get_tree().get_nodes_in_group("wing_guards"):
		if not candidate is Node2D or not is_instance_valid(candidate):
			continue
		var target := candidate as Node2D
		if not _is_homing_target_eligible(target):
			continue
		if CombatProjectile.room_for_actor(target) != CombatProjectile.room_for_actor(get_parent()):
			continue
		var aim_point := CombatProjectile.homing_aim_position(target, origin)
		var offset := aim_point - origin
		if offset.is_zero_approx():
			continue
		var angle := absf(rad_to_deg(heading.angle_to(offset.normalized())))
		if angle > half_angle_degrees:
			continue
		var ray := PhysicsRayQueryParameters2D.create(origin, aim_point, 1)
		if not target.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		var score := angle * 8.0 + offset.length() * 0.01
		if score < best_score:
			best_score = score
			best = target
	return best


func _is_homing_target_eligible(target: Node2D) -> bool:
	if target is WingGuard:
		return target.active and not target.health.is_dead()
	if target is RooftopWhaleGoddess:
		return target.state == RooftopWhaleGoddess.State.ACTIVE and target.health.damage_enabled and not target.health.guard_link_active and not target.health.is_dead()
	return true
