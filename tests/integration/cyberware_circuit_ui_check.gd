extends SceneTree

var failures := 0
var world: Node2D
var player: PlayerController
var hud: CanvasLayer
var capture_directory := ""


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_directory = argument.trim_prefix("--capture-dir=")
	root.size = Vector2i(640, 360)
	world = Node2D.new()
	world.add_to_group("combat_rooms")
	root.add_child(world)
	current_scene = world
	player = load("res://scenes/actors/player/player.tscn").instantiate() as PlayerController
	world.add_child(player)
	hud = load("res://scenes/ui/combat_hud.tscn").instantiate() as CanvasLayer
	world.add_child(hud)
	await process_frame
	await process_frame
	check(hud.has_method("get_circuit_editor") and hud.has_method("get_circuit_hud_snapshot"), "combat HUD loads the circuit UI script")
	if not hud.has_method("get_circuit_editor") or not hud.has_method("get_circuit_hud_snapshot"):
		print("Cyberware circuit UI failures: ", failures)
		root.get_node("GameSettings").quit_game(1)
		return
	var editor = hud.get_circuit_editor()
	check(editor != null and editor.has_method("set_open"), "combat HUD constructs the circuit editor")
	if editor == null or not editor.has_method("set_open"):
		print("Cyberware circuit UI failures: ", failures)
		root.get_node("GameSettings").quit_game(1)
		return
	player.set_physics_process(false)
	player.cyberware.set_physics_process(false)
	check(player.cyberware.circuit.slot_capacity == 3 and hud.get_circuit_editor().get_slot_button_count() == 3, "new run exposes three circuit slots")
	var config_hint := hud.get("_circuit_config_hint") as Label
	var circuit_hud := hud.get("_circuit_hud") as Control
	check(config_hint != null and config_hint.text == "[C]" and config_hint.position.x + config_hint.size.x <= circuit_hud.position.x, "blinking C hint sits to the left of the circuit")
	if config_hint != null:
		var first_alpha := config_hint.modulate.a
		hud._process(0.3)
		check(not is_equal_approx(config_hint.modulate.a, first_alpha), "C hint changes opacity over time")

	_configure_sample()
	await process_frame
	_test_key_contract()
	await _test_editor_open_and_preview()
	await _test_library_pagination()
	await _test_runtime_pointer_and_snapshot_edit()
	await _test_library_click_rebuild_is_deferred()
	await _test_hud_module_cards_drag_reorder()
	await _test_editor_card_drag_reorder()
	await _test_auto_compact_reflow()
	await _test_drag_over_origin_clears_reflow_ghosts()
	await _test_five_slot_drag_alignment()
	_test_right_click_unloads_and_expanded_slots()

	paused = false
	print("Cyberware circuit UI failures: ", failures)
	root.get_node("GameSettings").quit_game(0 if failures == 0 else 1)


func _configure_sample() -> void:
	if player.cyberware.circuit.slot_capacity < 4:
		player.cyberware.circuit.set_slot_capacity(4)
		player.cyberware.circuit.expand_capacity()
		player.cyberware.circuit_changed.emit(player.cyberware.export_circuit_state())
	var ids := [
		"active_neural_switch",
		"smart_fire",
		"explosive_magazine",
		"tactical_coprocessor",
		"combat_synapse_sensor",
		"rhythm_pulser",
		"kill_energy_sink",
		"guard_coprocessor",
		"instruction_mirror_synapse",
	]
	var counts: Dictionary = {}
	for module_id in ids:
		counts[module_id] = 2
	player.cyberware.set_circuit_library_counts(counts)
	var result := player.cyberware.set_circuit_slots(PackedStringArray(ids.slice(0, 4)))
	check(bool(result.get("ok", false)), "sample circuit configures")


func _test_key_contract() -> void:
	check(InputMap.has_action("circuit_editor"), "project exposes a dedicated circuit editor action")
	check(_action_has_key(&"circuit_editor", KEY_C), "C opens the circuit editor")
	check(_action_has_key(&"interact", KEY_E), "E remains the interaction key")
	check(_action_has_key(&"circuit_activate", KEY_F), "F remains the active circuit trigger")


