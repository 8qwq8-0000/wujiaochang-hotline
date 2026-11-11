extends CanvasLayer

const MESSAGE := "到了，这里就是仓库，暂时安全了。\n\n先休整一下吧，背包里的装备也可以慢慢整理、合成。等你准备好了，我们去右侧的出击入口，按 E 就能再次出击。"
var player: PlayerController
var _layout: Control
var _closed := false
var _backdrop: CyberSignalBackdrop


func _ready() -> void:
	add_to_group("prologue_arrival")
	layer = 96
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	player.set_input_enabled(false)
	_backdrop = CyberSignalBackdrop.new()
	_backdrop.interrupted = false
	add_child(_backdrop)
	_layout = Control.new()
	add_child(_layout)
	var panel := CyberDialoguePanel.new()
	panel.title = "接线员 / 仓库已接通"
	panel.accent_color = CyberUITheme.ACCENT
	panel.set_channel(false)
	panel.size = Vector2(544, 206)
	_layout.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	var text := Label.new()
	text.text = ControlPrompts.adapt(MESSAGE)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 15)
	text.add_theme_color_override("font_color", CyberUITheme.HIGHLIGHT)
	column.add_child(text)
	var button := Button.new()
	button.text = "轻触屏幕开始休整" if OS.has_feature("mobile") else "开始休整 [Enter]"
	CyberDialoguePanel.style_button(button, true)
	button.pressed.connect(close)
	column.add_child(button)
	button.grab_focus()


func _process(_delta: float) -> void:
	var viewport := get_viewport().get_visible_rect().size
	var ratio := minf(viewport.x / 640, viewport.y / 360)
	_backdrop.size = viewport
	_layout.scale = Vector2.ONE * ratio
	_layout.position = (viewport - Vector2(544, 206) * ratio) * 0.5 + Vector2(0, 18) * ratio


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if (event is InputEventScreenTouch and DialogueAdvanceInput.is_tap(event)) or (event is InputEventKey and event.pressed and event.keycode == KEY_ENTER) or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	if _closed:
		return
	_closed = true
	get_tree().paused = false
	if is_instance_valid(player):
		player.set_input_enabled(true)
	queue_free()


func _exit_tree() -> void:
	if not _closed:
		get_tree().paused = false
