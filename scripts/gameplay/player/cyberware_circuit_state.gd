class_name CyberwareCircuitState
extends RefCounted


func get_definition(module_id: StringName) -> CyberwareData:
	return _definitions.get(module_id) as CyberwareData

const INITIAL_SLOT_COUNT := 3
const SLOT_COUNT := 6
const DEFAULT_MAXIMUM_ENERGY := 80.0
const ENERGY_REGEN_PER_SECOND := 40.0
const MIRROR_MODULE_ID := &"instruction_mirror_synapse"
const RELAY_STARTER_ID := &"relay_starter"

var current_energy := DEFAULT_MAXIMUM_ENERGY
var maximum_energy := DEFAULT_MAXIMUM_ENERGY
var slot_capacity := INITIAL_SLOT_COUNT
var energy_recovery_bonus := 0.0
var room_energy_recovery_bonus := 0.0
var persona_energy_recovery_bonus := 0.0

var _definitions: Dictionary = {}
var _library: Dictionary = {}
var _slots := PackedStringArray(["", "", ""])
var _pending_plan: Dictionary = {}
var _started_plans: Array[Dictionary] = []


func configure_definitions(definitions: Dictionary) -> void:
	_definitions = definitions.duplicate()


func set_library_counts(counts: Dictionary) -> void:
	_library.clear()
	for raw_id in counts:
		var module_id := StringName(str(raw_id))
		var count := maxi(int(counts[raw_id]), 0)
		if not module_id.is_empty() and count > 0:
			_library[module_id] = count


func get_library_counts() -> Dictionary:
	return _library.duplicate(true)


func get_installed_count(module_id: StringName) -> int:
	var count := 0
	for installed_id in _slots:
		if StringName(installed_id) == module_id:
			count += 1
	return count


func get_available_count(module_id: StringName) -> int:
	return maxi(int(_library.get(module_id, 0)) - get_installed_count(module_id), 0)


func set_slots(module_ids: PackedStringArray) -> Dictionary:
	var validation := validate_slots(module_ids)
	if not bool(validation.get("ok", false)):
		return validation
	_slots = _normalized_slots(module_ids)
	return {"ok": true, "errors": PackedStringArray()}


func get_slots() -> PackedStringArray:
	return _slots.duplicate()


func validate_slots(module_ids: PackedStringArray) -> Dictionary:
	var errors := PackedStringArray()
	if module_ids.size() > slot_capacity:
		errors.append("回路最多只能安装 %d 件义体" % slot_capacity)
	var required: Dictionary = {}
	for raw_id in module_ids:
		var module_id := StringName(raw_id)
		if module_id.is_empty():
			continue
		if not _definitions.has(module_id):
			errors.append("缺少义体定义：%s" % String(module_id))
			continue
		required[module_id] = int(required.get(module_id, 0)) + 1
	for module_id in required:
		if int(required[module_id]) > int(_library.get(module_id, 0)):
			errors.append(
				"义体数量不足：%s（需要 %d，持有 %d）" % [
					String(module_id),
					int(required[module_id]),
					int(_library.get(module_id, 0)),
				]
			)
	return {"ok": errors.is_empty(), "errors": errors}


