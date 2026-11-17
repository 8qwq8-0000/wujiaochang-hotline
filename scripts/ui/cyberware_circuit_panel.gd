class_name CyberwareCircuitPanel
extends CanvasLayer

const CIRCUIT_CARD := preload("res://scripts/ui/cyberware_circuit_card.gd")
const CIRCUIT_DROP_ZONE := preload("res://scripts/ui/cyberware_circuit_drop_zone.gd")
const CIRCUIT_RAIL := preload("res://assets/art/ui/os_hud/energy_bus_backbone_v1.png")

signal open_changed(open: bool)

const DISPLAY_ORDER := [
	&"active_neural_switch",
	&"combat_synapse_sensor",
	&"combat_synapse_sensor_dash",
	&"combat_synapse_sensor_guard",
	&"combat_synapse_sensor_hit",
	&"combat_synapse_sensor_kill",
	&"rhythm_pulser",
	&"smart_fire",
	&"explosive_magazine",
	&"tactical_coprocessor",
	&"kill_energy_sink",
	&"guard_coprocessor",
	&"instruction_mirror_synapse",
	&"optical_intruder",
	&"shock_pulser",
	&"micro_rotor_reflex_bundle",
	&"momentum_recovery_tendon",
	&"ballistic_takeover_protocol",
	&"arc_ballistic_cortex",
	&"axon_recycler",
	&"omnidirectional_reflection_matrix",
	&"trajectory_echo_processor",
	&"inertial_inversion_vertebra",
	&"predatory_vestibular_ring",
	&"calamity_flame",
	&"relay_starter",
	&"world",
	&"ballistic_splicer",
	&"fission_core",
	&"penetration_booster",
]
const MODULE_ICONS := {
	&"active_neural_switch": preload("res://assets/art/items/equipment_v1/active_neural_switch_64.png"),
	&"combat_synapse_sensor": preload("res://assets/art/items/equipment_v1/combat_synapse_sensor_64.png"),
	&"rhythm_pulser": preload("res://assets/art/items/equipment_v1/rhythm_pulser_64.png"),
	&"smart_fire": preload("res://assets/art/items/equipment_v1/smart_fire_64.png"),
	&"explosive_magazine": preload("res://assets/art/items/equipment_v1/explosive_magazine_64.png"),
	&"tactical_coprocessor": preload("res://assets/art/items/equipment_v1/tactical_coprocessor_64.png"),
	&"kill_energy_sink": preload("res://assets/art/items/equipment_v1/kill_heat_sink_64.png"),
	&"guard_coprocessor": preload("res://assets/art/items/equipment_v1/guard_coprocessor_64.png"),
	&"instruction_mirror_synapse": preload("res://assets/art/items/equipment_v1/instruction_mirror_synapse_64.png"),
	&"optical_intruder": preload("res://assets/art/items/equipment_v1/optical_intruder_64.png"),
	&"shock_pulser": preload("res://assets/art/items/equipment_v1/heat_threshold_pulser_64.png"),
	&"micro_rotor_reflex_bundle": preload("res://assets/art/items/equipment_v1/micro_rotor_reflex_bundle_64.png"),
	&"momentum_recovery_tendon": preload("res://assets/art/items/equipment_v1/momentum_recovery_tendon_64.png"),
	&"ballistic_takeover_protocol": preload("res://assets/art/items/equipment_v1/ballistic_takeover_protocol_64.png"),
	&"arc_ballistic_cortex": preload("res://assets/art/items/equipment_v1/arc_ballistic_cortex_64.png"),
	&"axon_recycler": preload("res://assets/art/items/equipment_v1/axon_recycler_64.png"),
	&"omnidirectional_reflection_matrix": preload("res://assets/art/items/equipment_v1/guard_coprocessor_64.png"),
	&"trajectory_echo_processor": preload("res://assets/art/items/equipment_v1/trajectory_echo_processor_64.png"),
	&"inertial_inversion_vertebra": preload("res://assets/art/items/equipment_v1/inertial_inversion_vertebra_64.png"),
	&"predatory_vestibular_ring": preload("res://assets/art/items/equipment_v1/predatory_vestibular_ring_64.png"),
	&"calamity_flame": preload("res://assets/art/items/equipment_v1/calamity_flame_64.png"),
	&"relay_starter": preload("res://assets/art/items/equipment_v1/relay_starter_64.png"),
	&"world": preload("res://assets/art/items/equipment_v1/world_64.png"),
	&"ballistic_splicer": preload("res://assets/art/items/equipment_v1/ballistic_splicer_64.png"),
	&"fission_core": preload("res://assets/art/items/equipment_v1/fission_core_64.png"),
	&"penetration_booster": preload("res://assets/art/items/equipment_v1/penetration_booster_64.png"),
}
const MODULE_ICON_SIZE := 24
const LIBRARY_PAGE_SIZE := 8
const OS_FRAME := preload("res://assets/art/ui/os_hud/shared_os_frame_v2.png")