func _test_editor_open_and_preview() -> void:
	var editor = hud.get_circuit_editor()
	var event := InputEventAction.new()
	event.action = &"circuit_editor"
	event.pressed = true
	editor._unhandled_input(event)
	check(editor.is_open and paused, "C opens the editor and pauses combat")
	check(editor.get_slot_button_count() == 4, "editor exposes exactly four ordered slots")
	check(editor.get_library_button_count() == 9, "independent library exposes all nine first-playable modules")
	check(editor.get_visible_library_button_count() == 8, "library shows eight cyberware entries per page")
	var library_grid: GridContainer = editor.get("_library_grid")
	var icon_count := 0
	for child in library_grid.get_children():
		if child is Button and child.icon != null:
			icon_count += 1
	check(icon_count == 8, "all visible cyberware entries display an icon")
	var slot_buttons: Array = editor.get("_slot_buttons")
	check((slot_buttons[0] as CyberwareCircuitCard).module_texture != null, "installed circuit cards display their cyberware icon")
	check("预计净耗 50" in editor.get_preview_text(), "preview shows expected net energy")
	check("实际执行" in editor.get_preview_text(), "preview explains the actual compiled order")
	var rect: Rect2 = editor.get_panel_rect()
	check(Rect2(Vector2.ZERO, Vector2(640, 360)).encloses(rect), "editor fits inside a 640 by 360 viewport")
	await _capture("cyberware-circuit-editor-640x360.png")
	editor._unhandled_input(event)
	check(not editor.is_open and not paused, "pressing C again closes the editor and releases its pause")


func _test_library_pagination() -> void:
	var counts := {}
	for module_id in CyberwareCircuitPanel.DISPLAY_ORDER:
		counts[module_id] = 1
	player.cyberware.set_circuit_library_counts(counts)
	var editor = hud.get_circuit_editor()
	editor.set_open(true)
	await process_frame
	check(editor.get_library_button_count() == CyberwareCircuitPanel.DISPLAY_ORDER.size(), "full cyberware library keeps every definition")
	check(editor.get_visible_library_button_count() == 8 and editor.get("_library_page_label").text == "第 1 页 共 4 页", "first page shows eight entries and page count")
	var scroll := editor.get("_library_scroll") as ScrollContainer
	var first_page_last := (editor.get("_library_grid") as GridContainer).get_child(7) as Control
	check(first_page_last.get_global_rect().end.y <= scroll.get_global_rect().end.y + 1.0, "all eight library entries fit above the pager at 640 by 360")
	(editor.get("_library_next") as Button).pressed.emit()
	check(editor.get_visible_library_button_count() == 8 and editor.get("_library_page_label").text == "第 2 页 共 4 页", "second page shows the next eight entries")
	(editor.get("_library_next") as Button).pressed.emit()
	(editor.get("_library_next") as Button).pressed.emit()
	check(editor.get_visible_library_button_count() == CyberwareCircuitPanel.DISPLAY_ORDER.size() - 24 and (editor.get("_library_next") as Button).disabled, "last page exposes the remaining entries")
	editor.select_slot(0)
	var final_entry := (editor.get("_library_grid") as GridContainer).get_child(editor.get_visible_library_button_count() - 1) as Button
	final_entry.pressed.emit()
	await process_frame
	check(player.cyberware.circuit.get_slots()[0] == String(CyberwareCircuitPanel.DISPLAY_ORDER.back()) and editor.get("_library_page_label").text == "第 4 页 共 4 页", "last-page cyberware can be installed without losing the page")
	(editor.get("_library_prev") as Button).pressed.emit()
	check(editor.get("_library_page_label").text == "第 3 页 共 4 页", "previous page returns to the middle entries")
	(editor.get("_library_prev") as Button).pressed.emit()
	(editor.get("_library_prev") as Button).pressed.emit()
	editor.set_open(false)
	_configure_sample()
	await process_frame


