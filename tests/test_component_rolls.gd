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


func test_cyberware_fusion_is_order_independent_module_union() -> void:
	var rng := RandomNumberGenerator.new()
	var smart := ComponentRolls.create("smart_fire", 3, rng)
	var explosive := ComponentRolls.create("explosive_magazine", 1, rng)
	var duplicate := ComponentRolls.create("smart_fire", 1, rng)
	assert_eq(ComponentRolls.quality(smart), 0)
	assert_true(ComponentRolls.affixes(smart).is_empty())
	assert_true(ComponentRolls.compatible(smart, explosive))
	assert_false(ComponentRolls.compatible(smart, duplicate))
	var forward := ComponentRolls.fuse(smart, explosive, rng)
	var reverse := ComponentRolls.fuse(explosive, smart, rng)
	assert_eq(ComponentRolls.cyberware_modules(forward), ComponentRolls.cyberware_modules(reverse))
	assert_eq(ComponentRolls.cyberware_modules(forward), PackedStringArray(["explosive_magazine", "smart_fire"]))
	assert_eq(ComponentRolls.title(forward), "复合义体 [2/4]")


func test_cyberware_fusion_rejects_a_fifth_distinct_module() -> void:
	var rng := RandomNumberGenerator.new()
	var compound := ComponentRolls.create("smart_fire", 1, rng)
	for prototype_id in ["explosive_magazine", "tactical_coprocessor", "optical_intruder"]:
		compound = ComponentRolls.fuse(compound, ComponentRolls.create(prototype_id, 1, rng), rng)
	assert_eq(ComponentRolls.cyberware_modules(compound).size(), 4)
	var fifth := ComponentRolls.create("kill_heat_sink", 1, rng)
	assert_false(ComponentRolls.compatible(compound, fifth))
	assert_true(ComponentRolls.fuse(compound, fifth, rng) == null)

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
		assert_eq(ComponentRolls.affixes(result).get("capacity"), 30.0)
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


func test_calamity_flame_is_bound_and_outside_random_progression() -> void:
	var item := ComponentRolls.create("calamity_flame", 3, RandomNumberGenerator.new())
	assert_true(bool(item.get_property("bound", false)))
	assert_eq(ComponentRolls.quality(item), 0)
	assert_true(ComponentRolls.affixes(item).is_empty())
	assert_false(ComponentRolls.ordinary(item))
	assert_false(ComponentRolls.synthesizable(item))
