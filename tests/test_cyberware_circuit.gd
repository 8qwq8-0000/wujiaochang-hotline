@tool
extends McpTestSuite

const CyberwareCircuitStateScript := preload("res://scripts/gameplay/player/cyberware_circuit_state.gd")


func suite_name() -> String:
	return "cyberware_circuit"


func test_energy_recovery_bonuses_combine_without_heat() -> void:
	var circuit = _make_circuit()
	circuit.energy_recovery_bonus = 0.20
	circuit.room_energy_recovery_bonus = 0.50
	circuit.persona_energy_recovery_bonus = 0.25
	assert_true(is_equal_approx(circuit.energy_regen_rate(), 78.0))
	circuit.current_energy = 0.0
	circuit.advance(0.5)
	assert_true(is_equal_approx(circuit.current_energy, 39.0))


func test_frenzy_debt_has_a_hard_limit_and_survives_save() -> void:
	var circuit = _make_circuit()
	circuit.set_energy(5.0)
	assert_true(circuit.try_spend_energy(12.0, 100.0))
	assert_true(circuit.try_spend_energy(93.0, 100.0))
	assert_true(is_equal_approx(circuit.current_energy, -100.0))
	assert_false(circuit.try_spend_energy(1.0, 100.0))
	circuit.add_energy(40.0)
	assert_true(is_equal_approx(circuit.current_energy, -60.0))
	assert_false(circuit.try_spend_energy(12.0))
	var restored = _make_circuit()
	assert_true(restored.import_state(circuit.export_state()))
	assert_true(is_equal_approx(restored.current_energy, -60.0))


func test_first_playable_definitions_have_locked_energy_values() -> void:
	var expected := {
		&"active_neural_switch": [10.0, 0.0],
		&"combat_synapse_sensor": [12.0, 0.0],
		&"rhythm_pulser": [8.0, 0.0],
		&"smart_fire": [8.0, 0.0],
		&"explosive_magazine": [14.0, 0.0],
		&"tactical_coprocessor": [18.0, 0.0],
		&"kill_energy_sink": [10.0, 20.0],
		&"guard_coprocessor": [12.0, 0.0],
		&"instruction_mirror_synapse": [20.0, 0.0],
	}
	for module_id in expected:
		var data := load(ComponentRolls.cyberware_resource_path(module_id)) as CyberwareData
		assert_true(data != null)
		assert_eq(data.circuit_energy_cost, expected[module_id][0])
		assert_eq(data.fixed_energy_refund, expected[module_id][1])


func test_slots_require_owned_copies_and_known_definitions() -> void:
	var circuit = _make_circuit()
	assert_eq(circuit.slot_capacity, 3)
	assert_eq(circuit.maximum_energy, 60.0)
	circuit.set_library_counts({"smart_fire": 1})
	assert_true(bool(circuit.set_slots(PackedStringArray(["smart_fire"])).ok))
	assert_eq(circuit.get_available_count(&"smart_fire"), 0)
	assert_false(bool(circuit.set_slots(PackedStringArray(["smart_fire", "smart_fire"])).ok))
	assert_false(bool(circuit.set_slots(PackedStringArray(["missing_definition"])).ok))
	assert_eq(circuit.get_slots(), PackedStringArray(["smart_fire", "", ""]))
	assert_false(bool(circuit.set_slots(PackedStringArray(["smart_fire", "", "", ""])).ok))
	assert_true(circuit.set_slot_capacity(4))
	circuit.expand_capacity()
	assert_eq(circuit.get_slots().size(), 4)
	assert_eq(circuit.maximum_energy, 80.0)


func test_circuit_expands_to_six_and_preserves_capacity_in_save() -> void:
	var circuit = _make_circuit()
	circuit.set_library_counts({"active_neural_switch": 1, "smart_fire": 5})
	for capacity in [4, 5, 6]:
		assert_true(circuit.set_slot_capacity(capacity))
		circuit.expand_capacity()
	assert_eq(circuit.maximum_energy, 120.0)
	assert_eq(circuit.get_slots().size(), 6)
	assert_true(bool(circuit.set_slots(PackedStringArray(["active_neural_switch", "smart_fire", "smart_fire", "smart_fire", "smart_fire", "smart_fire"])).ok))
	assert_false(circuit.set_slot_capacity(5))
	var restored = _make_circuit()
	assert_true(restored.import_state(circuit.export_state()))
	assert_eq(restored.slot_capacity, 6)
	assert_eq(restored.get_slots(), circuit.get_slots())


