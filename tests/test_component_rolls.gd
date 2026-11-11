@tool
extends McpTestSuite

func suite_name() -> String:
	return "component_rolls"

func test_floor_weights_raise_quality_and_clamp() -> void:
	assert_eq(ComponentRolls.floor_weights(0), [85, 14, 1])
	assert_eq(ComponentRolls.floor_weights(4), [20, 45, 35])
	assert_eq(ComponentRolls.floor_weights(99), [20, 45, 35])
	for floor_number in range(1, 5):
		var weights := ComponentRolls.floor_weights(floor_number)
		assert_eq(weights[0] + weights[1] + weights[2], 100)

func test_heavy_weapons_have_slightly_lower_random_drop_odds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 981731
	var counts := {}
	for index in 3800:
		var item := ComponentRolls.floor_drop(index % 3 + 1, rng)
		var id: String = item.get_prototype().get_prototype_id()
		counts[id] = int(counts.get(id, 0)) + 1
	# Broad deterministic sampling checks the actual production entry point.
	for id in ["scattergun", "rail_cannon"]:
		assert_true(int(counts.get(id, 0)) > 0)
		assert_true(int(counts.get("armor", 0)) > int(counts.get(id, 0)))
	assert_true(counts.has("calamity_flame"))
	assert_true(counts.has("omnidirectional_reflection_matrix"))
	assert_false(counts.has("baton"))


func test_every_registered_cyberware_can_drop_on_first_floor_with_grade_weights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41857
	var grade_counts := [0, 0, 0, 0]
	var seen := {}
	var definitions := ComponentRolls.cyberware_resource_paths()
	for module_id in definitions:
		assert_true(not ComponentRolls.cyberware_resource_path(StringName(module_id)).is_empty())
		assert_true(ComponentInventory.PROTOTYPES.data.has(module_id))
	for index in 6000:
		var item := ComponentRolls.floor_drop(1, rng)
		var id: String = item.get_prototype().get_prototype_id()
		if definitions.has(StringName(id)):
			seen[id] = true
			var data := load(ComponentRolls.cyberware_resource_path(StringName(id))) as CyberwareData
			grade_counts[data.grade] += 1
	assert_eq(seen.size(), definitions.size())
	assert_true(grade_counts[1] > grade_counts[2] and grade_counts[2] > grade_counts[3])


func test_owned_cyberware_is_less_likely_to_repeat() -> void:
	var first := RandomNumberGenerator.new()
	var second := RandomNumberGenerator.new()
	first.seed = 90771
	second.seed = first.seed
	var fresh_count := 0
	var owned_count := 0
	for index in 3000:
		if ComponentRolls.floor_drop(3, first).get_prototype().get_prototype_id() == "smart_fire":
			fresh_count += 1
		if ComponentRolls.floor_drop(3, second, {"smart_fire": 5}).get_prototype().get_prototype_id() == "smart_fire":
			owned_count += 1
	assert_true(owned_count < fresh_count / 3)

func test_rolls_have_unique_ids_and_no_legacy_attack_affix() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 127
	var ids := {}
	for index in 80:
		var item := ComponentRolls.create("armor", 3, rng)
		var id: String = item.get_property("instance_id")
		assert_false(ids.has(id))
		ids[id] = true
		assert_false(ComponentRolls.affixes(item).has("attack"))
		assert_true(ComponentRolls.affixes(item).size() >= 1 and ComponentRolls.affixes(item).size() <= 3)


func test_ordinary_cyberware_fusion_is_disabled() -> void:
	var rng := RandomNumberGenerator.new()
	var smart := ComponentRolls.create("smart_fire", 3, rng)
	var explosive := ComponentRolls.create("explosive_magazine", 1, rng)
	var duplicate := ComponentRolls.create("smart_fire", 1, rng)
	assert_eq(ComponentRolls.quality(smart), 0)
	assert_true(ComponentRolls.affixes(smart).is_empty())
	assert_false(ComponentRolls.compatible(smart, explosive))
	assert_false(ComponentRolls.compatible(smart, duplicate))
	assert_true(ComponentRolls.fuse(smart, explosive, rng) == null)


func test_military_supply_rolls_only_military_and_forbidden_modules() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 76321
	var grades := {}
	for index in 100:
		var item := ComponentRolls.guaranteed_cyberware_drop(1, rng, {}, CyberwareData.Grade.MILITARY)
		var modules := ComponentRolls.cyberware_modules(item)
		if modules.size() != 1:
			assert_eq(modules.size(), 1)
			return
		var data := load(ComponentRolls.cyberware_resource_path(modules[0])) as CyberwareData
		grades[data.grade] = true
	assert_eq(grades.size(), 2)
	assert_true(grades.has(CyberwareData.Grade.MILITARY))
	assert_true(grades.has(CyberwareData.Grade.FORBIDDEN))


