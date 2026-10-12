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