func test_compile_counts_fixed_refunds_and_mirror_without_recursion() -> void:
	var circuit = _make_circuit()
	assert_true(circuit.set_slot_capacity(4))
	circuit.set_library_counts({
		"rhythm_pulser": 1,
		"kill_energy_sink": 1,
		"instruction_mirror_synapse": 1,
		"guard_coprocessor": 1,
	})
	assert_true(bool(circuit.set_slots(PackedStringArray([
		"rhythm_pulser",
		"kill_energy_sink",
		"instruction_mirror_synapse",
		"guard_coprocessor",
	])).ok))
	var plan: Dictionary = circuit.compile_plan()
	assert_true(bool(plan.ok))
	assert_eq(plan.gross_energy, 42.0)
	assert_eq(plan.fixed_energy_refund, 40.0)
	assert_eq(plan.net_energy, 2.0)
	assert_eq(plan.required_energy, 0.0)
	assert_eq(plan.steps[2].effect_id, &"kill_energy_sink")
	assert_eq(plan.steps[2].mirrored_from_slot, 1)
	assert_eq(plan.steps[3].effect_id, &"guard_coprocessor")


func test_round_starts_without_whole_plan_prepay_and_regenerates_40_per_second() -> void:
	var circuit = _make_circuit()
	assert_true(circuit.set_slot_capacity(4))
	circuit.set_library_counts({
		"active_neural_switch": 1,
		"smart_fire": 1,
		"explosive_magazine": 1,
		"tactical_coprocessor": 1,
	})
	assert_true(bool(circuit.set_slots(PackedStringArray([
		"active_neural_switch",
		"smart_fire",
		"explosive_magazine",
		"tactical_coprocessor",
	])).ok))
	circuit.set_energy(10.0)
	var request: Dictionary = circuit.request_round()
	assert_false(bool(request.waiting))
	assert_false(circuit.has_waiting_round())
	var started: Dictionary = circuit.take_started_plan()
	assert_false(started.is_empty())
	assert_eq(started.net_energy, 40.0)
	assert_eq(circuit.current_energy, 10.0)
	circuit.advance(1.0)
	assert_true(circuit.take_started_plan().is_empty())
	assert_eq(circuit.current_energy, 50.0)


func test_state_round_trip_preserves_library_slots_and_energy() -> void:
	var circuit = _make_circuit()
	circuit.set_library_counts({"rhythm_pulser": 1, "kill_energy_sink": 2})
	assert_true(bool(circuit.set_slots(PackedStringArray([
		"rhythm_pulser",
		"kill_energy_sink",
		"kill_energy_sink",
	])).ok))
	circuit.set_energy(37.5)
	assert_true(circuit.set_slot_capacity(4))
	circuit.expand_capacity()
	var restored = _make_circuit()
	assert_true(restored.import_state(circuit.export_state()))
	assert_eq(restored.get_library_counts(), circuit.get_library_counts())
	assert_eq(restored.get_slots(), circuit.get_slots())
	assert_eq(restored.current_energy, 57.5)
	assert_eq(restored.maximum_energy, 80.0)
	assert_eq(restored.slot_capacity, 4)
	var before: Dictionary = restored.export_state()
	assert_false(restored.import_state({
		"library": {"rhythm_pulser": 1},
		"slots": ["rhythm_pulser", "kill_energy_sink"],
		"current_energy": 1.0,
		"maximum_energy": 100.0,
	}))
	assert_eq(restored.export_state(), before)


