class_name ChannelDialogue
extends CanvasLayer

const PAGE_LENGTH := 76
var _owns_pause := false
var _player: PlayerController
var _restore_input := false
var _panel: CyberDialoguePanel
var _text: Label
var _buttons: HBoxContainer
var _on_cancel: Callable
var _layout: Control
var _speaker: Label
var _pages: Array[String] = []
var _page_index := 0
var _choices: Array = []


func _ready() -> void:
	layer = 98
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layout = Control.new()
	_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layout)
	_panel = CyberDialoguePanel.new()
	_panel.compact = true
	_panel.position = Vector2(14, 272)
	_panel.size = Vector2(612, 78)
	_layout.add_child(_panel)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	_panel.add_child(column)
	_speaker = Label.new()
	_speaker.add_theme_font_override("font", CyberUITheme.FONT)
	_speaker.add_theme_font_size_override("font_size", 11)
	_speaker.add_theme_color_override("font_color", Color("75e8df"))
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_speaker)
	_text = Label.new()
	_text.add_theme_font_override("font", CyberUITheme.FONT)
	_text.add_theme_font_size_override("font_size", 13)
	_text.add_theme_color_override("font_color", Color("ebf1f3"))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_text)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	column.add_child(_buttons)
	hide()


func _process(_delta: float) -> void:
	var viewport := get_viewport().get_visible_rect().size
	var ratio := minf(viewport.x / 640.0, viewport.y / 360.0)
	_layout.scale = Vector2.ONE * ratio
	_layout.position = (viewport - Vector2(640, 360) * ratio) * 0.5
	var height := maxf(78, _text.get_minimum_size().y + 48 + (32 if _buttons.visible else 0))
	_panel.position.y = 350 - height
	_panel.size = Vector2(612, height)


func open(title: String, text: String, choices: Array, on_cancel: Callable = Callable()) -> void:
	_speaker.text = title if not title.is_empty() else "接线员"
	_choices = choices.duplicate()
	_pages = _paginate(ControlPrompts.adapt(text))
	_page_index = 0
	_on_cancel = on_cancel
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	if choices.size() > 1:
		for index in choices.size():
			var choice: Array = choices[index]
			var button := Button.new()
			button.text = ControlPrompts.adapt(choice[0])
			button.custom_minimum_size.y = 28
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			CyberDialoguePanel.style_button(button, index == choices.size() - 1)
			button.pressed.connect(_choose.bind(choice[1]))
			_buttons.add_child(button)
	if not visible:
		_owns_pause = not get_tree().paused
		_player = get_tree().get_first_node_in_group("player") as PlayerController
		_restore_input = _player != null and _player.is_input_enabled()
		if _restore_input:
			_player.set_input_enabled(false)
	get_tree().paused = true
	show()
	_refresh_page()


func _paginate(text: String) -> Array[String]:
	var result: Array[String] = []
	for paragraph: String in text.split("\n\n", false):
		var remaining := paragraph.strip_edges()
		while remaining.length() > PAGE_LENGTH:
			var cut := PAGE_LENGTH
			for index in range(PAGE_LENGTH - 1, 29, -1):
				if remaining[index] in "。！？；":
					cut = index + 1
					break
			result.append(remaining.substr(0, cut))
			remaining = remaining.substr(cut).strip_edges()
		if not remaining.is_empty():
			result.append(remaining)
	if result.is_empty():
		result.append("")
	return result


func _refresh_page() -> void:
	_text.text = _pages[_page_index]
	_buttons.visible = _page_index == _pages.size() - 1 and _choices.size() > 1
	_panel.title = "AI 接线员 / 通信中  [选择后继续]" if _buttons.visible else ("AI 接线员 / 通信中  [轻触屏幕继续]" if OS.has_feature("mobile") else "AI 接线员 / 通信中  [Enter 或点击继续]")
	if _pages.size() > 1:
		_panel.title += "  %d/%d" % [_page_index + 1, _pages.size()]
	if _buttons.visible:
		# The ordinary-action / prepare-first option receives initial focus.
		_buttons.get_child(_buttons.get_child_count() - 1).grab_focus()


func _advance_page() -> void:
	if _page_index < _pages.size() - 1:
		_page_index += 1
		_refresh_page()
	elif _choices.size() <= 1:
		_choose(_choices[0][1] if not _choices.is_empty() else Callable())


func _choose(action: Callable) -> void:
	close()
	if action.is_valid():
		action.call()


func close() -> void:
	hide()
	if _restore_input and is_instance_valid(_player) and not _player.health.is_dead():
		_player.set_input_enabled(true)
	_restore_input = false
	if _owns_pause:
		get_tree().paused = false
		_owns_pause = false


func _input(event: InputEvent) -> void:
	if not visible or event.is_echo():
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _on_cancel.is_valid():
			_choose(_on_cancel)
		elif _choices.size() <= 1:
			_advance_page()
		else:
			close()
		return
	if _buttons.visible:
		# Let GUI focus and mouse hit-testing handle deliberate choices.
		return
	var clicked := DialogueAdvanceInput.is_tap(event)
	var continued: bool = event is InputEventKey and event.pressed and event.keycode == KEY_ENTER
	if clicked or continued:
		get_viewport().set_input_as_handled()
		_advance_page()
	elif event is InputEventKey:
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if _restore_input and is_instance_valid(_player) and not _player.health.is_dead():
		_player.set_input_enabled(true)
	if _owns_pause:
		get_tree().paused = false