var player: PlayerController
var is_open := false
var _owns_pause := false
var _selected_slot := -1
var _overlay: Control
var _panel: Panel
var _library_grid: GridContainer
var _library_scroll: ScrollContainer
var _library_pager: HBoxContainer
var _library_prev: Button
var _library_next: Button
var _library_page_label: Label
var _library_page := 0
var _library_page_count := 1
var _library_entry_count := 0
var _category_filter: OptionButton
var _tag_filter: LineEdit
var _slot_buttons: Array[CyberwareCircuitCard] = []
var _slot_row: HBoxContainer
var _drop_zone: Control
var _insert_marker: ColorRect
var _drag_source := -1
var _drag_target := -1
var _tooltip_panel: PanelContainer
var _tooltip_label: Label
var _preview: Label
var _message: Label
var _tutorial_hint: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 80
	_build_ui()
	get_viewport().size_changed.connect(_fit_panel)
	_fit_panel()
	hide()
	set_process(true)


func _process(_delta: float) -> void:
	if _drag_source >= 0 and not get_viewport().gui_is_dragging():
		_reset_drag_preview()
	elif _drag_source >= 0 and _slot_row != null:
		var hover_index := floori(_slot_row.get_local_mouse_position().x / CyberwareCircuitCard.CARD_SIZE)
		if hover_index >= 0 and hover_index < get_slot_button_count():
			_preview_insert(_drag_source, hover_index)


func bind_player(value: PlayerController) -> void:
	if player == value:
		return
	if is_instance_valid(player):
		if player.cyberware.circuit_changed.is_connected(_refresh):
			player.cyberware.circuit_changed.disconnect(_refresh)
		if player.health.died.is_connected(_on_player_died):
			player.health.died.disconnect(_on_player_died)
	player = value
	_selected_slot = -1
	if is_instance_valid(player):
		player.cyberware.circuit_changed.connect(_refresh)
		player.health.died.connect(_on_player_died)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not InputMap.has_action(&"circuit_editor"):
		return
	var editor_pressed := event.is_action_pressed(&"circuit_editor")
	var cancel_pressed := is_open and InputMap.has_action(&"pause") and event.is_action_pressed(&"pause")
	if not editor_pressed and not cancel_pressed:
		return
	if is_open:
		set_open(false)
	elif editor_pressed and not get_tree().paused and _can_open():
		set_open(true)
	else:
		return
	get_viewport().set_input_as_handled()


func set_open(value: bool) -> void:
	value = value and _can_open()
	if value == is_open:
		return
	is_open = value
	if is_open:
		_owns_pause = not get_tree().paused
		get_tree().paused = true
		_selected_slot = -1
		_refresh()
		show()
	else:
		if _drag_source >= 0:
			_reset_drag_preview()
		hide()
		_release_pause()
	open_changed.emit(is_open)


func select_slot(index: int) -> void:
	_selected_slot = index if index >= 0 and is_instance_valid(player) and index < player.cyberware.circuit.slot_capacity else -1
	_refresh_slots()


func set_tutorial_hint(text: String) -> void:
	if _tutorial_hint.text != text:
		_tutorial_hint.text = text
		_tutorial_hint.visible = not text.is_empty()


