@tool
extends McpTestSuite


func suite_name() -> String:
	return "floor_assembler"


func test_weighted_room_selection_edges() -> void:
	var assembler := FloorAssembler.new()
	var weights := PackedFloat32Array([1.0, 2.0, 1.0])
	assert_eq(assembler.choose_weighted_index(weights, 0.0), 0)
	assert_eq(assembler.choose_weighted_index(weights, 0.26), 1)
	assert_eq(assembler.choose_weighted_index(weights, 0.76), 2)
	assembler.free()


func test_weighted_room_selection_rejects_empty_weight() -> void:
	var assembler := FloorAssembler.new()
	assert_eq(assembler.choose_weighted_index(PackedFloat32Array([0.0, 0.0]), 0.5), -1)
	assembler.free()


func test_combat_layout_expands_spacing_without_scaling_cover() -> void:
	var source := CombatLayoutData.new()
	source.covers = [Rect2(300, 160, 40, 40)]
	source.zones = [Rect2(0, 0, 320, 180)]
	source.enemy_positions = [Vector2(500, 180)]
	source.doors = [Vector4(600, 180, 0, 64)]
	var expanded := source.scaled_for_room(CombatRoom.ROOM_SCALE, CombatRoom.BASE_ROOM_SIZE)
	assert_eq(expanded.room_size, Vector2(960, 540))
	assert_eq(expanded.covers[0].size, Vector2(40, 40))
	assert_eq(expanded.covers[0].get_center(), Vector2(480, 270))
	assert_eq(expanded.zones[0].size, Vector2(480, 270))
	assert_eq(expanded.enemy_positions[0], Vector2(750, 270))
	assert_eq(Vector2(expanded.doors[0].x, expanded.doors[0].y), Vector2(900, 270))
