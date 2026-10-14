extends CanvasLayer

const FLOOR_PATH := "res://scenes/levels/floors/combat_prototype.tscn"
var _player: PlayerController
var _owns_pause := false
var _settled := false
var _active_exit: ExitElevator
var _overlay: ColorRect
var _title: Label
var _details: Label
var _buttons: HBoxContainer
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
	_player = scene.get_node_or_null("Player") as PlayerController
	for exit in scene.find_children("*", "Area2D", true, false):
		if exit is ExitElevator:
			exit.entered.connect(open_exit.bind(exit))
			exit.exited.connect(_leave_exit.bind(exit))


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
	_settled = true
	_set_layout(true)
	_owns_pause = not get_tree().paused
	get_tree().paused = true
	_player.set_input_enabled(false)
	_title.text = "撤离成功 · 第 %d 层" % run.extraction_result.floor
	var lines := PackedStringArray()
	for entry in run.extraction_result.items:
		lines.append("%s：%s" % [entry.location, entry.name])
	_details.text = "带出物品（%d 件）\n\n%s\n\n本局结算已保留在当前运行中。仓库与永久存档尚未接入，关闭游戏后不会保存。" % [lines.size(), "\n".join(lines)]
	_clear_buttons()
	_add_button("开始新一局", start_new_run)


func continue_floor() -> void:
	if _settled or not is_instance_valid(_player) or _player.health.is_dead():
		return
	var snapshot: Dictionary = _player.export_run_state()
	if not flow.request_scene(FLOOR_PATH, {"player_state": snapshot}):
		_details.text = "下一层加载请求失败，请重试或返回搜刮。"
		return
	run.set_player_state(snapshot)
	run.floor_index += 1
	close_exit()


func start_new_run() -> void:
	if not _settled:
		return
	# Confirm the scene can load before clearing the previous result.
	if not flow.request_scene(FLOOR_PATH):
		_details.text += "\n新一局加载请求失败，请重试。"
		return
	run.begin_run()
	_settled = false
	close_exit()


func close_exit() -> void:
	if _settled:
		return
	_overlay.hide()
	_active_exit = null
	_release_pause()


func _input(event: InputEvent) -> void:
	if not _overlay.visible:
		return
	if event.is_action_pressed("pause") and not _settled:
		close_exit()
	# Exit choice allows movement; only the completed settlement is modal.
	if _settled and event is InputEventKey:
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
