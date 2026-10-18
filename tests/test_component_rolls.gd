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

func test_rolls_have_unique_ids_and_no_ineffective_mobility_attack() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 127
	var ids := {}
	for index in 80:
		var item := ComponentRolls.create("wheel", 3, rng)
		var id: String = item.get_property("instance_id")
		assert_false(ids.has(id))
		ids[id] = true
		assert_false(ComponentRolls.affixes(item).has("attack"))
		assert_true(ComponentRolls.affixes(item).size() >= 1 and ComponentRolls.affixes(item).size() <= 3)

func test_shared_affixes_are_retained_at_stronger_value() -> void:
	var rng := RandomNumberGenerator.new()
	var a := ComponentRolls.create("pistol", 3, rng)
	var b := ComponentRolls.create("baton", 3, rng)
	a.set_property("affixes", {"attack": 20, "guard": 20, "status": 10})
	b.set_property("affixes", {"attack": 50, "guard": 60, "cooling": 30})
	for index in 15:
		var result := ComponentRolls.fuse(a, b, rng)
		assert_eq(ComponentRolls.quality(result), 3)
		assert_eq(ComponentRolls.affixes(result).get("attack"), 50.0)
		assert_eq(ComponentRolls.affixes(result).get("guard"), 60.0)
		assert_eq(ComponentRolls.affixes(result).size(), 3)

func test_different_quality_cannot_fuse() -> void:
	var rng := RandomNumberGenerator.new()
	var a := ComponentRolls.create("pistol", 1, rng)
	var b := ComponentRolls.create("baton", 2, rng)
	assert_false(ComponentRolls.compatible(a, b))
	assert_true(ComponentRolls.fuse(a, b, rng) == null)
