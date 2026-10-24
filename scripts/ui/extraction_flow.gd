extends CanvasLayer

const FLOOR_PATH := "res://scenes/levels/floors/combat_prototype.tscn"
const BOSS_PATH := "res://scenes/levels/bosses/rooftop_boss_arena.tscn"
const CODEX_PASSAGE_PATH := "res://scenes/levels/intermissions/codex_service_passage.tscn"
var _player: PlayerController
var _bound_scene: Node
var _owns_pause := false
var _settled := false
var _active_exit: ExitElevator
var _overlay: ColorRect
var _title: Label
var _details: Label
var _buttons: HBoxContainer
var _death_pending := false
@onready var flow: SceneContainerManager = get_parent().get_node("SceneFlow")
@onready var run: Node = get_node("/root/RunManager")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_panel()
	flow.scene_swapped.connect(_bind_floor)


func _set_layout(settlement: bool) -> void:
	if settlement:
		_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		_overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_overlay.offset_left = -316
		_overlay.offset_right = -16
		_overlay.offset_top = 16
		_overlay.offset_bottom = 180
	_title.add_theme_font_size_override("font_size", 24 if settlement else 18)
	_details.add_theme_font_size_override("font_size", 16 if settlement else 14)


func _build_panel() -> void:
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.025, 0.04, 0.07, 0.96)
	add_child(_overlay)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	_overlay.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	column.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_details = Label.new()
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(_details)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 16)
	column.add_child(_buttons)
	_overlay.hide()


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
	_owns_pause = _owns_pause or not get_tree().paused
	get_tree().paused = true
	_overlay.show()
	_clear_buttons()
	if not store.commit(profile.chest, recovery):
		_title.text = "结算没有保存"
		_details.text = store.error_message + "。请重试；成功前不会返回仓库。"
		_add_button("重试保存", settle_death)
		return
	_death_pending = false
	run.run_finished = true
	run.set_player_state(recovery)
	_settled = true
	_title.text = "行动失败"
	var protected := _player.inventory.blackbox_slot.get_item()
	_details.text = "黑匣保留：%s\n其余随身装备已经丢失。仓库里的装备不受影响，回去后仍有武器可用。" % (protected.get_title() if protected != null else "无")
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
		_title.text = "通关"
		_details.text = "完成记录后，本次行动会加入遗产酒谱。"
		_clear_buttons()
		_add_button("保存通关记录", complete_victory)
		_overlay.show()
		return
	_title.text = "本层已清理"
	_details.text = "现在撤离会带出随身装备；也可以继续前往下一层。走出出口范围即可关闭。"
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
	_title.text = "撤离成功"
	var lines := PackedStringArray()
	for entry in run.extraction_result.items:
		lines.append("%s：%s" % [entry.location, entry.name])
	_details.text = "从第 %d 层带出 %d 件装备\n\n%s\n\n记录已经保存，回到仓库后可存入箱子。" % [run.extraction_result.floor, lines.size(), "\n".join(lines)]
	_clear_buttons()
	_add_button("返回仓库", return_to_warehouse)


func return_to_warehouse() -> void:
	if not _settled:
		return
	if not flow.request_scene("res://scenes/levels/base/warehouse.tscn"):
		_details.text += "\n暂时无法返回仓库，请重试。"
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
		_details.text = "暂时无法进入下一层，请重试或继续搜刮。"
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
		_details.text = store.error_message + "。通关记录还没有保存，请重试。"
		return
	_settled = true
	_set_layout(true)
	_owns_pause = not get_tree().paused
	get_tree().paused = true
	_player.set_input_enabled(false)
	_title.text = "通关记录已保存"
	var persona_lines := PackedStringArray()
	for entry: Dictionary in record.get("personas", []):
		var talent := String(entry.get("tier_3_talent", ""))
		persona_lines.append("%s Lv.%d%s" % [
			entry.get("name", "未知人格"),
			int(entry.get("level", 0)),
			"（三级天赋：" + talent + "）" if not talent.is_empty() else "",
		])
	_details.text = "编号 %s\n通关用时 %.1f 秒\n\n%s\n\n最高连续标记击杀 %d，手动完美格挡 %d\n摇滚峰值 %.1f，摇滚攻击 %d" % [
		record.get("id", "--"),
		float(record.get("clear_seconds", 0.0)),
		"\n".join(persona_lines) if not persona_lines.is_empty() else "未使用人格",
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
