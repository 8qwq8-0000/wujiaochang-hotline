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


func test_combat_layout_scales_partitions_and_doors_but_not_furniture() -> void:
	var source := CombatLayoutData.new()
	source.covers = [Rect2(300, 160, 40, 40)]
	source.covers.append(Rect2(200, 40, 6, 80))
	source.zones = [Rect2(0, 0, 320, 180)]
	source.enemy_positions = [Vector2(500, 180)]
	source.doors = [Vector4(600, 180, 0, 64)]
	var expanded := source.scaled_for_room(CombatRoom.ROOM_SCALE, CombatRoom.BASE_ROOM_SIZE)
	assert_eq(expanded.room_size, Vector2(960, 540))
	assert_eq(expanded.covers[0].size, Vector2(40, 40))
	assert_eq(expanded.covers[0].get_center(), Vector2(480, 270))
	assert_eq(expanded.covers[1].size, Vector2(9, 120))
	assert_eq(expanded.covers[1].get_center(), Vector2(304.5, 120))
	assert_eq(expanded.zones[0].size, Vector2(480, 270))
	assert_eq(expanded.enemy_positions[0], Vector2(750, 270))
	assert_eq(Vector2(expanded.doors[0].x, expanded.doors[0].y), Vector2(900, 270))
	assert_eq(expanded.doors[0].w, 96.0)


func test_billboard_playlist_holds_then_transitions() -> void:
	var playlist := BillboardPlaylist.new()
	playlist.configure([&"one", &"two", &"three"], 91)
	var first := playlist.current_id()
	playlist.advance(11.99)
	assert_eq(playlist.current_id(), first)
	assert_false(playlist.is_transitioning())
	playlist.advance(0.02)
	assert_true(playlist.is_transitioning())
	assert_eq(playlist.current_id(), first)
	playlist.advance(0.49)
	assert_false(playlist.is_transitioning())
	assert_ne(playlist.current_id(), first)


func test_billboard_playlist_shuffles_without_repeats() -> void:
	var playlist := BillboardPlaylist.new()
	playlist.configure([&"one", &"two", &"three"], 17)
	var seen := {playlist.current_id(): true}
	var previous := playlist.current_id()
	for step in 8:
		playlist.advance(BillboardPlaylist.ITEM_SECONDS)
		var current := playlist.current_id()
		assert_ne(current, previous)
		if step < 2:
			seen[current] = true
		previous = current
	assert_eq(seen.size(), 3)


func test_billboard_wall_playlist_holds_main_then_staggers_one_panel() -> void:
	var playlist := BillboardWallPlaylist.new()
	playlist.configure([&"one", &"two", &"three", &"four", &"five", &"six", &"seven", &"eight", &"nine", &"ten"], 91)
	var first_main := playlist.slot_id(0)
	assert_eq(playlist.slot_count(), 4)
	assert_eq(_unique_string_name_count(playlist.visible_ids()), 4)
	playlist.advance(11.99)
	assert_false(playlist.is_transitioning())
	assert_eq(playlist.slot_id(0), first_main)
	playlist.advance(0.02)
	assert_true(playlist.is_transitioning())
	assert_eq(playlist.transition_slot(), 0)
	playlist.advance(0.49)
	assert_false(playlist.is_transitioning())
	assert_ne(playlist.slot_id(0), first_main)
	playlist.advance(BillboardWallPlaylist.STAGGER_SECONDS - BillboardWallPlaylist.TRANSITION_SECONDS - 0.01)
	assert_false(playlist.is_transitioning())
	playlist.advance(0.02)
	assert_true(playlist.is_transitioning())
	assert_eq(playlist.transition_slot(), 1)


func test_billboard_wall_playlist_keeps_four_unique_ads_and_cycles_all_into_hero_slots() -> void:
	var playlist := BillboardWallPlaylist.new()
	playlist.configure([&"one", &"two", &"three", &"four", &"five", &"six", &"seven", &"eight", &"nine", &"ten"], 17)
	var seen_hero := {playlist.slot_id(0): true, playlist.slot_id(1): true}
	for cycle in 24:
		playlist.advance(BillboardWallPlaylist.ITEM_SECONDS)
		assert_eq(_unique_string_name_count(playlist.visible_ids()), 4)
		seen_hero[playlist.slot_id(0)] = true
		seen_hero[playlist.slot_id(1)] = true
	assert_eq(seen_hero.size(), 10)


func test_billboard_catalog_only_returns_approved_complete_entries() -> void:
	var catalog := BillboardAdCatalog.new()
	var pending := BillboardAdEntry.new()
	pending.id = &"pending"
	pending.approved = false
	var incomplete := BillboardAdEntry.new()
	incomplete.id = &"incomplete"
	incomplete.approved = true
	catalog.entries = [pending, incomplete]
	assert_true(catalog.approved_entries().is_empty())


func _unique_string_name_count(values: Array[StringName]) -> int:
	var unique := {}
	for value in values:
		unique[value] = true
	return unique.size()