func test_event_starter_drop_group_has_two_starter_weights() -> void:
	var candidates := ComponentRolls._cyberware_drop_candidates({})
	var total := 0
	for id in ComponentRolls.EVENT_STARTER_DROPS:
		total += int(candidates.get(id, 0))
	assert_eq(total, 80)
	var owned := ComponentRolls._cyberware_drop_candidates({&"combat_synapse_sensor": 1})
	assert_false(owned.has("combat_synapse_sensor"))
	assert_eq(int(owned.get("combat_synapse_sensor_dash", 0)), 20)

func test_item_creation_restores_cleared_prototype_catalog() -> void:
	var stale := InventoryItem.new(ComponentInventory.PROTOTYPES, "pistol")
	stale.get_prototree().clear()
	assert_true(stale.get_prototree().is_empty())
	var restored := ComponentRolls.create("pistol", 1, RandomNumberGenerator.new())
	assert_true(restored.get_prototype() != null)
	assert_eq(restored.get_prototype().get_prototype_id(), "pistol")

func test_legacy_attack_affix_migrates_and_shared_affixes_survive() -> void:
	var rng := RandomNumberGenerator.new()
	var a := ComponentRolls.create("pistol", 3, rng)
	var b := ComponentRolls.create("scattergun", 3, rng)
	a.set_property("affixes", {"attack": 20, "guard": 20, "status": 10})
	b.set_property("affixes", {"attack": 50, "guard": 60, "cooling": 30})
	for index in 15:
		var result := ComponentRolls.fuse(a, b, rng)
		assert_eq(ComponentRolls.quality(result), 3)
		assert_false(ComponentRolls.affixes(result).has("attack"))
		assert_eq(ComponentRolls.affixes(result).get("attack_speed"), 30.0)
		assert_eq(ComponentRolls.affixes(result).get("guard"), 60.0)
		assert_eq(ComponentRolls.affixes(result).size(), 3)

func test_different_quality_cannot_fuse() -> void:
	var rng := RandomNumberGenerator.new()
	var a := ComponentRolls.create("pistol", 1, rng)
	var b := ComponentRolls.create("scattergun", 2, rng)
	assert_false(ComponentRolls.compatible(a, b))
	assert_true(ComponentRolls.fuse(a, b, rng) == null)

func test_issued_pistol_is_unbound_and_uses_normal_synthesis_rules() -> void:
	var rng := RandomNumberGenerator.new()
	var starter := ComponentRolls.create_issued_pistol()
	var material := ComponentRolls.create("pistol", 1, rng)
	material.set_property("affixes", {"guard": 40})
	starter.set_property("affixes", {"guard": 20})
	assert_true(ComponentRolls.compatible(starter, material))
	assert_true(ComponentRolls.affixes(starter).size() == 1)
	var result := ComponentRolls.fuse(starter, material, rng)
	assert_eq(result.get_prototype().get_prototype_id(), "pistol")
	assert_eq(ComponentRolls.quality(result), 2)
	assert_eq(ComponentRolls.affixes(result), {"guard": 40.0})
	assert_false(bool(result.get_property("bound", false)))
	var another_starter := ComponentRolls.create("pistol", 1, rng)
	var from_starters := ComponentRolls.fuse(starter, another_starter, rng)
	assert_true(ComponentRolls.affixes(from_starters).size() >= 1)


func test_calamity_drop_is_an_unbound_circuit_module() -> void:
	var item := ComponentRolls.create("calamity_flame", 3, RandomNumberGenerator.new())
	assert_false(bool(item.get_property("bound", false)))
	assert_eq(item.get_property("slot"), "cyberware")
	assert_eq(item.get_property("effect"), "res://resources/cyberware/calamity_flame.tres")
	assert_eq(ComponentRolls.quality(item), 0)
	assert_true(ComponentRolls.affixes(item).is_empty())
	assert_false(ComponentRolls.ordinary(item))
	assert_true(ComponentRolls.synthesizable(item))


func test_forged_event_starter_is_excluded_from_duplicate_drops() -> void:
	var candidates := ComponentRolls._cyberware_drop_candidates({&"combat_synapse_sensor_combo_9": 1})
	assert_false(candidates.has("combat_synapse_sensor"))
	assert_false(candidates.has("combat_synapse_sensor_hit"))
	assert_true(candidates.has("combat_synapse_sensor_dash"))


func test_prototype_tree_releases_nested_inheritance_references() -> void:
	var tree := ProtoTree.new()
	var root := tree.get_root()
	root.set_property("inherited", 7)
	var parent := tree.create_prototype("parent")
	var child := parent.inherit("child")
	var root_ref: WeakRef = weakref(root)
	var parent_ref: WeakRef = weakref(parent)
	var child_ref: WeakRef = weakref(child)
	tree = null
	assert_eq(child.get_property("inherited"), 7)
	root = null
	parent = null
	child = null
	assert_true(root_ref.get_ref() == null)
	assert_true(parent_ref.get_ref() == null)
	assert_true(child_ref.get_ref() == null)