func move_selected(offset: int) -> bool:
	if not is_instance_valid(player) or _selected_slot < 0:
		return false
	var target := _selected_slot + offset
	if target < 0 or target >= player.cyberware.circuit.slot_capacity:
		return false
	var slots := player.cyberware.circuit.get_slots()
	if StringName(slots[target]).is_empty():
		return false
	var held := slots[_selected_slot]
	slots[_selected_slot] = slots[target]
	slots[target] = held
	var result := player.cyberware.set_circuit_slots(slots)
	if not bool(result.get("ok", false)):
		_show_errors(result)
		return false
	_selected_slot = target
	_message.text = "已调整执行顺序；当前执行轮仍使用旧快照。"
	_refresh()
	return true


func remove_selected() -> bool:
	if not is_instance_valid(player) or _selected_slot < 0:
		return false
	var slots := player.cyberware.circuit.get_slots()
	if StringName(slots[_selected_slot]).is_empty():
		return false
	slots[_selected_slot] = ""
	slots = _compact_slots(slots)
	var result := player.cyberware.set_circuit_slots(slots)
	if not bool(result.get("ok", false)):
		_show_errors(result)
		return false
	_selected_slot = -1
	_message.text = "已卸下，后续槽位自动补位。"
	_refresh()
	return true


func clear_slots() -> void:
	if not is_instance_valid(player):
		return
	player.cyberware.set_circuit_slots(PackedStringArray())
	_selected_slot = -1
	_message.text = "回路已清空。"
	_refresh()


func install_module(module_id: StringName) -> bool:
	if not is_instance_valid(player):
		return false
	var circuit: CyberwareCircuitState = player.cyberware.circuit
	var slots := circuit.get_slots()
	var target := -1
	for index in slots.size():
		if StringName(slots[index]).is_empty():
			target = index
			break
	if target < 0:
		target = _selected_slot
	if target < 0:
		_message.text = "%d 个槽位已满；先选择要替换的槽位。" % circuit.slot_capacity
		return false
	if StringName(slots[target]) != module_id and circuit.get_available_count(module_id) <= 0:
		_message.text = "该义体没有可用副本。"
		return false
	slots[target] = String(module_id)
	var compact_index := 0
	for index in target:
		if not StringName(slots[index]).is_empty():
			compact_index += 1
	slots = _compact_slots(slots)
	target = compact_index
	var result := player.cyberware.set_circuit_slots(slots)
	if not bool(result.get("ok", false)):
		_show_errors(result)
		return false
	_selected_slot = target
	_message.text = "已写入槽位 %d；下次启动按新顺序执行。" % (target + 1)
	_refresh()
	return true


func _compact_slots(slots: PackedStringArray) -> PackedStringArray:
	var compact := PackedStringArray()
	for module_id in slots:
		if not module_id.is_empty():
			compact.append(module_id)
	while compact.size() < player.cyberware.circuit.slot_capacity:
		compact.append("")
	return compact


func get_panel_rect() -> Rect2:
	return _panel.get_global_rect() if _panel != null else Rect2()


func get_preview_text() -> String:
	return _preview.text if _preview != null else ""


func get_selected_slot() -> int:
	return _selected_slot


func get_slot_button_count() -> int:
	return player.cyberware.circuit.slot_capacity if is_instance_valid(player) else CyberwareCircuitState.INITIAL_SLOT_COUNT


func get_library_button_count() -> int:
	return _library_entry_count


func get_visible_library_button_count() -> int:
	return _library_grid.get_child_count() if _library_grid != null else 0


func _can_open() -> bool:
	return is_instance_valid(player) and not player.health.is_dead()


func _release_pause() -> void:
	if _owns_pause:
		get_tree().paused = false
		_owns_pause = false


func _on_player_died(_packet: DamagePacket) -> void:
	set_open(false)


