extends CanvasLayer

## Session-only test tools. WarehouseStore keeps every test write in memory.
const MAIN_MENU := "res://scenes/ui/start_menu.tscn"
const WAREHOUSE_MAIN := "res://scenes/bootstrap/warehouse_main.tscn"
const FLOOR := "res://scenes/levels/floors/combat_prototype.tscn"
const CODEX_PASSAGE := "res://scenes/levels/intermissions/codex_service_passage.tscn"
const BOSS := "res://scenes/levels/bosses/rooftop_boss_arena.tscn"
const PERSONA_PORTRAITS := {
	&"deep_ninja": preload("res://assets/art/ui/start_menu/persona_naraku_ghost.png"),
	&"legendary_master": preload("res://assets/art/ui/start_menu/persona_xiangshan_ghost.png"),
	&"rock_vigilante": preload("res://assets/art/ui/start_menu/persona_johnny_ghost.png"),
}
const CIRCUIT_LAB := "res://scenes/debug/cyberware_circuit_lab.tscn"
const COMMAND_HELP := {
	"help": "help [指令]  查看指令列表或参数说明",
	"jump": "jump <lab|warehouse|floor1|floor2|floor3|boss|channel|channel_core|channel_boss>  跳转并保留测试配装",
	"give": "give <物品ID> [品质1-3]  领取一件正式物品",
	"build": "build <人格ID> <等级1-3> <逐级天赋ID...>  应用一套完整天赋",
	"seed": "seed <整数>  设置下一次跳关所用的随机种子",
	"clear": "clear  清理当前普通楼层",
	"win": "win  击败当前 Boss",
	"status": "status  显示关卡、种子、生命和回路槽位",
	"report": "report  导出本次测试的指令和状态记录",
	"capture": "capture  保存当前游戏画面并加入测试报告",
	"replay": "replay <报告文件名.json>  在新测试会话中重放成功的场景指令",
}
const JUMP_TARGETS := {
	"lab": -2, "warehouse": -1, "floor1": 0, "floor2": 1,
	"floor3": 2, "boss": 3,
}

var enabled := false
var _ending := false
var _busy := false
var _owns_pause := false
var _original_difficulty := 1
var _overlay: ColorRect
var _badge: Button
var _launcher: Button
var _message: Label
var _feedback_scroll: ScrollContainer
var _command_input: LineEdit
var _command_hint: Label
var _command_history: Array[String] = []
var _command_results: Array[Dictionary] = []
var _history_cursor := 0
var _queued_seed := 0
var _last_capture := ""
var _items: OptionButton
var _quality: OptionButton
var _persona: OptionButton
var _level: OptionButton
var _talents: Array[OptionButton] = []
var _item_ids: Array[String] = []


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func set_enabled(value: bool) -> bool:
	if _ending:
		return false
	if enabled == value:
		return true
	var store := get_node("/root/WarehouseStore")
	if value:
		if not store.begin_test_session():
			get_node("/root/CombatEvents").publish_message(store.error_message)
			return false
		_original_difficulty = int(get_parent().difficulty)
		enabled = true
		_badge.show()
		if _launcher != null:
			_launcher.hide()
		return true
	_ending = true
	call_deferred("_end_session")
	return true


func _end_session() -> void:
	close_panel()
	# Unload all gameplay callbacks while the memory-only store is still active.
	var error := get_tree().change_scene_to_file(MAIN_MENU)
	if error != OK:
		_ending = false
		return
	get_node("/root/WarehouseStore").end_test_session()
	get_node("/root/RunManager").begin_run()
	get_parent().set_difficulty(_original_difficulty, false)
	# change_scene has removed the old tree; restore before the new menu reads it.
	await get_tree().scene_changed
	enabled = false
	_ending = false
	_badge.hide()
	if _launcher != null:
		_launcher.show()
	get_tree().paused = false


func _input(event: InputEvent) -> void:
	if _ending or _busy or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F8 or event.physical_keycode == KEY_F8:
		if not enabled and not set_enabled(true):
			return
		if _overlay.visible:
			close_panel()
		else:
			open_panel()
		get_viewport().set_input_as_handled()
	elif enabled and _overlay.visible and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
		close_panel()
		get_viewport().set_input_as_handled()


func open_panel() -> void:
	if not enabled or _ending or _busy:
		return
	if _overlay.visible:
		return
	_owns_pause = not get_tree().paused
	get_tree().paused = true
	_overlay.show()
	_message.text = "测试数据不写入正式存档。选择操作后，即可收起面板继续试玩。"
	_feedback_scroll.custom_minimum_size.y = 24
	_sync_persona()
	_items.grab_focus()


