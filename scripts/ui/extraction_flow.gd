extends CanvasLayer

const FLOOR_PATH := "res://scenes/levels/floors/combat_prototype.tscn"
const BOSS_PATH := "res://scenes/levels/bosses/rooftop_boss_arena.tscn"
const CODEX_PASSAGE_PATH := "res://scenes/levels/intermissions/codex_service_passage.tscn"
var _player: PlayerController
var _bound_scene: Node
var _owns_pause := false
var _settled := false
var _active_exit: ExitElevator
var _overlay: TerminalPanel
var _title: Label
var _details: Label
var _buttons: HBoxContainer
var _death_pending := false
var _shade: ColorRect
var _divider: HSeparator
var _settlement_note: Label
var _settlement_layout := false
@onready var flow: SceneContainerManager = get_parent().get_node("SceneFlow")
@onready var run: Node = get_node("/root/RunManager")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_panel()
	flow.scene_swapped.connect(_bind_floor)


func _set_layout(settlement: bool) -> void:
	_settlement_layout = settlement
	_divider.visible = settlement
	_settlement_note.visible = settlement
	_overlay.accent_color = CyberUITheme.PHOSPHOR
	_overlay.panel_color = Color("071a16f5")
	if settlement:
		_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_overlay.offset_left = 48
		_overlay.offset_right = -48
		_overlay.offset_top = 40
		_overlay.offset_bottom = -40
		_overlay.title = "HOTLINE / 行动记录"
		_settlement_note.text = "行动记录已保存 / 可返回仓库"
		_overlay.panel_color = CyberUITheme.BACKGROUND
	else:
		_overlay.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_overlay.offset_left = 20
		_overlay.offset_right = -20
		_overlay.offset_top = -150
		_overlay.offset_bottom = -16
		_overlay.title = "HOTLINE / 上行线路"
	_title.add_theme_font_size_override("font_size", 18 if settlement else 14)
	_details.add_theme_font_size_override("font_size", 12)
	_sync_settlement_shade()


func _build_panel() -> void:
	_shade = ColorRect.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.01, 0.025, 0.02, 0.72)
	_shade.hide()
	add_child(_shade)
	_overlay = TerminalPanel.new()
	_overlay.name = "ExitDialogue"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.theme = CyberUITheme.create_theme()
	_overlay.panel_color = Color("071a16f5")
	add_child(_overlay)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visibility_changed.connect(_sync_settlement_shade)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_overlay.add_child(column)
	_title = Label.new()
	_title.add_theme_color_override("font_color", CyberUITheme.HIGHLIGHT)
	column.add_child(_title)
	_divider = HSeparator.new()
	var rule := StyleBoxLine.new()
	rule.color = CyberUITheme.DIM_GREEN
	rule.thickness = 1
	_divider.add_theme_stylebox_override("separator", rule)
	_divider.hide()
	column.add_child(_divider)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_details = Label.new()
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_theme_color_override("font_color", CyberUITheme.HIGHLIGHT)
	scroll.add_child(_details)
	_settlement_note = Label.new()
	_settlement_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_settlement_note.add_theme_color_override("font_color", CyberUITheme.MUTED)
	_settlement_note.hide()
	column.add_child(_settlement_note)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	_buttons.add_theme_constant_override("separation", 8)
	column.add_child(_buttons)
	_overlay.hide()


func _sync_settlement_shade() -> void:
	_shade.visible = _overlay.visible and _settlement_layout


func _bind_floor(scene: Node, _payload: Dictionary) -> void:
	close_exit()
	_active_exit = null
	_bound_scene = scene
	_player = scene.get_node_or_null("Player") as PlayerController
	if _player != null and not scene.is_in_group("warehouse"):
		_player.player_died.connect(_on_player_died)
	for exit in scene.find_children("*", "Area2D", true, false):
		if exit is ExitElevator:
			exit.entered.connect(open_exit.bind(exit))
			exit.exited.connect(_leave_exit.bind(exit))


func _on_player_died(_packet: DamagePacket) -> void:
	if not run.persistent_run or run.run_finished:
		return
	_death_pending = true
	call_deferred("settle_death")