func _build_ui() -> void:
	_overlay = Control.new()
	_overlay.name = "CircuitEditorOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.theme = CyberUITheme.create_os_theme()
	add_child(_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.035, 0.045, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(shade)
	_panel = Panel.new()
	_panel.name = "CircuitEditorPanel"
	_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_overlay.add_child(_panel)
	var frame := TextureRect.new()
	frame.name = "FrameArt"
	frame.texture = OS_FRAME
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(frame)
	var margin := MarginContainer.new()
	margin.name = "ContentMargin"
	for side in [&"left", &"right"]:
		margin.add_theme_constant_override("margin_" + String(side), 24)
	for side in [&"top", &"bottom"]:
		margin.add_theme_constant_override("margin_" + String(side), 32)
	_panel.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "义体序列"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 14)
	header.add_child(title)
	_tutorial_hint = Label.new()
	_tutorial_hint.add_theme_font_size_override("font_size", 11)
	_tutorial_hint.add_theme_color_override("font_color", CyberUITheme.WARNING)
	header.add_child(_tutorial_hint)
	_tutorial_hint.hide()
	var close := Button.new()
	close.text = "关闭"
	close.custom_minimum_size = Vector2(70, 24)
	close.pressed.connect(set_open.bind(false))
	header.add_child(close)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	column.add_child(body)
	var library_column := VBoxContainer.new()
	library_column.custom_minimum_size.x = 250
	library_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(library_column)
	var library_header := HBoxContainer.new()
	library_header.add_theme_constant_override("separation", 3)
	library_column.add_child(library_header)
	var library_title := Label.new()
	library_title.text = "义体库"
	library_title.add_theme_color_override("font_color", Color("e7ac62"))
	library_header.add_child(library_title)
	_category_filter = OptionButton.new()
	_category_filter.custom_minimum_size.x = 82
	for label in ["全部", "启动", "修正", "执行", "重构"]:
		_category_filter.add_item(label)
	_category_filter.item_selected.connect(func(_index: int) -> void:
		_library_page = 0
		_refresh_library()
	)
	library_header.add_child(_category_filter)
	_tag_filter = LineEdit.new()
	_tag_filter.placeholder_text = "功能词"
	_tag_filter.custom_minimum_size.x = 70
	_tag_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tag_filter.text_changed.connect(func(_value: String) -> void:
		_library_page = 0
		_refresh_library()
	)
	library_header.add_child(_tag_filter)
	_library_scroll = ScrollContainer.new()
	_library_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_library_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	library_column.add_child(_library_scroll)
	_library_grid = GridContainer.new()
	_library_grid.columns = 2
	_library_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_library_grid.add_theme_constant_override("h_separation", 5)
	_library_grid.add_theme_constant_override("v_separation", 5)
	_library_scroll.add_child(_library_grid)
	_library_pager = HBoxContainer.new()
	_library_pager.add_theme_constant_override("separation", 4)
	library_column.add_child(_library_pager)
	_library_prev = Button.new()
	_library_prev.text = "上一页"
	_library_prev.custom_minimum_size.x = 65
	_library_prev.pressed.connect(_change_library_page.bind(-1))
	_library_pager.add_child(_library_prev)
	_library_page_label = Label.new()
	_library_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_library_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_library_page_label.add_theme_color_override("font_color", Color("ada9a0"))
	_library_pager.add_child(_library_page_label)
	_library_next = Button.new()
	_library_next.text = "下一页"
	_library_next.custom_minimum_size.x = 65
	_library_next.pressed.connect(_change_library_page.bind(1))
	_library_pager.add_child(_library_next)
	var circuit_column := VBoxContainer.new()
	circuit_column.custom_minimum_size.x = 294
	circuit_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(circuit_column)
	var circuit_title := Label.new()
	circuit_title.text = "执行顺序"
	circuit_title.add_theme_color_override("font_color", Color("e7ac62"))
	circuit_column.add_child(circuit_title)
	var slot_host := Control.new()
	slot_host.name = "CircuitCardRail"
	slot_host.custom_minimum_size = Vector2(CyberwareCircuitCard.CARD_SIZE * CyberwareCircuitState.SLOT_COUNT, 72)
	circuit_column.add_child(slot_host)
	var rail_crop := AtlasTexture.new()
	rail_crop.atlas = CIRCUIT_RAIL
	rail_crop.region = Rect2(0, 260, 2172, 160)
	var rail := TextureRect.new()
	rail.name = "EnergyRail"
	rail.texture = rail_crop
	rail.position = Vector2(-8, 45)
	rail.size = Vector2(CyberwareCircuitCard.CARD_SIZE * CyberwareCircuitState.SLOT_COUNT + 16, 20)
	rail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rail.stretch_mode = TextureRect.STRETCH_SCALE
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_host.add_child(rail)
	rail.size = Vector2(CyberwareCircuitCard.CARD_SIZE * CyberwareCircuitState.SLOT_COUNT + 16, 20)
	_slot_row = HBoxContainer.new()
	_slot_row.position = Vector2.ZERO
	_slot_row.size = Vector2(CyberwareCircuitCard.CARD_SIZE * CyberwareCircuitState.SLOT_COUNT, CyberwareCircuitCard.CARD_SIZE)
	_slot_row.add_theme_constant_override("separation", 0)
	slot_host.add_child(_slot_row)
	for index in CyberwareCircuitState.SLOT_COUNT:
		var slot := CIRCUIT_CARD.new() as CyberwareCircuitCard
		slot.name = "CircuitModuleCard%d" % (index + 1)
		slot.slot_index = index
		slot.circuit_owner_id = get_instance_id()
		slot.drop_requested = _reorder_slots
		slot.hover_requested = _preview_insert
		slot.drag_started = _start_drag
		slot.right_click_requested = _remove_slot
		slot.pressed.connect(select_slot.bind(index))
		slot.mouse_entered.connect(_show_slot_tooltip.bind(index))
		slot.mouse_exited.connect(_hide_slot_tooltip)
		_slot_row.add_child(slot)
		_slot_buttons.append(slot)
	_insert_marker = ColorRect.new()
	_insert_marker.name = "InsertMarker"
	_insert_marker.color = Color("e7ac62")
	_insert_marker.size = Vector2(2, 44)
	_insert_marker.position.y = 4
	_insert_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_insert_marker.hide()
	slot_host.add_child(_insert_marker)
	_drop_zone = CIRCUIT_DROP_ZONE.new()
	_drop_zone.name = "CircuitDropZone"
	_drop_zone.position = Vector2(-8, -6)
	_drop_zone.size = Vector2(CyberwareCircuitCard.CARD_SIZE * CyberwareCircuitState.INITIAL_SLOT_COUNT + 16, CyberwareCircuitCard.CARD_SIZE + 12)
	_drop_zone.set("circuit_owner_id", get_instance_id())
	_drop_zone.set("preview_requested", _preview_insert)
	_drop_zone.set("drop_requested", _reorder_slots)
	_drop_zone.set("cancel_requested", _reset_drag_preview)
	slot_host.add_child(_drop_zone)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	circuit_column.add_child(actions)
	_add_action(actions, "卸下", remove_selected)
	_add_action(actions, "清空", clear_slots)
	_preview = Label.new()
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview.custom_minimum_size.y = 48
	_preview.add_theme_color_override("font_color", Color("ada9a0"))
	circuit_column.add_child(_preview)
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.max_lines_visible = 2
	_message.custom_minimum_size.y = 22
	_message.add_theme_color_override("font_color", Color("e7ac62"))
	column.add_child(_message)
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.name = "CircuitEffectTooltip"
	_tooltip_panel.custom_minimum_size.x = 220
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.add_theme_stylebox_override("panel", CyberUITheme.create_box(Color("252b30"), Color("8f7658")))
	_overlay.add_child(_tooltip_panel)
	_tooltip_label = Label.new()
	_tooltip_label.custom_minimum_size.x = 200
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_label.add_theme_font_size_override("font_size", 10)
	_tooltip_label.add_theme_color_override("font_color", Color("e6e1d8"))
	_tooltip_panel.add_child(_tooltip_label)
	_tooltip_panel.hide()