func _test_library_click_rebuild_is_deferred() -> void:
	var editor = hud.get_circuit_editor()
	editor.set_open(true)
	editor.select_slot(1)
	var library_grid: GridContainer = editor.get("_library_grid")
	var target: Button
	for child in library_grid.get_children():
		if child is Button and "战斗突触感应器" in child.text:
			target = child
			break
	check(target != null, "library click fixture finds the event starter")
	if target != null:
		target.pressed.emit()
		await process_frame
		check(player.cyberware.circuit.get_slots()[1] == "combat_synapse_sensor", "clicking cyberware rebuilds the library without freeing the emitting button")
	editor.set_open(false)


func _test_runtime_pointer_and_snapshot_edit() -> void:
	player.cyberware.circuit.set_energy(100.0)
	player.cyberware.submit_circuit_request(&"active", Vector2.RIGHT, PackedStringArray(["主动"]))
	player.cyberware._physics_process(0.0)
	player.cyberware._physics_process(0.0)
	var hud_state: Dictionary = hud.get_circuit_hud_snapshot()
	check(bool(hud_state.pointer_visible) and int(hud_state.pointer_slot) == 1, "HUD arrow points to the executing slot right of the starter")
	check("主动▶" in String(hud_state.queues), "HUD identifies the active request type")
	check(is_equal_approx(player.cyberware.circuit.current_energy, 82.0) and not (hud.get("_circuit_energy_label") as Label).visible, "HUD energy bar follows starter and first-slot spending")
	check("执行中" in String(hud_state.status) and is_equal_approx(float(hud_state.energy_ratio), 0.82), "HUD exposes execution state and a proportional energy strip")
	var hud_rect: Rect2 = hud_state.rect
	check(Rect2(Vector2.ZERO, Vector2(640, 360)).encloses(hud_rect), "right-bottom circuit HUD stays inside 640 by 360")
	var health_meter: Control = hud.get("_health_meter")
	var energy_rail: Control = hud.get("_circuit_energy_bar").get_node("EnergyRail")
	for hud_scale in [1.0, 1.5]:
		hud.set_hud_scale(hud_scale)
		var energy_rect := energy_rail.get_global_rect()
		var health_rect := health_meter.get_global_rect()
		check(energy_rect.position.y > health_rect.end.y and energy_rect.position.x < health_rect.end.x, "energy rail sits below durability at scale %.1f" % hud_scale)
		var slots_rect: Rect2 = hud.get_circuit_hud_snapshot().rect
		check(slots_rect.position.x > 320 and slots_rect.position.y > 180, "circuit slots remain at the bottom right at scale %.1f" % hud_scale)
	hud.set_hud_scale(1.0)
	await _capture("cyberware-circuit-hud-640x360.png")

	var editor = hud.get_circuit_editor()
	editor.set_open(true)
	editor.select_slot(1)
	check(editor.move_selected(1), "selected slot can move right during combat")
	var slots := player.cyberware.circuit.get_slots()
	check(slots[1] == "explosive_magazine" and slots[2] == "smart_fire", "editor immediately stores the next-round order")
	var active: Dictionary = player.cyberware.get_circuit_runtime_state().active
	var active_steps: Array = (active.get("plan", {}) as Dictionary).get("steps", [])
	check(StringName((active_steps[0] as Dictionary).get("module_id", "")) == &"smart_fire", "in-flight round keeps its original compiled snapshot")
	check(paused, "combat remains paused throughout editing")
	editor.set_open(false)
	check(not paused, "closing after a combat edit resumes the owning pause")
	for _index in 5:
		player.cyberware._physics_process(0.1)
	check(not bool(hud.get_circuit_hud_snapshot().pointer_visible), "HUD arrow clears when the round finishes")