func settle_death() -> void:
	if not _death_pending or not is_instance_valid(_player):
		return
	var store := get_node("/root/WarehouseStore")
	var profile: Dictionary = store.get_profile()
	var recovery := _player.export_recovery_state()
	_set_layout(true)
	_overlay.title = "HOTLINE / 线路中断"
	_overlay.accent_color = CyberUITheme.DANGER
	_owns_pause = _owns_pause or not get_tree().paused
	get_tree().paused = true
	_overlay.show()
	_clear_buttons()
	if not store.commit(profile.chest, recovery):
		_title.text = "死亡结算保存失败"
		_settlement_note.text = "记录尚未保存 / 请重试"
		_details.text = store.error_message + "。请重试，尚未返回仓库。"
		_add_button("重试保存", settle_death)
		return
	_death_pending = false
	run.run_finished = true
	run.set_player_state(recovery)
	_settled = true
	_title.text = "线路中断 · 行动结束"
	var protected := _player.inventory.blackbox_slot.get_item()
	_settlement_note.text = "仓库箱内物品不受影响 / 回仓时保证有武器可用"
	_details.text = "黑匣保留\n%s\n\n未保护的普通装备和背包物品已丢失。" % (protected.get_title() if protected != null else "无")
	_add_button("返回仓库", return_to_warehouse)


func open_exit(exit: ExitElevator = null) -> void:
	if _overlay.visible or run.run_finished or not is_instance_valid(_player):
		return
	if _player.health.is_dead() or run.mandatory_enemies_remaining > 0 or get_tree().paused:
		return
	# A local exit must not allow extraction while other rooms remain uncleared.
	var assembler := _player.get_parent().get_node_or_null("FloorAssembler")
	if assembler != null and assembler.get("_rooms_remaining") > 0:
		return
	_settled = false
	_active_exit = exit
	_set_layout(false)
	if _bound_scene is RooftopBossArena:
		var arena := _bound_scene as RooftopBossArena
		if not run.persistent_run or arena.phase != RooftopBossArena.Phase.CLEARED:
			return
		_title.text = "完整通关 · 遗产记录待铸造"
		_details.text = "本次人格、三级天赋与战斗特征将被封存为一瓶遗产饮料。\n此记录只在楼顶 Boss 被完整击败后生成。"
		_clear_buttons()
		_add_button("铸造遗产饮料", complete_victory)
		_overlay.show()
		return
	_title.text = "本层已清理"
	_details.text = "撤离带出物品，继续保留配装。\n走出出口范围即可关闭。"
	_clear_buttons()
	_add_button("撤离结算", extract)
	_add_button("继续下一层", continue_floor)
	_overlay.show()


func _leave_exit(exit: ExitElevator) -> void:
	if exit == _active_exit and not _settled:
		close_exit()


func extract() -> void:
	if _settled or not is_instance_valid(_player):
		return
	if not run.finish_extraction(_player):
		return
	var store := get_node("/root/WarehouseStore")
	var profile: Dictionary = store.get_profile()
	if not store.commit(profile.chest, run.extraction_result.player_state):
		run.run_finished = false
		run.extraction_result.clear()
		_details.text = store.error_message + "，请重试撤离。"
		return
	_settled = true
	_set_layout(true)
	_owns_pause = not get_tree().paused
	get_tree().paused = true
	_player.set_input_enabled(false)
	_overlay.title = "HOTLINE / 撤离结算"
	_settlement_note.text = "可带出装备已保存 / 义体随行动结束清除"
	_title.text = "撤离成功 · 第 %d 层" % run.extraction_result.floor
	var lines := PackedStringArray()
	for entry in run.extraction_result.items:
		lines.append("%s：%s" % [entry.location, entry.name])
	_details.text = "带出物品 / %d 件\n\n%s" % [lines.size(), "\n".join(lines)]
	_clear_buttons()
	_add_button("返回仓库", return_to_warehouse)


func return_to_warehouse() -> void:
	if not _settled:
		return
	if not flow.request_scene("res://scenes/levels/base/warehouse.tscn"):
		_details.text += "\n仓库加载失败，请重试。"
		return
	_settled = false
	close_exit()