func _add_action(parent: Control, text: String, callable: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callable)
	parent.add_child(button)


func _fit_panel() -> void:
	if _panel == null:
		return
	var safe := get_viewport().get_visible_rect().grow(-6.0)
	var desired_width := maxf(620.0, 48.0 + 250.0 + 10.0 + CyberwareCircuitCard.CARD_SIZE * get_slot_button_count() + 12.0)
	_panel.size = Vector2(minf(desired_width, safe.size.x), minf(348.0, safe.size.y))
	_panel.position = safe.get_center() - _panel.size * 0.5


func _refresh(_state: Dictionary = {}) -> void:
	_refresh_slot_capacity()
	_refresh_library()
	_refresh_slots()
	_refresh_preview()


func _refresh_slot_capacity() -> void:
	if _slot_row == null:
		return
	var capacity := get_slot_button_count()
	var width := CyberwareCircuitCard.CARD_SIZE * capacity
	_slot_row.size.x = width
	_drop_zone.size.x = width + 16.0
	_drop_zone.set("slot_count", capacity)
	var host := _slot_row.get_parent() as Control
	host.custom_minimum_size.x = width
	var rail := host.get_node("EnergyRail") as TextureRect
	rail.size.x = width + 16.0
	for index in _slot_buttons.size():
		_slot_buttons[index].visible = index < capacity
	if _selected_slot >= capacity:
		_selected_slot = -1
	_fit_panel()