func close_panel() -> void:
	_overlay.hide()
	if _owns_pause:
		get_tree().paused = false
	_owns_pause = false


func _player() -> PlayerController:
	if not enabled or _ending:
		return null
	return get_tree().get_first_node_in_group("player") as PlayerController


func _flow() -> SceneContainerManager:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("SceneFlow") as SceneContainerManager if scene != null else null


func grant_item(id: String, quality: int = 1) -> bool:
	var player := _player()
	if player == null or player.health.is_dead() or id not in _item_ids:
		return false
	var random := RandomNumberGenerator.new()
	random.randomize()
	var item := ComponentRolls.create(id, clampi(quality, 1, 3), random)
	var granted := player.inventory.pickup(id, item)
	return granted


func apply_talents(persona_id: StringName, level: int, choices: Array) -> bool:
	var player := _player()
	if player == null or player.health.is_dead() or level < 1 or level > 3 or persona_id not in TalentCoreController.PERSONA_IDS or choices.size() != level:
		return false
	# Validate the full selection before mutating any talent or level.
	for tier in range(1, level + 1):
		if choices[tier - 1] not in TalentCoreController.TALENT_OPTIONS[persona_id][tier]:
			return false
	var core := player.talent_core
	core.set_persona_level(persona_id, level)
	core.set_persona(persona_id)
	for tier in range(1, level + 1):
		core.set_talent_choice(persona_id, tier, choices[tier - 1])
	get_node("/root/RunManager").set_player_state(player.export_run_state())
	var flow := _flow()
	if flow != null:
		var rest := flow.get_parent().get_node_or_null("PersonaRestFlow")
		if rest != null and rest.is_open:
			var run := get_node("/root/RunManager")
			run.consume_persona_authorization(run.floor_index)
			rest.close(true)
			get_tree().paused = true
			_owns_pause = true
	return true


func jump_to(floor_index: int) -> bool:
	if floor_index < -2 or floor_index > 3:
		return false
	var destination := BOSS if floor_index == 3 else FLOOR
	if floor_index == -2:
		destination = CIRCUIT_LAB
	elif floor_index == -1:
		destination = "res://scenes/levels/base/warehouse.tscn"
	return await _jump_to(floor_index, destination)


func jump_to_codex(with_core := false) -> bool:
	return await _jump_to(1, CODEX_PASSAGE, with_core)


func jump_to_channel_boss() -> bool:
	return await _jump_to(3, BOSS, true, true)