func test_expanded_modules_compile_with_inversion_and_free_replay() -> void:
	var circuit = _make_circuit()
	assert_true(circuit.set_slot_capacity(4))
	var expanded := [
		"optical_intruder", "shock_pulser", "micro_rotor_reflex_bundle",
		"momentum_recovery_tendon", "ballistic_takeover_protocol", "arc_ballistic_cortex",
		"omnidirectional_reflection_matrix", "trajectory_echo_processor",
		"inertial_inversion_vertebra", "predatory_vestibular_ring", "calamity_flame",
	]
	for module_id in expanded:
		var data := load(ComponentRolls.cyberware_resource_path(StringName(module_id))) as CyberwareData
		assert_true(data != null)
		assert_true(data.circuit_energy_cost > 0.0)
		var counts := {"active_neural_switch": 1}
		counts[module_id] = 1
		circuit.set_library_counts(counts)
		assert_true(bool(circuit.set_slots(PackedStringArray(["active_neural_switch", module_id])).ok))
		assert_true(bool(circuit.compile_plan().ok))
	circuit.set_library_counts({"active_neural_switch": 1, "inertial_inversion_vertebra": 1, "kill_energy_sink": 1, "guard_coprocessor": 1})
	assert_true(bool(circuit.set_slots(PackedStringArray(["active_neural_switch", "inertial_inversion_vertebra", "kill_energy_sink", "guard_coprocessor"])).ok))
	var inverted: Dictionary = circuit.compile_plan()
	assert_eq(inverted.steps[2].effect_id, &"kill_energy_sink")
	assert_eq(inverted.steps[3].effect_id, &"guard_coprocessor")
	assert_eq(inverted.steps[4].effect_id, &"guard_coprocessor")
	assert_eq(inverted.steps[5].effect_id, &"kill_energy_sink")
	assert_eq(inverted.fixed_energy_refund, 40.0)
	circuit.set_library_counts({"active_neural_switch": 1, "inertial_inversion_vertebra": 1})
	assert_true(bool(circuit.set_slots(PackedStringArray(["active_neural_switch", "inertial_inversion_vertebra"])).ok))
	assert_eq(circuit.compile_plan().idle_inversion_scale, 1.0)
	circuit.set_library_counts({"active_neural_switch": 1, "kill_energy_sink": 1, "predatory_vestibular_ring": 1})
	assert_true(bool(circuit.set_slots(PackedStringArray(["active_neural_switch", "kill_energy_sink", "predatory_vestibular_ring"])).ok))
	var replay: Dictionary = circuit.compile_plan()
	assert_eq(replay.steps.size(), 5)
	assert_eq(replay.fixed_energy_refund, 40.0)
	assert_eq(replay.steps[4].effect_id, &"kill_energy_sink")


func test_multiple_starters_are_free_pass_through_and_mirror_uses_signal_neighbors() -> void:
	var circuit = _make_circuit()
	assert_true(circuit.set_slot_capacity(4))
	circuit.set_library_counts({
		"active_neural_switch": 1,
		"rhythm_pulser": 1,
		"smart_fire": 1,
		"instruction_mirror_synapse": 1,
	})
	assert_true(bool(circuit.set_slots(PackedStringArray([
		"active_neural_switch", "rhythm_pulser", "instruction_mirror_synapse", "smart_fire",
	])).ok))
	var from_active: Dictionary = circuit.compile_plan(&"active_neural_switch")
	assert_true(bool(from_active.ok))
	assert_eq(from_active.steps[0].module_id, &"rhythm_pulser")
	assert_eq(from_active.steps[1].effect_id, &"smart_fire")
	assert_eq(from_active.steps[1].mirrored_from_slot, 3)
	assert_eq(from_active.gross_energy, 38.0)
	var from_rhythm: Dictionary = circuit.compile_plan(&"rhythm_pulser")
	assert_true(bool(from_rhythm.ok))
	assert_eq(from_rhythm.steps[0].effect_id, &"smart_fire")
	assert_eq(from_rhythm.steps[0].mirrored_from_slot, 3)
	assert_eq(from_rhythm.gross_energy, 36.0)


func _make_circuit():
	var circuit = CyberwareCircuitStateScript.new()
	var definitions: Dictionary = {}
	for module_id in [
		&"active_neural_switch",
		&"combat_synapse_sensor",
		&"rhythm_pulser",
		&"smart_fire",
		&"explosive_magazine",
		&"tactical_coprocessor",
		&"kill_energy_sink",
		&"guard_coprocessor",
		&"instruction_mirror_synapse",
		&"optical_intruder", &"shock_pulser", &"micro_rotor_reflex_bundle",
		&"momentum_recovery_tendon", &"ballistic_takeover_protocol", &"arc_ballistic_cortex",
		&"omnidirectional_reflection_matrix", &"trajectory_echo_processor",
		&"inertial_inversion_vertebra", &"predatory_vestibular_ring", &"calamity_flame",
	]:
		definitions[module_id] = load(ComponentRolls.cyberware_resource_path(module_id))
	circuit.configure_definitions(definitions)
	return circuit