func _refresh_library() -> void:
	if _library_grid == null:
		return
	for child in _library_grid.get_children():
		_library_grid.remove_child(child)
		child.queue_free()
	if not is_instance_valid(player):
		_library_entry_count = 0
		_library_page = 0
		_library_page_count = 1
		_update_library_pager()
		return
	var counts := player.cyberware.circuit.get_library_counts()
	var ordered: Array[StringName] = []
	for module_id in DISPLAY_ORDER:
		if counts.has(module_id) or counts.has(String(module_id)):
			ordered.append(module_id)
	for raw_id in counts:
		var module_id := StringName(str(raw_id))
		if module_id not in ordered:
			ordered.append(module_id)
	var entries: Array[StringName] = []
	for module_id in ordered:
		var data := _data(module_id)
		if data == null:
			continue
		if _category_filter.selected > 0 and data.circuit_kind != _category_filter.selected - 1:
			continue
		if not _tag_filter.text.strip_edges().is_empty():
			var query := _tag_filter.text.strip_edges()
			var matches := data.display_name.contains(query)
			for tag in data.circuit_tags:
				matches = matches or tag.contains(query)
			if not matches:
				continue
		entries.append(module_id)
	_library_entry_count = entries.size()
	_library_page_count = maxi(1, ceili(float(_library_entry_count) / LIBRARY_PAGE_SIZE))
	_library_page = clampi(_library_page, 0, _library_page_count - 1)
	_update_library_pager()
	var first_index := _library_page * LIBRARY_PAGE_SIZE
	for index in range(first_index, mini(first_index + LIBRARY_PAGE_SIZE, entries.size())):
		var module_id := entries[index]
		var data := _data(module_id)
		var available := player.cyberware.circuit.get_available_count(module_id)
		var button := Button.new()
		button.text = "%s %s\n%s 可用 %d" % [_kind_prefix(data.circuit_kind), data.display_name, ["启动", "标准", "军规", "禁忌"][clampi(data.grade, 0, 3)], available]
		button.icon = MODULE_ICONS.get(module_id, MODULE_ICONS[&"combat_synapse_sensor"])
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", MODULE_ICON_SIZE)
		button.tooltip_text = "耗能 %.0f\n%s" % [data.circuit_energy_cost, data.description]
		button.custom_minimum_size = Vector2(118, 38)
		button.disabled = available <= 0 and not _selected_holds(module_id)
		button.pressed.connect(install_module.bind(module_id))
		_library_grid.add_child(button)
	_library_scroll.scroll_vertical = 0


func _change_library_page(offset: int) -> void:
	var next_page := clampi(_library_page + offset, 0, _library_page_count - 1)
	if next_page == _library_page:
		return
	_library_page = next_page
	_refresh_library()