func _jump_to(floor_index: int, destination: String, with_core := false, with_duel := false) -> bool:
	if not enabled or _ending or _busy:
		return false
	_busy = true
	var flow := _flow()
	if flow == null:
		close_panel()
		if get_tree().change_scene_to_file(WAREHOUSE_MAIN) != OK:
			_busy = false
			return false
		await get_tree().scene_changed
		flow = _flow()
		for frame in 600:
			await get_tree().process_frame
			if not enabled or _ending or not is_instance_valid(flow):
				_busy = false
				return false
			if flow != null and not flow._is_loading and flow._scene_container.get_child_count() > 0:
				break
	if flow == null or flow._is_loading:
		_busy = false
		return false
	var player := _player()
	var original_player := player.export_run_state() if player != null else {}
	if with_core:
		if player == null or not player.inventory.grant_channel_core():
			_busy = false
			_message.text = "请先空出一格背包，再进入携带核心的通道"
			return false
		player.apply_channel_curse(true)
	var snapshot := player.export_run_state() if player != null else {}
	if player != null:
		snapshot["current_health"] = player.health.max_health
	var core_route: bool = (destination == CODEX_PASSAGE or with_duel) and player != null and get_node("/root/RunManager").carries_channel_core(player)
	if core_route:
		var store := get_node("/root/WarehouseStore")
		if not store.is_channel_route_unlocked():
			var profile: Dictionary = store.get_profile()
			if not store.commit(profile.chest, profile.loadout, "", {"id": "test-codex-route", "ending": "core_destroyed", "personas": [], "semantic_leaks": []}):
				player.import_run_state(original_player)
				_busy = false
				return false
		store.acknowledge_channel_intro()
	if floor_index == -1:
		var store := get_node("/root/WarehouseStore")
		if not store.commit(store.get_profile().chest, snapshot):
			_busy = false
			return false
	# Clear modal state in the persistent bootstrap before replacing the room.
	var main := flow.get_parent()
	var rest := main.get_node_or_null("PersonaRestFlow")
	if rest != null:
		rest.close(true)
	var extraction := main.get_node_or_null("ExtractionFlow")
	if extraction != null:
		extraction._settled = false
		extraction._death_pending = false
		extraction.close_exit()
	if player != null:
		player.inventory.set_open(false)
	var run := get_node("/root/RunManager")
	var old_run := _run_snapshot(run)
	run.begin_run()
	if _queued_seed != 0:
		run.run_seed = _queued_seed
	run.floor_index = maxi(floor_index, 0)
	run.persistent_run = floor_index >= 0
	if core_route:
		run.channel_route_active = true
		run.channel_record_found = true
		if with_duel:
			run.codex_companion = {"joined": true, "health": 3, "arrived": false, "ambush_complete": true}
	# Direct talent selection replaces the mandatory drink screen on test jumps.
	run.persona_authorization_floor = run.floor_index
	run.persona_authorization_pending = false
	run.persona_rest_refilled_floor = run.floor_index
	run.set_player_state(snapshot)
	if not flow.request_scene(destination, {"player_state": snapshot}):
		if is_instance_valid(player):
			player.import_run_state(original_player)
		_restore_run(run, old_run)
		_busy = false
		return false
	close_panel()
	get_tree().paused = false
	for frame in 600:
		await get_tree().process_frame
		if not enabled or _ending or not is_instance_valid(flow):
			_busy = false
			return false
		if not flow._is_loading:
			break
	_busy = false
	var success := not flow._is_loading and flow._scene_container.get_child_count() > 0 and flow._scene_container.get_child(0).scene_file_path == destination
	if success:
		_queued_seed = 0
	if not success:
		if is_instance_valid(player):
			player.import_run_state(original_player)
		_restore_run(run, old_run)
	return success