func _test_hud_module_cards_drag_reorder() -> void:
	_configure_sample()
	await process_frame
	var cards: Array = hud.get("_circuit_slot_cards")
	var card_panels: Array = hud.get("_circuit_slot_panels")
	check(cards.size() == CyberwareCircuitState.SLOT_COUNT and not (card_panels[4] as Control).visible, "HUD reserves six positions but shows only unlocked slots")
	var first_rect: Rect2 = (card_panels[0] as Control).get_global_rect()
	var second_rect: Rect2 = (card_panels[1] as Control).get_global_rect()
	check(is_equal_approx(first_rect.end.x, second_rect.position.x), "adjacent graphite cards share an edge without a gap")
	check(((cards[0] as Control).get_node("CardVisual/GraphiteCardFace") as TextureRect).texture != null, "each circuit card has an opaque graphite face")
	var state: Dictionary = hud.get_circuit_hud_snapshot()
	check(int(state.slot_icon_count) == 4, "installed HUD modules use icons instead of text labels: %d" % int(state.slot_icon_count))
	check((cards[0] as Button).text.is_empty(), "HUD module card has no permanent name text")
	check("主动神经开关" in hud._circuit_tooltip(&"active_neural_switch", 0) and "耗能" in hud._circuit_tooltip(&"active_neural_switch", 0), "hover tooltip exposes module identity and energy cost")
	var drag_data: Variant = cards[0]._get_drag_data(Vector2.ZERO)
	var drop_zone = hud.get("_circuit_drop_zone")
	check(drag_data is Dictionary and int(drag_data.source_index) == 0, "module card starts a typed drag operation")
	check(not (cards[0] as Control).get_node("CardVisual").visible, "dragged HUD card leaves its original slot empty")
	var edge_drop := Vector2(8.0 + 2.0 * CyberwareCircuitCard.CARD_SIZE + 2.0, 6.0)
	check(drop_zone.mouse_filter == Control.MOUSE_FILTER_STOP and drop_zone._can_drop_data(edge_drop, drag_data), "HUD row accepts a drop near a slot edge")
	hud._preview_circuit_insert(0, 0)
	check(not hud.get("_circuit_insert_marker").visible and is_zero_approx((cards[1] as Control).get_node("CardVisual").position.x), "returning over the HUD origin clears the displaced card immediately")
	drop_zone._drop_data(edge_drop, drag_data)
	check(drop_zone.mouse_filter == Control.MOUSE_FILTER_IGNORE, "HUD drop zone stops intercepting clicks after release")
	check(not (cards[0] as Control).get_node("CardVisual").visible, "HUD source stays hidden while drag preview closes")
	await process_frame
	await process_frame
	check((cards[0] as Control).get_node("CardVisual").visible, "HUD card returns after drag preview closes")
	var slots := player.cyberware.circuit.get_slots()
	check(slots == PackedStringArray(["smart_fire", "explosive_magazine", "active_neural_switch", "tactical_coprocessor"]), "dropping a module card inserts it at the target trigger position")
	var cancel_data: Variant = cards[0]._get_drag_data(Vector2.ZERO)
	drop_zone._drop_data(Vector2(8.0 + CyberwareCircuitCard.CARD_SIZE * 0.5, 6.0), cancel_data)
	check(not (cards[0] as Control).get_node("CardVisual").visible and player.cyberware.circuit.get_slots() == slots, "cancelled HUD drag stays hidden during return")
	await process_frame
	await process_frame
	check((cards[0] as Control).get_node("CardVisual").visible, "cancelled HUD card reappears after preview clears")