func _update_library_pager() -> void:
	_library_pager.visible = _library_page_count > 1
	_library_page_label.text = "第 %d 页 共 %d 页" % [_library_page + 1, _library_page_count]
	_library_prev.disabled = _library_page <= 0
	_library_next.disabled = _library_page >= _library_page_count - 1


func _refresh_slots() -> void:
	if _slot_buttons.is_empty():
		return
	var slots := player.cyberware.circuit.get_slots() if is_instance_valid(player) else PackedStringArray()
	for index in _slot_buttons.size():
		var button := _slot_buttons[index]
		var module_id := StringName(slots[index]) if index < slots.size() else StringName()
		var data := _data(module_id) if not module_id.is_empty() else null
		var texture: Texture2D = null if module_id.is_empty() else MODULE_ICONS.get(module_id, MODULE_ICONS[&"combat_synapse_sensor"])
		button.set_module(module_id, texture, data.circuit_kind if data != null else -1)
		button.set_selected(index == _selected_slot)


func _remove_slot(index: int) -> void:
	select_slot(index)
	remove_selected()


func _reorder_slots(source_index: int, target_index: int) -> bool:
	_reset_drag_preview()
	if not is_instance_valid(player):
		return false
	var slots := player.cyberware.circuit.get_slots()
	if source_index < 0 or source_index >= slots.size() or target_index < 0 or target_index >= slots.size() or source_index == target_index or slots[source_index].is_empty():
		return false
	var ordered := Array(slots)
	var moving: String = ordered.pop_at(source_index)
	ordered.insert(target_index, moving)
	ordered = ordered.filter(func(id: String) -> bool: return not id.is_empty())
	while ordered.size() < player.cyberware.circuit.slot_capacity:
		ordered.append("")
	var result := player.cyberware.set_circuit_slots(PackedStringArray(ordered))
	if not bool(result.get("ok", false)):
		_show_errors(result)
		return false
	_selected_slot = mini(target_index, player.cyberware.circuit.slot_capacity - 1)
	_slot_buttons[_selected_slot].settle()
	_message.text = "顺序已更新，下轮生效。"
	_refresh()
	return true


func _start_drag(source_index: int) -> void:
	for button in _slot_buttons:
		button.reset_visual_offset()
	_drag_source = source_index
	_drag_target = source_index
	_hide_slot_tooltip()
	_slot_buttons[source_index].set_drag_origin_hidden(true)
	_drop_zone.mouse_filter = Control.MOUSE_FILTER_STOP


func _preview_insert(source_index: int, target_index: int) -> void:
	if source_index != _drag_source or target_index == _drag_target:
		return
	_drag_target = target_index
	if target_index == source_index:
		_insert_marker.hide()
		for button in _slot_buttons:
			button.reset_visual_offset()
		return
	for index in _slot_buttons.size():
		var shift := 0.0
		if source_index < target_index and index > source_index and index <= target_index:
			shift = -CyberwareCircuitCard.CARD_SIZE
		elif source_index > target_index and index >= target_index and index < source_index:
			shift = CyberwareCircuitCard.CARD_SIZE
		_slot_buttons[index].set_visual_offset(shift)
	_insert_marker.position.x = target_index * CyberwareCircuitCard.CARD_SIZE + 1.0
	_insert_marker.show()


func _reset_drag_preview() -> void:
	if _drag_source < 0:
		return
	var source_index := _drag_source
	_drag_source = -1
	_drag_target = -1
	_drop_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_insert_marker.hide()
	for button in _slot_buttons:
		button.set_visual_offset(0.0)
		button.modulate.a = 1.0 if not button.module_id.is_empty() else 0.6
	_slot_buttons[source_index].restore_drag_origin_after_preview()


func _show_slot_tooltip(slot_index: int) -> void:
	if _drag_source >= 0 or slot_index < 0 or slot_index >= _slot_buttons.size():
		return
	var button := _slot_buttons[slot_index]
	if button.module_id.is_empty():
		return
	_tooltip_label.text = _slot_tooltip(button.module_id, slot_index)
	_tooltip_panel.reset_size()
	_tooltip_panel.show()
	var rect := button.get_global_rect()
	var viewport_size := get_viewport().get_visible_rect().size
	var tooltip_size := _tooltip_panel.size
	_tooltip_panel.global_position = Vector2(
		clampf(rect.get_center().x - tooltip_size.x * 0.5, 8.0, maxf(8.0, viewport_size.x - tooltip_size.x - 8.0)),
		clampf(rect.position.y - tooltip_size.y - 8.0, 8.0, maxf(8.0, viewport_size.y - tooltip_size.y - 8.0))
	)


