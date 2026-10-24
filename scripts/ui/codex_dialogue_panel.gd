extends CanvasLayer

signal completed
const LINES := [
	"第三层还没接通，这里暂时安全。",
	"把想升级的东西放上工作台。我能合成武器、防具，也能复合义体。",
	"选好再动手。复合后的义体拆不开，而且带不出这次行动。",
	"准备好了就去右边，我替你接通第三层。",
]
var player: PlayerController
var is_open := false
var _owns_pause := false
var _page := 0
var _overlay: Control
var _text: Label
var _progress: Label
var _next: Button

func _ready() -> void:
	layer = 97
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.theme = CyberUITheme.create_theme()
	add_child(_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.03, 0.02, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(shade)
	var box := PanelContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_left = 20
	box.offset_right = -20
	box.offset_top = -150
	box.offset_bottom = -16
	box.add_theme_stylebox_override("panel", CyberUITheme.create_box(Color("0b2018"), CyberUITheme.PHOSPHOR))
	_overlay.add_child(box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	box.add_child(column)
	var title := Label.new()
	title.text = "Codex"
	title.add_theme_font_size_override("font_size", 16)
	column.add_child(title)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_text)
	var row := HBoxContainer.new()
	column.add_child(row)
	_progress = Label.new()
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_progress)
	_next = Button.new()
	_next.custom_minimum_size = Vector2(140, 26)
	_next.pressed.connect(advance)
	row.add_child(_next)
	_overlay.hide()

func open() -> void:
	if is_open:
		return
	is_open = true
	_owns_pause = not get_tree().paused
	get_tree().paused = true
	player.set_input_enabled(false)
	_overlay.show()
	_refresh()

func _refresh() -> void:
	_text.text = LINES[_page]
	_progress.text = "%02d/%02d    [E] 继续    [Esc] 退出" % [_page + 1, LINES.size()]
	_next.text = "打开合成台 [E]" if _page == LINES.size() - 1 else "继续对话 [E]"

func advance() -> void:
	if not is_open:
		return
	if _page + 1 < LINES.size():
		_page += 1
		_refresh()
	else:
		close()
		completed.emit()

func close() -> void:
	if not is_open:
		return
	is_open = false
	_overlay.hide()
	if _owns_pause:
		get_tree().paused = false
	_owns_pause = false
	player.set_input_enabled(true)

func _input(event: InputEvent) -> void:
	if not is_open or event.is_echo():
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		advance()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if _owns_pause:
		get_tree().paused = false