func _test_editor_card_drag_reorder() -> void:
	_configure_sample()
	var editor = hud.get_circuit_editor()
	editor.set_open(true)
	var cards: Array = editor.get("_slot_buttons")
	check(cards.size() == CyberwareCircuitState.SLOT_COUNT and (cards[0] as CyberwareCircuitCard).module_texture != null and not (cards[4] as Control).visible, "editor uses graphical cards and hides locked slots")
	var drag_data: Variant = cards[0]._get_drag_data(Vector2.ZERO)
	var drop_zone = editor.get("_drop_zone")
	check(not (cards[0] as Control).get_node("CardVisual").visible, "dragged editor card leaves its original slot empty")
	var edge_drop := Vector2(8.0 + 2.0 * CyberwareCircuitCard.CARD_SIZE + 2.0, 6.0)
	check(drop_zone.mouse_filter == Control.MOUSE_FILTER_STOP and drop_zone._can_drop_data(edge_drop, drag_data), "editor row accepts a drop near a slot edge")
	check(editor.get("_insert_marker").visible, "editor shows the insertion marker during dragging")
	editor._preview_insert(0, 0)
	check(not editor.get("_insert_marker").visible and is_zero_approx((cards[1] as Control).get_node("CardVisual").position.x), "returning over the editor origin clears the displaced card immediately")
	drop_zone._drop_data(edge_drop, drag_data)
	check(drop_zone.mouse_filter == Control.MOUSE_FILTER_IGNORE, "editor drop zone stops intercepting clicks after release")
	check(not (cards[0] as Control).get_node("CardVisual").visible, "editor source stays hidden while drag preview closes")
	await process_frame
	await process_frame
	check((cards[0] as Control).get_node("CardVisual").visible, "editor card returns after drag preview closes")
	check(player.cyberware.circuit.get_slots() == PackedStringArray(["smart_fire", "explosive_magazine", "active_neural_switch", "tactical_coprocessor"]), "editor insertion matches the combat HUD")
	check(not editor.get("_insert_marker").visible, "editor clears the insertion marker after dropping")
	var cancel_data: Variant = cards[0]._get_drag_data(Vector2.ZERO)
	drop_zone._drop_data(Vector2(8.0 + CyberwareCircuitCard.CARD_SIZE * 0.5, 6.0), cancel_data)
	check(not (cards[0] as Control).get_node("CardVisual").visible, "cancelled editor drag stays hidden during return")
	await process_frame
	await process_frame
	check((cards[0] as Control).get_node("CardVisual").visible, "cancelled editor card reappears after preview clears")
	editor.set_open(false)


func _test_auto_compact_reflow() -> void:
	_configure_sample()
	await process_frame
	var editor = hud.get_circuit_editor()
	editor.select_slot(1)
	check(editor.remove_selected(), "removing a module succeeds")
	check(player.cyberware.circuit.get_slots() == PackedStringArray(["active_neural_switch", "explosive_magazine", "tactical_coprocessor", ""]), "later modules fill the vacant slot")
	check((hud.get("_circuit_reflow") as Array).size() == 2, "two shifted modules receive a spring transition")
	for index in 120:
		hud._advance_circuit_reflow(1.0 / 60.0)
	check((hud.get("_circuit_reflow") as Array).is_empty(), "reflow settles after its collision response")


func _test_drag_over_origin_clears_reflow_ghosts() -> void:
	_configure_sample()
	check(hud._reorder_circuit_modules(0, 2), "reorder starts an animated reflow")
	check(not (hud.get("_circuit_reflow") as Array).is_empty(), "reflow ghosts exist before the next drag")
	var cards: Array = hud.get("_circuit_slot_cards")
	cards[0]._get_drag_data(Vector2.ZERO)
	check((hud.get("_circuit_reflow") as Array).is_empty(), "new drag clears old reflow ghosts")
	var visible_ghosts := 0
	for ghost in (hud.get("_circuit_reflow_layer") as Control).get_children():
		if (ghost as Control).visible:
			visible_ghosts += 1
	check(visible_ghosts == 0 and not (cards[0] as Control).get_node("CardVisual").visible, "dragging over its origin shows only the mouse preview")
	hud._reset_circuit_drag_preview()
	await process_frame
	await process_frame
	check((cards[0] as Control).get_node("CardVisual").visible, "card returns after cancelling over its origin")