func _hide_slot_tooltip() -> void:
	if is_instance_valid(_tooltip_panel):
		_tooltip_panel.hide()


func _slot_tooltip(module_id: StringName, slot_index: int) -> String:
	var data := _data(module_id)
	if data == null:
		return String(module_id)
	var kind_names := ["启动器", "修正器", "执行器", "重构器"]
	var detail := data.description
	if module_id == &"world" and is_instance_valid(player):
		detail += "\n本层剩余 %d/10 次" % player.cyberware.world_uses_remaining()
	var plan := player.cyberware.compile_circuit_plan() if is_instance_valid(player) else {}
	for raw_step in plan.get("steps", []):
		var step: Dictionary = raw_step
		if int(step.get("slot", -1)) == slot_index and StringName(step.get("effect_id", module_id)) != module_id:
			var effect_data := _data(StringName(step.get("effect_id", module_id)))
			if effect_data != null:
				detail = "当前复制：%s\n%s" % [effect_data.display_name, effect_data.description]
			break
	return "%s · %s · %s\n耗能 %.0f\n%s" % [data.display_name, kind_names[clampi(data.circuit_kind, 0, 3)], ["启动", "标准", "军规", "禁忌"][clampi(data.grade, 0, 3)], data.circuit_energy_cost, detail]


func _refresh_preview() -> void:
	if _preview == null:
		return
	if not is_instance_valid(player):
		_preview.text = "未连接玩家。"
		return
	var plan := player.cyberware.compile_circuit_plan()
	if not bool(plan.get("ok", false)):
		_preview.text = "无法编译：%s" % "；".join(PackedStringArray(plan.get("errors", [])))
		return
	var order := PackedStringArray()
	for raw_step in plan.get("steps", []):
		var step: Dictionary = raw_step
		var module_id := StringName(step.get("module_id", ""))
		var effect_id := StringName(step.get("effect_id", module_id))
		var label := _display_name(module_id)
		if effect_id != module_id:
			label += "⇒" + _display_name(effect_id)
		order.append(label)
	var stop_slot := int(plan.get("projected_stop_slot", -1))
	_preview.text = "实际执行：%s\n总耗 %.0f  回能 %.0f  预计净耗 %.0f（命中/击杀等条件效果未计入）\n预计中止 %s  能量 %.0f/%.0f" % [
		" → ".join(order),
		float(plan.get("gross_energy", 0.0)),
		float(plan.get("fixed_refund", 0.0)),
		float(plan.get("net_energy", 0.0)),
		"第 %d 槽" % (stop_slot + 1) if stop_slot >= 0 else "无",
		player.cyberware.circuit.current_energy,
		player.cyberware.circuit.maximum_energy,
	]


func _selected_holds(module_id: StringName) -> bool:
	if not is_instance_valid(player) or _selected_slot < 0:
		return false
	return StringName(player.cyberware.circuit.get_slots()[_selected_slot]) == module_id


func _show_errors(result: Dictionary) -> void:
	_message.text = "；".join(PackedStringArray(result.get("errors", ["无法修改回路"])))


func _data(module_id: StringName) -> CyberwareData:
	var path := ComponentRolls.cyberware_resource_path(module_id)
	if not path.is_empty():
		return load(path) as CyberwareData
	return player.cyberware.get_circuit_module_data(module_id) if is_instance_valid(player) else null


func _display_name(module_id: StringName) -> String:
	var data := _data(module_id)
	return data.display_name if data != null else String(module_id)


func _kind_prefix(kind: int) -> String:
	return ["[启]", "[修]", "[效]", "[规]"][clampi(kind, 0, 3)]