func continue_floor() -> void:
	if _settled or not is_instance_valid(_player) or _player.health.is_dead():
		return
	if is_instance_valid(_bound_scene) and _bound_scene.is_in_group("intermission"):
		return
	var snapshot: Dictionary = _player.export_run_state()
	var destination := BOSS_PATH if run.floor_index >= run.NORMAL_FLOOR_COUNT - 1 else FLOOR_PATH
	var service_stop: bool = run.floor_index == 1
	if service_stop:
		destination = CODEX_PASSAGE_PATH
	var payload := {"player_state": snapshot, "transit_heat": {"current": _player.heat.current_heat, "overheated": _player.heat.is_overheated}}
	if not flow.request_scene(destination, payload):
		_details.text = "下一层加载请求失败，请重试或返回搜刮。"
		return
	run.set_player_state(snapshot)
	if not service_stop:
		run.floor_index += 1
	close_exit()


func complete_victory() -> void:
	if _settled or not is_instance_valid(_player) or not (_bound_scene is RooftopBossArena):
		return
	var arena := _bound_scene as RooftopBossArena
	if arena.phase != RooftopBossArena.Phase.CLEARED or not run.finish_victory(_player):
		return
	var store := get_node("/root/WarehouseStore")
	var profile: Dictionary = store.get_profile()
	var record: Dictionary = run.victory_result.record
	if not store.commit(profile.chest, run.victory_result.player_state, "", record):
		run.run_finished = false
		run.victory_result.clear()
		run.set_player_state(_player.export_run_state())
		_details.text = store.error_message + "，遗产记录尚未生成，请重试。"
		return
	_settled = true
	_set_layout(true)
	_owns_pause = not get_tree().paused
	get_tree().paused = true
	_player.set_input_enabled(false)
	_overlay.title = "HOTLINE / 完整通关"
	_overlay.accent_color = CyberUITheme.WARNING
	_settlement_note.text = "遗产记录已保存 / 义体随行动结束清除"
	_title.text = "遗产饮料已铸造 · 完整通关"
	var persona_lines := PackedStringArray()
	for entry: Dictionary in record.get("personas", []):
		var talent := String(entry.get("tier_3_talent", ""))
		persona_lines.append("%s Lv.%d%s" % [
			entry.get("name", "未知人格"),
			int(entry.get("level", 0)),
			" · " + talent if not talent.is_empty() else "",
		])
	_details.text = "瓶号 %s\n通关用时 %.1f 秒\n\n%s\n\n最高连续标记击杀 %d · 手动完美格挡 %d\n摇滚峰值 %.1f · 摇滚攻击 %d" % [
		record.get("id", "--"),
		float(record.get("clear_seconds", 0.0)),
		"\n".join(persona_lines) if not persona_lines.is_empty() else "未记录到人格副本",
		int(record.get("highest_marked_kill_chain", 0)),
		int(record.get("manual_perfect_guards", 0)),
		float(record.get("peak_rock_feedback", 0.0)),
		int(record.get("rock_attacks", 0)),
	]
	_clear_buttons()
	_add_button("返回仓库", return_to_warehouse)


func close_exit() -> void:
	if _settled or _death_pending:
		return
	_overlay.hide()
	_active_exit = null
	_release_pause()


func _input(event: InputEvent) -> void:
	if not _overlay.visible:
		return
	if event.is_action_pressed("pause") and not _settled and not _death_pending:
		close_exit()
		get_viewport().set_input_as_handled()
	# Exit choice allows movement; only the completed settlement is modal.
	if (_settled or _death_pending) and event is InputEventKey:
		get_viewport().set_input_as_handled()


func _add_button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(112, 26)
	button.pressed.connect(action)
	_buttons.add_child(button)


func _clear_buttons() -> void:
	for button in _buttons.get_children():
		_buttons.remove_child(button)
		button.queue_free()


func _release_pause() -> void:
	if _owns_pause:
		get_tree().paused = false
		_owns_pause = false


func _exit_tree() -> void:
	_release_pause()