func _test_five_slot_drag_alignment() -> void:
	_configure_sample()
	check(player.cyberware.circuit.set_slot_capacity(5), "fifth circuit slot unlocks")
	player.cyberware.circuit_changed.emit(player.cyberware.export_circuit_state())
	var configured := player.cyberware.set_circuit_slots(PackedStringArray(["active_neural_switch", "smart_fire", "explosive_magazine", "tactical_coprocessor", "combat_synapse_sensor"]))
	check(bool(configured.get("ok", false)), "five module circuit configures")
	await process_frame
	var cards: Array = hud.get("_circuit_slot_cards")
	var panels: Array = hud.get("_circuit_slot_panels")
	var drag_data: Variant = cards[0]._get_drag_data(Vector2.ZERO)
	check(cards[4]._can_drop_data(Vector2.ZERO, drag_data), "fifth slot accepts drag insertion")
	cards[4]._drop_data(Vector2.ZERO, drag_data)
	await process_frame
	check(player.cyberware.circuit.get_slots() == PackedStringArray(["smart_fire", "explosive_magazine", "tactical_coprocessor", "combat_synapse_sensor", "active_neural_switch"]), "five slot drag preserves order")
	for index in 180:
		hud._advance_circuit_reflow(1.0 / 60.0)
	check((hud.get("_circuit_reflow") as Array).is_empty(), "five slot reflow settles")
	for index in 4:
		check(is_equal_approx((panels[index] as Control).get_global_rect().end.x, (panels[index + 1] as Control).get_global_rect().position.x), "five slot cards remain edge aligned")
	var editor = hud.get_circuit_editor()
	editor.set_open(true)
	var editor_cards: Array = editor.get("_slot_buttons")
	var editor_drag: Variant = editor_cards[4]._get_drag_data(Vector2.ZERO)
	check(editor_cards[0]._can_drop_data(Vector2.ZERO, editor_drag), "five slot editor accepts reverse drag")
	editor_cards[0]._drop_data(Vector2.ZERO, editor_drag)
	check(player.cyberware.circuit.get_slots() == PackedStringArray(["active_neural_switch", "smart_fire", "explosive_magazine", "tactical_coprocessor", "combat_synapse_sensor"]), "five slot editor returns cards to their original order")
	editor.set_open(false)
	check(player.cyberware.circuit.set_slot_capacity(6), "sixth circuit slot unlocks")
	var six_slots := PackedStringArray(["active_neural_switch", "smart_fire", "explosive_magazine", "tactical_coprocessor", "combat_synapse_sensor", "rhythm_pulser"])
	check(bool(player.cyberware.set_circuit_slots(six_slots).get("ok", false)), "six module circuit configures")
	await process_frame
	var six_drag: Variant = cards[0]._get_drag_data(Vector2.ZERO)
	cards[5]._drop_data(Vector2.ZERO, six_drag)
	for index in 180:
		hud._advance_circuit_reflow(1.0 / 60.0)
	check((hud.get("_circuit_reflow") as Array).is_empty() and player.cyberware.circuit.get_slots()[5] == "active_neural_switch", "six slot drag settles on its final position")


func _test_right_click_unloads_and_expanded_slots() -> void:
	_configure_sample()
	player.cyberware.circuit.set_slot_capacity(4)
	player.cyberware.circuit_changed.emit(player.cyberware.export_circuit_state())
	var cards: Array = hud.get("_circuit_slot_cards")
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	(cards[1] as CyberwareCircuitCard)._gui_input(right_click)
	check(player.cyberware.circuit.get_slots() == PackedStringArray(["active_neural_switch", "explosive_magazine", "tactical_coprocessor", ""]), "right click unloads the card and compacts the circuit")
	player.cyberware.circuit.set_slot_capacity(6)
	player.cyberware.circuit.expand_capacity()
	player.cyberware.circuit.expand_capacity()
	player.cyberware.circuit_changed.emit(player.cyberware.export_circuit_state())
	check(hud.get_circuit_editor().get_slot_button_count() == 6 and (hud.get("_circuit_slot_panels")[5] as Control).visible, "fifth and sixth slots appear after expansion")


func _action_has_key(action: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event.keycode == keycode or event.physical_keycode == keycode):
			return true
	return false


func _capture(file_name: String) -> void:
	if capture_directory.is_empty():
		return
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var path := capture_directory.path_join(file_name)
	check(not image.is_empty() and image.save_png(path) == OK, "capture saved: " + file_name)