func compile_plan(start_module_id: StringName = &"") -> Dictionary:
	var validation := validate_slots(_slots)
	if not bool(validation.get("ok", false)):
		return {"ok": false, "errors": validation.get("errors", PackedStringArray())}
	var steps: Array[Dictionary] = []
	var gross_energy := 0.0
	var fixed_refund := 0.0
	var replay_count := 0
	var ordered_indexes: Array[int] = []
	var start_index := -1
	if not start_module_id.is_empty():
		for index in _slots.size():
			if StringName(_slots[index]) == start_module_id:
				start_index = index
				break
	for offset in _slots.size():
		ordered_indexes.append((start_index + 1 + offset) % _slots.size())
	for slot_index in ordered_indexes:
		var module_id := StringName(_slots[slot_index])
		if module_id.is_empty():
			continue
		var data := _definitions.get(module_id) as CyberwareData
		if data == null:
			return {"ok": false, "errors": PackedStringArray(["义体定义不可用：%s" % String(module_id)])}
		var effect_id := module_id
		var mirrored_from_slot := -1
		var step_refund := data.fixed_energy_refund
		gross_energy += data.circuit_energy_cost
		fixed_refund += step_refund
		steps.append({
			"slot": slot_index,
			"module_id": module_id,
			"effect_id": effect_id,
			"mirrored_from_slot": mirrored_from_slot,
			"energy_cost": data.circuit_energy_cost,
			"fixed_energy_refund": step_refund,
			"scale": 1.0,
			"replay": false,
		})
	if steps.is_empty():
		return {"ok": false, "errors": PackedStringArray(["回路中没有义体"])}
	var cursor := 0
	var idle_inversion_scale := 1.0
	while cursor < steps.size():
		if not _resolve_mirror_at(steps, cursor):
			return {"ok": false, "errors": PackedStringArray(["指令镜像两侧没有可复制的义体"])}
		if StringName(steps[cursor].effect_id) == &"inertial_inversion_vertebra" and not bool(steps[cursor].get("fold_return", false)) and not bool(steps[cursor].get("folded", false)):
			steps[cursor]["folded"] = true
			var tail := steps.slice(cursor + 1)
			tail.reverse()
			for raw_step in tail:
				var inverted: Dictionary = raw_step.duplicate(true)
				inverted["fold_return"] = true
				steps.append(inverted)
			if steps.size() > 64:
				return {"ok": false, "errors": PackedStringArray(["回路折返次数过多"])}
		cursor += 1
	for index in steps.size():
		if not _resolve_mirror_at(steps, index):
			return {"ok": false, "errors": PackedStringArray(["指令镜像两侧没有可复制的义体"])}
	for step in steps:
		if StringName(step.effect_id) == &"predatory_vestibular_ring":
			replay_count += 1
	gross_energy = 0.0
	fixed_refund = 0.0
	for step in steps:
		var definition := _definitions.get(StringName(step.module_id)) as CyberwareData
		if not bool(step.replay) and definition != null and (definition.circuit_kind != CyberwareData.CircuitKind.STARTER or StringName(step.module_id) == RELAY_STARTER_ID):
			gross_energy += float(step.energy_cost)
		fixed_refund += float(step.fixed_energy_refund) * float(step.scale)
	if replay_count > 0:
		var original := steps.duplicate(true)
		for replay_index in replay_count:
			for raw_step in original:
				var copied: Dictionary = raw_step.duplicate(true)
				if StringName(copied.effect_id) == &"predatory_vestibular_ring":
					continue
				copied["scale"] = float(copied.scale)
				copied["replay"] = true
				copied["replay_index"] = replay_index
				fixed_refund += float(copied.fixed_energy_refund) * float(copied.scale)
				steps.append(copied)
	var projected_energy := current_energy
	var projected_stop_slot := -1
	var starter_paid := false
	var remaining_discount := false
	if start_index >= 0:
		var start_data := _definitions.get(StringName(_slots[start_index])) as CyberwareData
		if start_data != null:
			gross_energy += start_data.circuit_energy_cost
			if projected_energy + 0.0001 < start_data.circuit_energy_cost:
				projected_stop_slot = start_index
			else:
				projected_energy -= start_data.circuit_energy_cost
	for step in steps:
		if projected_stop_slot >= 0:
			break
		var step_data := _definitions.get(StringName(step.module_id)) as CyberwareData
		var starter_step := step_data != null and step_data.circuit_kind == CyberwareData.CircuitKind.STARTER and StringName(step.module_id) != RELAY_STARTER_ID
		var paid_starter_step := start_index >= 0 and int(step.slot) == start_index and not starter_paid and not bool(step.replay)
		if paid_starter_step:
			starter_paid = true
		var cost := 0.0 if starter_step or paid_starter_step or bool(step.replay) else float(step.energy_cost)
		if remaining_discount:
			cost *= 0.5
		if projected_energy + 0.0001 < cost:
			projected_stop_slot = int(step.slot)
			break
		projected_energy = minf(projected_energy - cost + float(step.fixed_energy_refund) * float(step.scale), maximum_energy)
		if StringName(step.effect_id) == &"axon_recycler":
			remaining_discount = true
	var net_energy := gross_energy - fixed_refund
	return {
		"ok": true,
		"errors": PackedStringArray(),
		"slots": _slots.duplicate(),
		"steps": steps,
		"gross_energy": gross_energy,
		"fixed_energy_refund": fixed_refund,
		"net_energy": net_energy,
		"projected_stop_slot": projected_stop_slot,
		"required_energy": 0.0,
		"replay_count": replay_count,
		"idle_inversion_scale": idle_inversion_scale,
	}


func _is_copyable_step(step: Dictionary) -> bool:
	var module_id := StringName(step.get("module_id", ""))
	if module_id.is_empty() or module_id == MIRROR_MODULE_ID:
		return false
	var data := _definitions.get(module_id) as CyberwareData
	return data != null and (data.circuit_kind != CyberwareData.CircuitKind.STARTER or module_id == RELAY_STARTER_ID)


func _resolve_mirror_at(steps: Array[Dictionary], index: int) -> bool:
	if StringName(steps[index].module_id) != MIRROR_MODULE_ID:
		return true
	var neighbor := index - 1
	if neighbor < 0 or not _is_copyable_step(steps[neighbor]):
		neighbor = index + 1
	if neighbor >= steps.size() or not _is_copyable_step(steps[neighbor]):
		return false
	var source: Dictionary = steps[neighbor]
	var source_id := StringName(source.module_id)
	var source_data := _definitions.get(source_id) as CyberwareData
	steps[index]["effect_id"] = source_id
	steps[index]["mirrored_from_slot"] = int(source.slot)
	steps[index]["fixed_energy_refund"] = source_data.fixed_energy_refund if source_data != null else 0.0
	return true


