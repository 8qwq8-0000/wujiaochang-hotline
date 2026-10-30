extends CanvasLayer

## Session-only test tools. WarehouseStore keeps every test write in memory.
const MAIN_MENU := "res://scenes/ui/start_menu.tscn"
const WAREHOUSE_MAIN := "res://scenes/bootstrap/warehouse_main.tscn"
const FLOOR := "res://scenes/levels/floors/combat_prototype.tscn"
const BOSS := "res://scenes/levels/bosses/rooftop_boss_arena.tscn"

var enabled := false
var _ending := false
var _busy := false
var _owns_pause := false
var _original_difficulty := 1
var _overlay: ColorRect
var _badge: Button
var _message: Label
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
	get_tree().paused = false


func _input(event: InputEvent) -> void:
	if not enabled or _ending or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F8 or (_overlay.visible and event.keycode == KEY_ESCAPE):
		if _overlay.visible:
			close_panel()
		else:
			open_panel()
		get_viewport().set_input_as_handled()


func open_panel() -> void:
	if not enabled or _ending or _busy:
		return
	if _overlay.visible:
		return
	_owns_pause = not get_tree().paused
	get_tree().paused = true
	_overlay.show()
	_message.text = "自由领取装备、选择天赋或跳转关卡。测试数据不写入正式存档。"
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
	if not enabled or _ending or _busy or floor_index < -1 or floor_index > 3:
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
	var snapshot := player.export_run_state() if player != null else {}
	if player != null:
		snapshot["current_health"] = player.health.max_health
	var destination := BOSS if floor_index == 3 else FLOOR
	if floor_index == -1:
		destination = "res://scenes/levels/base/warehouse.tscn"
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
	run.floor_index = maxi(floor_index, 0)
	run.persistent_run = floor_index >= 0
	# Direct talent selection replaces the mandatory drink screen on test jumps.
	run.persona_authorization_floor = run.floor_index
	run.persona_authorization_pending = false
	run.persona_rest_refilled_floor = run.floor_index
	run.set_player_state(snapshot)
	if not flow.request_scene(destination, {"player_state": snapshot}):
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
	if not success:
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


func _build_ui() -> void:
	_badge = Button.new()
	_badge.text = "测试模式 · F8 打开面板"
	_badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_badge.offset_left = -224
	_badge.offset_right = -8
	_badge.offset_top = 4
	_badge.offset_bottom = 28
	_badge.theme = CyberUITheme.create_theme()
	_badge.pressed.connect(open_panel)
	add_child(_badge)
	_badge.hide()
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.015, 0.025, 0.04, 0.98)
	_overlay.theme = CyberUITheme.create_theme()
	add_child(_overlay)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_overlay.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = "测试面板"
	heading.add_theme_font_size_override("font_size", 20)
	column.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	_label(content, "领取装备（关闭面板后按 Tab 配装）")
	var equipment := HBoxContainer.new()
	content.add_child(equipment)
	_items = OptionButton.new()
	_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id: String in ComponentInventory.PROTOTYPES.data:
		var prototype: Dictionary = ComponentInventory.PROTOTYPES.data[id]
		if bool(prototype.get("debug_only", false)) or bool(prototype.get("bound", false)) or id in ["baton", "initial_baton", "wheel"] or str(prototype.get("slot", "")) not in ["weapon", "cyberware", "defense", "insurance"]:
			continue
		_item_ids.append(id)
		var item := ComponentRolls.make_item(id)
		_items.add_item(item.get_title())
	_items.item_selected.connect(func(_index: int) -> void: _sync_quality())
	equipment.add_child(_items)
	_quality = OptionButton.new()
	for text in ["制式", "改良", "原型"]:
		_quality.add_item(text)
	equipment.add_child(_quality)
	_sync_quality()
	_button(equipment, "领取", _on_grant)
	_label(content, "直接选择人格和天赋（无需饮料）")
	var persona_row := HBoxContainer.new()
	content.add_child(persona_row)
	_persona = OptionButton.new()
	_persona.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id in TalentCoreController.PERSONA_IDS:
		_persona.add_item(TalentCoreController.PERSONA_DISPLAY_NAMES[id])
	_persona.item_selected.connect(func(_index: int) -> void: _refresh_talents())
	persona_row.add_child(_persona)
	_level = OptionButton.new()
	for value in range(1, 4):
		_level.add_item("Lv.%d" % value)
	_level.select(2)
	_level.item_selected.connect(func(_index: int) -> void: _refresh_talents())
	persona_row.add_child(_level)
	_button(persona_row, "应用天赋", _on_apply_talents)
	for tier in range(1, 4):
		var choices := OptionButton.new()
		choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(choices)
		_talents.append(choices)
	_refresh_talents()
	_label(content, "关卡跳转（保留当前测试配装）")
	var destinations := HBoxContainer.new()
	content.add_child(destinations)
	_button(destinations, "测试仓库", _on_jump.bind(-1))
	for index in 3:
		_button(destinations, "第 %d 层" % (index + 1), _on_jump.bind(index))
	_button(destinations, "直达 Boss", _on_jump.bind(3))
	var cheats := HBoxContainer.new()
	content.add_child(cheats)
	_button(cheats, "一键清场", func() -> void: _message.text = "本层已清理" if clear_area() else "请先进入战斗关卡")
	_button(cheats, "直接击败 Boss", func() -> void: _message.text = "Boss 已击败，可前往出口结算" if defeat_boss() else "请先进入未通关的 Boss 关")
	_message = Label.new()
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.add_theme_color_override("font_color", CyberUITheme.WARNING)
	column.add_child(_message)
	var footer := HBoxContainer.new()
	column.add_child(footer)
	_button(footer, "关闭面板 / F8", close_panel)
	_button(footer, "退出测试并返回主菜单", func() -> void: set_enabled(false))
	_overlay.hide()


func _label(parent: Node, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", CyberUITheme.HIGHLIGHT)
	parent.add_child(label)


func _button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)


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
			choices.add_item("%d  %s  %s" % [index + 1, PersonaRestFlow.TALENT_TEXT[talent_id][0], PersonaRestFlow.TALENT_SUMMARY[talent_id]])
		if player != null:
			var selected := options.find(player.talent_core.get_talent_choice(id, index + 1))
			choices.select(maxi(selected, 0))
		choices.disabled = index > _level.selected


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