func _run_snapshot(run: Node) -> Dictionary:
	var snapshot := {}
	for property in run.get_script().get_script_property_list():
		var key := String(property.name)
		if key == "script" or not (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var value: Variant = run.get(key)
		snapshot[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return snapshot


func _restore_run(run: Node, snapshot: Dictionary) -> void:
	for key in snapshot:
		run.set(key, snapshot[key])


func clear_area() -> bool:
	var flow := _flow()
	if not enabled or _ending or _busy or flow == null or flow._is_loading or flow._scene_container.get_child_count() == 0:
		return false
	var scene := flow._scene_container.get_child(0)
	if scene is RooftopBossArena:
		return defeat_boss()
	var assembler := scene.get_node_or_null("FloorAssembler") as FloorAssembler
	if assembler == null:
		return false
	# Include inactive combat areas so clearing the floor also opens its exits.
	for room in assembler.generated_rooms:
		room.activate()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if scene.is_ancestor_of(enemy) and enemy is EnemyController and not enemy.health.is_dead():
			_finish_enemy(enemy)
	return true


func _finish_enemy(enemy: EnemyController) -> void:
	# Instant clear also finalizes self-destruct heavies while the panel is paused.
	enemy.health.set_current_health(0)
	enemy._finalize_defeat()


func defeat_boss() -> bool:
	var flow := _flow()
	if not enabled or _ending or _busy or flow == null or flow._is_loading or flow._scene_container.get_child_count() == 0:
		return false
	var arena := flow._scene_container.get_child(0) as RooftopBossArena
	if arena == null or arena.phase == RooftopBossArena.Phase.CLEARED:
		return false
	var packet := DamagePacket.new()
	packet.source_faction = CombatFaction.Id.PLAYER
	# The debug action explicitly bypasses awakening and guard-linked immunity.
	arena.boss.health.end_guard_link()
	arena.boss.health.set_current_health(0)
	arena.boss.health.died.emit(packet)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if arena.is_ancestor_of(enemy) and enemy is EnemyController and not enemy.health.is_dead():
			_finish_enemy(enemy)
	return true


const INK := Color("dce8f2")
const SOFT_INK := Color("8299af")
const ACCENT := Color("61d9d0")
const LINE := Color("2a4055")


func _panel_box(fill: Color, border: Color, padding := 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(4)
	box.set_content_margin_all(padding)
	return box


func _test_theme() -> Theme:
	var theme := CyberUITheme.create_theme()
	for type_name in [&"Label", &"Button", &"OptionButton", &"PopupMenu"]:
		theme.set_color("font_color", type_name, INK)
		theme.set_color("font_hover_color", type_name, Color.WHITE)
		theme.set_color("font_focus_color", type_name, Color.WHITE)
		theme.set_color("font_pressed_color", type_name, ACCENT)
		theme.set_color("font_disabled_color", type_name, Color(SOFT_INK, 0.45))
	for type_name in [&"Button", &"OptionButton"]:
		theme.set_stylebox("normal", type_name, _panel_box(Color("172a3b"), LINE, 5))
		theme.set_stylebox("hover", type_name, _panel_box(Color("213d50"), ACCENT, 5))
		theme.set_stylebox("pressed", type_name, _panel_box(Color("1b494e"), ACCENT, 5))
		theme.set_stylebox("disabled", type_name, _panel_box(Color("101d2b"), Color("203144"), 5))
		theme.set_stylebox("focus", type_name, _panel_box(Color.TRANSPARENT, ACCENT, 5))
	theme.set_stylebox("panel", "PopupMenu", _panel_box(Color("122334"), LINE))
	theme.set_stylebox("hover", "PopupMenu", _panel_box(Color("244653"), ACCENT, 4))
	theme.set_constant("v_separation", "PopupMenu", 8)
	theme.set_stylebox("separator", "HSeparator", _panel_box(LINE, LINE, 0))
	theme.set_stylebox("scroll", "VScrollBar", _panel_box(Color("0c1824"), Color("0c1824"), 2))
	theme.set_stylebox("grabber", "VScrollBar", _panel_box(LINE, LINE, 2))
	theme.set_stylebox("grabber_highlight", "VScrollBar", _panel_box(ACCENT, ACCENT, 2))
	theme.set_stylebox("grabber_pressed", "VScrollBar", _panel_box(ACCENT, ACCENT, 2))
	return theme


func _build_ui() -> void:
	var theme := _test_theme()
	_badge = Button.new()
	_badge.text = "● 测试模式  /  F8"
	_badge.tooltip_text = "打开测试面板；Esc 收起后继续试玩"
	_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_badge.offset_left = -160
	_badge.offset_right = -8
	_badge.offset_top = 4
	_badge.offset_bottom = 28
	_badge.theme = theme
	_badge.pressed.connect(open_panel)
	add_child(_badge)
	_badge.hide()
	if OS.has_feature("mobile"):
		_launcher = Button.new()
		_launcher.text = "测试工具"
		_launcher.tooltip_text = "打开隔离测试控制台"
		_launcher.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_launcher.offset_left = -112
		_launcher.offset_right = -8
		_launcher.offset_top = 4
		_launcher.offset_bottom = 28
		_launcher.theme = theme
		_launcher.pressed.connect(func() -> void:
			if set_enabled(true):
				open_panel()
		)
		add_child(_launcher)
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color("09131f")
	_overlay.theme = theme
	add_child(_overlay)
	CyberUITheme.add_os_frame(_overlay)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	_overlay.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	header.add_child(titles)
	var heading := _label(titles, "测试控制台", INK)
	heading.add_theme_font_size_override("font_size", 20)
	_label(titles, "自由配装 · 快速跳转 · 即时验证", SOFT_INK).add_theme_font_size_override("font_size", 10)
	var status := _label(header, "● 隔离测试中", ACCENT)
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var content := HBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	var routes := _card(content, "01  关卡跳转", "保留当前测试配装")
	routes.get_parent().size_flags_stretch_ratio = 0.9
	var destinations := GridContainer.new()
	destinations.columns = 2
	destinations.add_theme_constant_override("h_separation", 5)
	destinations.add_theme_constant_override("v_separation", 5)
	routes.add_child(destinations)
	_button(destinations, "义体构筑试验场", _on_jump.bind(-2))
	_button(destinations, "测试仓库", _on_jump.bind(-1))
	for index in 3:
		_button(destinations, "第 %d 层" % (index + 1), _on_jump.bind(index))
	_button(destinations, "直达 Boss", _on_jump.bind(3))
	_button(destinations, "二结局 Boss", _on_channel_boss_jump)
	_button(routes, "直达 Codex 通道", _on_codex_jump.bind(false))
	_button(routes, "通道＋二结局核心", _on_codex_jump.bind(true))
	var separator := HSeparator.new()
	routes.add_child(separator)
	var cheats := HBoxContainer.new()
	cheats.add_theme_constant_override("separation", 5)
	routes.add_child(cheats)
	_button(cheats, "一键清场", func() -> void: _message.text = "本层已清理" if clear_area() else "请先进入战斗关卡")
	_button(cheats, "击败 Boss", func() -> void: _message.text = "Boss 已击败，可前往出口结算" if defeat_boss() else "请先进入未通关的 Boss 关")
	var loadout := VBoxContainer.new()
	loadout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loadout.add_theme_constant_override("separation", 8)
	content.add_child(loadout)
	var equipment := _card(loadout, "02  装备补给", "领取后按 Tab 配装")
	var equipment_row := HBoxContainer.new()
	equipment_row.add_theme_constant_override("separation", 5)
	equipment.add_child(equipment_row)
	_items = OptionButton.new()
	_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items.fit_to_longest_item = false
	_style_image_options(_items)
	for id: String in ComponentInventory.PROTOTYPES.data:
		var prototype: Dictionary = ComponentInventory.PROTOTYPES.data[id]
		if bool(prototype.get("debug_only", false)) or bool(prototype.get("bound", false)) or id in ["baton", "initial_baton", "wheel"] or str(prototype.get("slot", "")) not in ["weapon", "cyberware", "defense", "insurance"]:
			continue
		_item_ids.append(id)
		var item := ComponentRolls.make_item(id)
		_items.add_icon_item(item.get_texture(), item.get_title())
		_items.get_popup().set_item_icon_max_width(_items.item_count - 1, 24)
	_items.item_selected.connect(func(_index: int) -> void: _sync_quality())
	equipment_row.add_child(_items)
	_quality = OptionButton.new()
	for text in ["制式", "改良", "原型"]:
		_quality.add_item(text)
	equipment_row.add_child(_quality)
	_sync_quality()
	_button(equipment_row, "领取", _on_grant, true)
	var talents := _card(loadout, "03  人格与天赋", "直接应用，无需饮料")
	var persona_row := HBoxContainer.new()
	persona_row.add_theme_constant_override("separation", 5)
	talents.add_child(persona_row)
	_persona = OptionButton.new()
	_persona.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_persona.fit_to_longest_item = false
	_style_image_options(_persona)
	for id in TalentCoreController.PERSONA_IDS:
		_persona.add_icon_item(PERSONA_PORTRAITS[id], TalentCoreController.PERSONA_DISPLAY_NAMES[id])
		_persona.get_popup().set_item_icon_max_width(_persona.item_count - 1, 28)
	_persona.item_selected.connect(func(_index: int) -> void: _refresh_talents())
	persona_row.add_child(_persona)
	_level = OptionButton.new()
	for value in range(1, 4):
		_level.add_item("Lv.%d" % value)
	_level.select(2)
	_level.item_selected.connect(func(_index: int) -> void: _refresh_talents())
	persona_row.add_child(_level)
	_button(persona_row, "应用", _on_apply_talents, true)
	for tier in range(1, 4):
		var choices := OptionButton.new()
		choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choices.fit_to_longest_item = false
		_style_image_options(choices)
		choices.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		choices.item_selected.connect(func(_index: int) -> void: _sync_talent_tooltips())
		talents.add_child(choices)
		_talents.append(choices)
	_refresh_talents()
	var command_row := HBoxContainer.new()
	command_row.add_theme_constant_override("separation", 5)
	column.add_child(command_row)
	_command_input = LineEdit.new()
	_command_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_command_input.placeholder_text = "输入测试指令；help 查看用法"
	_command_input.text_submitted.connect(_on_command_submitted)
	_command_input.text_changed.connect(_on_command_changed)
	_command_input.gui_input.connect(_on_command_input_event)
	command_row.add_child(_command_input)
	_button(command_row, "执行", func() -> void: _on_command_submitted(_command_input.text), true)
	_command_hint = _label(column, "help · jump · give · build · seed · clear · win · status · capture · report · replay", SOFT_INK)
	_command_hint.add_theme_font_size_override("font_size", 10)
	var feedback := PanelContainer.new()
	feedback.add_theme_stylebox_override("panel", _panel_box(Color("102830"), Color("265058"), 6))
	column.add_child(feedback)
	_message = Label.new()
	_feedback_scroll = ScrollContainer.new()
	_feedback_scroll.custom_minimum_size.y = 24
	_feedback_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	feedback.add_child(_feedback_scroll)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message.add_theme_font_size_override("font_size", 11)
	_message.add_theme_color_override("font_color", ACCENT)
	_feedback_scroll.add_child(_message)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	column.add_child(footer)
	var hint := _label(footer, "F8 / Esc  收起后继续试玩", SOFT_INK)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", 10)
	_button(footer, "返回游戏", close_panel, true)
	var exit_button := _button(footer, "结束测试", func() -> void: set_enabled(false))
	exit_button.tooltip_text = "结束隔离测试并返回主菜单"
	exit_button.add_theme_color_override("font_color", Color("e7ac96"))
	_overlay.hide()


func _card(parent: Node, title: String, subtitle: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_box(Color("101f2e"), LINE, 7))
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	_label(column, title, ACCENT)
	_label(column, subtitle, SOFT_INK).add_theme_font_size_override("font_size", 10)
	return column


func _label(parent: Node, text: String, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 24
	if primary:
		button.add_theme_stylebox_override("normal", _panel_box(Color("20464c"), Color("3b7e80"), 5))
		button.add_theme_color_override("font_color", Color("b7f4e9"))
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _style_image_options(options: OptionButton) -> void:
	options.expand_icon = true
	options.add_theme_constant_override("icon_max_width", 20)
	options.add_theme_constant_override("h_separation", 5)
	options.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	options.get_popup().max_size = Vector2i(480, 280)


func _sync_talent_tooltips() -> void:
	var id := TalentCoreController.PERSONA_IDS[_persona.selected]
	for index in _talents.size():
		var talent_id: StringName = TalentCoreController.TALENT_OPTIONS[id][index + 1][_talents[index].selected]
		_talents[index].tooltip_text = "%s\n%s" % [PersonaRestFlow.TALENT_TEXT[talent_id][0], PersonaRestFlow.TALENT_SUMMARY[talent_id]]


func _sync_persona() -> void:
	var player := _player()
	if player != null:
		_persona.select(TalentCoreController.PERSONA_IDS.find(player.talent_core.current_persona_id))
		_level.select(maxi(player.talent_core.core_level - 1, 0))
	_refresh_talents()


func _refresh_talents() -> void:
	var id := TalentCoreController.PERSONA_IDS[_persona.selected]
	var player := _player()
	for index in _talents.size():
		var choices := _talents[index]
		choices.clear()
		var options: Array = TalentCoreController.TALENT_OPTIONS[id][index + 1]
		for talent_id: StringName in options:
			var icon := load("res://assets/art/ui/test_talents/%s.svg" % talent_id) as Texture2D
			choices.add_icon_item(icon, "%d 阶  ·  %s" % [index + 1, PersonaRestFlow.TALENT_TEXT[talent_id][0]])
			choices.get_popup().set_item_icon_max_width(choices.item_count - 1, 20)
			choices.get_popup().set_item_tooltip(choices.item_count - 1, PersonaRestFlow.TALENT_TEXT[talent_id][1])
		if player != null:
			var selected := options.find(player.talent_core.get_talent_choice(id, index + 1))
			choices.select(maxi(selected, 0))
		choices.disabled = index > _level.selected
	_sync_talent_tooltips()


func _on_grant() -> void:
	_message.text = ControlPrompts.adapt("已领取，关闭面板后按 Tab 配装") if grant_item(_item_ids[_items.selected], _quality.selected + 1) else "领取失败：请进入游戏，检查背包空间或保险核心是否重复"


func _sync_quality() -> void:
	_quality.disabled = str(ComponentInventory.PROTOTYPES.data[_item_ids[_items.selected]].get("slot", "")) not in ["weapon", "defense"]


func _on_apply_talents() -> void:
	var id := TalentCoreController.PERSONA_IDS[_persona.selected]
	var choices: Array[StringName] = []
	for index in _level.selected + 1:
		choices.append(TalentCoreController.TALENT_OPTIONS[id][index + 1][_talents[index].selected])
	_message.text = "人格与天赋已应用" if apply_talents(id, _level.selected + 1, choices) else "请先进入游戏，再选择天赋"


func _on_jump(index: int) -> void:
	var success := await jump_to(index)
	_message.text = "已进入目标关卡" if success else "暂时无法跳转，请等待加载结束后重试"


func _on_codex_jump(with_core: bool) -> void:
	var success := await jump_to_codex(with_core)
	if success:
		_message.text = "已进入 Codex 通道" + ("，携带核心可触发同行对话" if with_core else "")
	elif not _message.text.contains("空出一格"):
		_message.text = "暂时无法跳转通道，请等待加载结束后重试"


func _on_channel_boss_jump() -> void:
	var success := await jump_to_channel_boss()
	_message.text = "已进入二结局 Boss，按 Enter 继续剧情" if success else "请先空出一格背包，或等待加载结束后重试"


func _on_command_changed(value: String) -> void:
	var command := value.strip_edges().get_slice(" ", 0).to_lower()
	if COMMAND_HELP.has(command):
		_command_hint.text = COMMAND_HELP[command]
		return
	var matches: PackedStringArray = []
	for name in COMMAND_HELP:
		if String(name).begins_with(command):
			matches.append(name)
	_command_hint.text = "可用指令：" + ", ".join(matches) if not matches.is_empty() else "输入 help 查看全部指令"


func _on_command_input_event(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_UP and not _command_history.is_empty():
		_history_cursor = maxi(_history_cursor - 1, 0)
		_command_input.text = _command_history[_history_cursor]
		_command_input.caret_column = _command_input.text.length()
		_command_input.accept_event()
	elif event.keycode == KEY_DOWN and not _command_history.is_empty():
		_history_cursor = mini(_history_cursor + 1, _command_history.size())
		_command_input.text = _command_history[_history_cursor] if _history_cursor < _command_history.size() else ""
		_command_input.caret_column = _command_input.text.length()
		_command_input.accept_event()
	elif event.keycode == KEY_TAB:
		var prefix := _command_input.text.strip_edges().to_lower()
		for name in COMMAND_HELP:
			if String(name).begins_with(prefix):
				_command_input.text = name + " "
				_command_input.caret_column = _command_input.text.length()
				_command_input.accept_event()
				break


func _on_command_submitted(value: String) -> void:
	var line := value.strip_edges()
	if line.is_empty():
		return
	_command_input.editable = false
	var result: Dictionary = await run_command(line)
	_command_input.editable = true
	_command_input.clear()
	_message.text = ("✓ " if result.ok else "✕ ") + String(result.message)
	_feedback_scroll.custom_minimum_size.y = 66 if String(result.message).contains("\n") else 24
	_command_input.grab_focus()


func _command_result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}


func _test_state() -> Dictionary:
	var run := get_node("/root/RunManager")
	var player := _player()
	var scene_path := ""
	var flow := _flow()
	if flow != null and flow._scene_container.get_child_count() > 0:
		scene_path = flow._scene_container.get_child(0).scene_file_path
	return {
		"scene": scene_path,
		"floor": run.floor_index,
		"seed": run.run_seed,
		"health": player.health.current_health if player != null else 0,
		"max_health": player.health.max_health if player != null else 0,
		"slots": player.cyberware.circuit.slot_capacity if player != null else 0,
		"player_state": player.export_run_state() if player != null else {},
	}


func run_command(line: String) -> Dictionary:
	if not enabled or _ending or _busy:
		return _command_result(false, "请先进入可用的测试会话")
	var parts := line.strip_edges().split(" ", false)
	if parts.is_empty():
		return _command_result(false, "请输入指令；help 查看用法")
	var command := parts[0].to_lower()
	var result: Dictionary
	match command:
		"help":
			if parts.size() == 2 and COMMAND_HELP.has(parts[1]):
				result = _command_result(true, COMMAND_HELP[parts[1]])
			elif parts.size() == 1:
				var lines: PackedStringArray = []
				for name in COMMAND_HELP:
					lines.append(COMMAND_HELP[name])
				result = _command_result(true, "\n".join(lines))
			else:
				result = _command_result(false, "未知指令；输入 help 查看列表")
		"jump":
			if parts.size() != 2:
				result = _command_result(false, COMMAND_HELP["jump"])
			elif JUMP_TARGETS.has(parts[1]):
				result = _command_result(await jump_to(JUMP_TARGETS[parts[1]]), "跳转成功：" + parts[1])
			elif parts[1] == "channel" or parts[1] == "channel_core":
				result = _command_result(await jump_to_codex(parts[1] == "channel_core"), "通道跳转完成")
			elif parts[1] == "channel_boss":
				result = _command_result(await jump_to_channel_boss(), "二结局 Boss 跳转完成")
			else:
				result = _command_result(false, COMMAND_HELP["jump"])
		"give":
			if parts.size() < 2 or parts.size() > 3 or not _item_ids.has(parts[1]) or (parts.size() == 3 and not parts[2].is_valid_int()):
				result = _command_result(false, COMMAND_HELP["give"])
			else:
				var quality := int(parts[2]) if parts.size() == 3 else 1
				result = _command_result(quality >= 1 and quality <= 3 and grant_item(parts[1], quality), "领取：" + parts[1])
		"build":
			if parts.size() < 4 or not parts[2].is_valid_int() or parts.size() != int(parts[2]) + 3:
				result = _command_result(false, COMMAND_HELP["build"])
			else:
				var choices: Array[StringName] = []
				for index in range(3, parts.size()):
					choices.append(StringName(parts[index]))
				result = _command_result(apply_talents(StringName(parts[1]), int(parts[2]), choices), "人格构筑已应用")
		"seed":
			if parts.size() != 2 or not parts[1].is_valid_int() or int(parts[1]) == 0:
				result = _command_result(false, COMMAND_HELP["seed"])
			else:
				_queued_seed = int(parts[1])
				result = _command_result(true, "下一次跳关种子：%d" % _queued_seed)
		"clear":
			result = _command_result(parts.size() == 1 and clear_area(), "普通楼层已清理")
		"win":
			result = _command_result(parts.size() == 1 and defeat_boss(), "Boss 已击败")
		"status":
			var state := _test_state()
			result = _command_result(parts.size() == 1, "关卡 %s · 第 %d 层 · 种子 %d · 生命 %d/%d · %d 槽" % [state.scene, state.floor + 1, state.seed, state.health, state.max_health, state.slots])
		"capture":
			result = await _capture_test_screen() if parts.size() == 1 else _command_result(false, COMMAND_HELP["capture"])
		"replay":
			result = await _replay_test_report(parts[1]) if parts.size() == 2 else _command_result(false, COMMAND_HELP["replay"])
		"report":
			result = _export_test_report() if parts.size() == 1 else _command_result(false, COMMAND_HELP["report"])
		_:
			result = _command_result(false, "未知指令；输入 help 查看列表")
	_command_history.append(line.strip_edges())
	_history_cursor = _command_history.size()
	_command_results.append({"command": line.strip_edges(), "ok": result.ok, "message": result.message})
	return result


func _report_folder() -> String:
	return ProjectSettings.globalize_path("user://test-reports")


func _capture_test_screen() -> Dictionary:
	if DirAccess.make_dir_recursive_absolute(_report_folder()) != OK:
		return _command_result(false, "无法创建测试报告目录")
	var was_visible := _overlay.visible
	_overlay.hide()
	await RenderingServer.frame_post_draw
	var path := _report_folder().path_join("capture-%d.png" % Time.get_ticks_msec())
	var error := get_viewport().get_texture().get_image().save_png(path)
	if was_visible:
		_overlay.show()
	if error != OK:
		return _command_result(false, "截图保存失败")
	_last_capture = path
	return _command_result(true, "截图已保存：" + path)


func _export_test_report() -> Dictionary:
	if DirAccess.make_dir_recursive_absolute(_report_folder()) != OK:
		return _command_result(false, "无法创建测试报告目录")
	var path := _report_folder().path_join("report-%d.json" % Time.get_ticks_msec())
	var report := {
		"created": Time.get_datetime_string_from_system(true),
		"platform": OS.get_name(),
		"godot": Engine.get_version_info().string,
		"state": _test_state(),
		"commands": _command_results.duplicate(true),
		"screenshot": _last_capture,
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _command_result(false, "报告写入失败")
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	return _command_result(true, "报告已保存：" + path)


func _replay_test_report(filename: String) -> Dictionary:
	if not filename.begins_with("report-") or filename.get_file() != filename or filename.contains("\\") or not filename.ends_with(".json"):
		return _command_result(false, COMMAND_HELP["replay"])
	var path := _report_folder().path_join(filename)
	if not FileAccess.file_exists(path):
		return _command_result(false, "找不到测试报告：" + filename)
	var report: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not report is Dictionary or not report.get("commands", null) is Array:
		return _command_result(false, "测试报告格式无效")
	var replayed := 0
	for entry in report.commands:
		if not entry is Dictionary or not bool(entry.get("ok", false)):
			continue
		var source := String(entry.get("command", ""))
		if source.get_slice(" ", 0) not in ["seed", "jump", "give", "build", "clear", "win"]:
			continue
		var outcome: Dictionary = await run_command(source)
		if not outcome.ok:
			return _command_result(false, "重放在第 %d 条指令失败：%s" % [replayed + 1, source])
		replayed += 1
	return _command_result(true, "已重放 %d 条场景指令" % replayed)