func request_round() -> Dictionary:
	var plan := compile_plan()
	if not bool(plan.get("ok", false)):
		return plan
	_start_plan(plan)
	return {"ok": true, "started": true, "waiting": false, "plan": plan}


func advance(delta: float) -> void:
	if delta > 0.0:
		current_energy = minf(current_energy + energy_regen_rate() * delta, maximum_energy)


func energy_regen_rate() -> float:
	return ENERGY_REGEN_PER_SECOND * (1.0 + maxf(energy_recovery_bonus + room_energy_recovery_bonus + persona_energy_recovery_bonus, 0.0))


func has_waiting_round() -> bool:
	return not _pending_plan.is_empty()


func clear_waiting_round() -> void:
	_pending_plan.clear()


func take_started_plan() -> Dictionary:
	if _started_plans.is_empty():
		return {}
	return _started_plans.pop_front()


func set_energy(value: float) -> void:
	current_energy = clampf(value, -100.0, maximum_energy)


func add_energy(amount: float) -> void:
	current_energy = clampf(current_energy + amount, -100.0, maximum_energy)


func can_start_plan(plan: Dictionary) -> bool:
	return bool(plan.get("ok", false))


func try_spend_energy(amount: float, debt_limit: float = 0.0) -> bool:
	var cost := maxf(amount, 0.0)
	if current_energy - cost < -maxf(debt_limit, 0.0) - 0.0001:
		return false
	current_energy -= cost
	return true


func start_compiled_plan(plan: Dictionary) -> bool:
	if not can_start_plan(plan):
		return false
	_start_plan(plan)
	return true


func expand_capacity(amount: float = 20.0) -> void:
	var increase := maxf(amount, 0.0)
	maximum_energy += increase
	current_energy = minf(current_energy + increase, maximum_energy)


func set_slot_capacity(value: int) -> bool:
	var next_capacity := clampi(value, INITIAL_SLOT_COUNT, SLOT_COUNT)
	for index in range(next_capacity, _slots.size()):
		if not _slots[index].is_empty():
			return false
	slot_capacity = next_capacity
	_slots.resize(slot_capacity)
	for index in _slots.size():
		if _slots[index].is_empty():
			_slots[index] = ""
	return true


func export_state() -> Dictionary:
	var serialized_library: Dictionary = {}
	for module_id in _library:
		serialized_library[String(module_id)] = int(_library[module_id])
	return {
		"library": serialized_library,
		"slots": Array(_slots),
		"slot_capacity": slot_capacity,
		"current_energy": current_energy,
		"maximum_energy": maximum_energy,
	}


func import_state(state: Dictionary) -> bool:
	if state.is_empty():
		return true
	var previous_library := _library.duplicate(true)
	var previous_slots := _slots.duplicate()
	var previous_capacity := slot_capacity
	var previous_current := current_energy
	var previous_maximum := maximum_energy
	var migrated_library := {}
	for raw_id in (state.get("library", {}) as Dictionary):
		var id: String = str(ComponentRolls.LEGACY_CYBERWARE_IDS.get(str(raw_id), str(raw_id)))
		migrated_library[id] = int(migrated_library.get(id, 0)) + int(state.library[raw_id])
	set_library_counts(migrated_library)
	maximum_energy = maxf(float(state.get("maximum_energy", DEFAULT_MAXIMUM_ENERGY)), 1.0)
	current_energy = clampf(float(state.get("current_energy", maximum_energy)), -100.0, maximum_energy)
	var imported_slots := PackedStringArray(state.get("slots", []))
	for index in imported_slots.size():
		imported_slots[index] = ComponentRolls.LEGACY_CYBERWARE_IDS.get(imported_slots[index], imported_slots[index])
	slot_capacity = clampi(int(state.get("slot_capacity", maxi(imported_slots.size(), INITIAL_SLOT_COUNT))), INITIAL_SLOT_COUNT, SLOT_COUNT)
	var result := set_slots(imported_slots)
	if bool(result.get("ok", false)):
		_pending_plan.clear()
		_started_plans.clear()
		return true
	_library = previous_library
	_slots = previous_slots
	slot_capacity = previous_capacity
	current_energy = previous_current
	maximum_energy = previous_maximum
	return false


func _start_plan(plan: Dictionary) -> void:
	_started_plans.append(plan.duplicate(true))


func _normalized_slots(module_ids: PackedStringArray) -> PackedStringArray:
	var result := PackedStringArray()
	result.resize(slot_capacity)
	for index in slot_capacity:
		result[index] = ""
	for index in mini(module_ids.size(), slot_capacity):
		result[index] = module_ids[index]
	return result
