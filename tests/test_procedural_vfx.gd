@tool
extends McpTestSuite

const COATING_SCRIPT := preload("res://scripts/presentation/procedural_coating_2d.gd")
const STAIN_LAYER_SCRIPT := preload("res://scripts/presentation/cyber_stain_layer.gd")


func suite_name() -> String:
	return "procedural_vfx"


func test_coating_layout_is_seeded_and_bounded() -> void:
	var coating: Variant = track(COATING_SCRIPT.new())
	var test_rects: Array[Rect2] = [
		Rect2(0.0, 0.0, 12.0, 6.0),
		Rect2(14.0, 0.0, 10.0, 6.0),
	]
	coating.safe_rects = test_rects
	coating.mark_count = 2
	coating.configure(8128, &"test_weapon")
	var first_hash: int = coating.get_layout_hash()
	assert_eq(coating.get_mark_count(), 2)
	coating.configure(8128, &"test_weapon")
	assert_eq(coating.get_layout_hash(), first_hash)
	coating.configure(8129, &"test_weapon")
	assert_ne(coating.get_layout_hash(), first_hash)


func test_stains_are_deterministic_and_respect_budget() -> void:
	var layer: Variant = track(STAIN_LAYER_SCRIPT.new())
	layer.stain_budget = 2
	(Engine.get_main_loop() as SceneTree).root.add_child(layer)
	layer.spawn_stain(Vector2.ZERO, 4001, EnemyProfile.Role.MELEE_PRESSURE)
	var first_hash: int = layer.get_stain_shape_hash(0)
	layer.clear_stains()
	layer.spawn_stain(Vector2.ZERO, 4001, EnemyProfile.Role.MELEE_PRESSURE)
	assert_eq(layer.get_stain_shape_hash(0), first_hash)
	layer.spawn_stain(Vector2(10.0, 0.0), 4002, EnemyProfile.Role.RANGED_SIGHTLINE)
	layer.spawn_stain(Vector2(20.0, 0.0), 4003, EnemyProfile.Role.HEAVY_ANCHOR)
	assert_eq(layer.get_stain_count(), 2)
	assert_eq(layer.get_retired_stain_count(), 1)


func test_stain_shape_uses_motion_and_impact_direction() -> void:
	var layer: Variant = track(STAIN_LAYER_SCRIPT.new())
	layer.obstacle_collision_mask = 0
	(Engine.get_main_loop() as SceneTree).root.add_child(layer)
	layer.spawn_stain(
		Vector2.ZERO,
		8119,
		EnemyProfile.Role.MELEE_PRESSURE,
		Vector2.RIGHT,
		Vector2.DOWN
	)
	var data: Dictionary = layer.get_stain_debug_data(0)
	assert_eq(data["motion_direction"], Vector2.RIGHT)
	assert_eq(data["impact_direction"], Vector2.DOWN)
	var outline: PackedVector2Array = data["outer"]
	var minimum_x := INF
	var maximum_x := -INF
	for point in outline:
		minimum_x = minf(minimum_x, point.x)
		maximum_x = maxf(maximum_x, point.x)
	assert_gt(absf(minimum_x), maximum_x)
	var droplet_positions: PackedVector2Array = data["droplet_positions"]
	var average_y := 0.0
	for point in droplet_positions:
		average_y += point.y
	average_y /= maxf(float(droplet_positions.size()), 1.0)
	assert_gt(average_y, 0.0)


func test_stain_stops_processing_after_settling() -> void:
	var layer: Variant = track(STAIN_LAYER_SCRIPT.new())
	layer.obstacle_collision_mask = 0
	(Engine.get_main_loop() as SceneTree).root.add_child(layer)
	layer.spawn_stain(Vector2.ZERO, 9201)
	layer._process(1.0)
	assert_false(layer.is_processing())


func test_vfx_manager_owns_and_clears_stains() -> void:
	var manager := track(VFXManager.new()) as VFXManager
	manager.prewarm_count = 1
	manager.stain_budget = 3
	(Engine.get_main_loop() as SceneTree).root.add_child(manager)
	var profile := EnemyProfile.new()
	profile.id = &"test"
	profile.role = EnemyProfile.Role.RANGED_SIGHTLINE
	manager.spawn_death_stain(Vector2(12.0, 18.0), profile)
	assert_eq(manager.get_stain_count(), 1)
	manager.clear_stains()
	assert_eq(manager.get_stain_count(), 0)
