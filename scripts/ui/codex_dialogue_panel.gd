extends CanvasLayer

signal completed
const LINES := [
	"你居然真从下面走上来了。先别急，第三层的门还没开，我把这段检修通道隔离出来了。这里暂时安全。",
	"把背包里的零件放到台上。同类、同品质的武器和防御组件，我可以替你合成升级。主体放左边，材料放右边。",
	"义体也能在这里复合。不同模块可以装进同一件义体，最多四种；重复的效果不会叠加，合上以后也不能再拆开。",
	"义体只陪你走完这次行动。左边箱子里的武器可以寄回仓库，死亡也保留；绿色货箱上的小血瓶能补一格耐久。准备好了走右边，我替你接通第三层。",
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
	shade.color = Color(0.01, 0.03, 0.02, 0.18)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(shade)
	var box := TerminalPanel.new()
	box.name = "CodexDialogue"
	box.title = "CODEX / 本地连接"
	box.panel_color = Color("071a16f5")
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_left = 20
	box.offset_right = -20
	box.offset_top = -150
	box.offset_bottom = -16
	_overlay.add_child(box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	box.add_child(column)
	var title := Label.new()
	title.text = "Codex · 临时维修站"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", CyberUITheme.HIGHLIGHT)
	column.add_child(title)
	_text = Label.new()
	_text.add_theme_color_override("font_color", CyberUITheme.HIGHLIGHT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_text)
	var row := HBoxContainer.new()
	column.add_child(row)
	_progress = Label.new()
	_progress.add_theme_color_override("font_color", CyberUITheme.MUTED)
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
	_progress.text = "%02d / %02d    [E] 继续   [Esc] 暂停对话" % [_page + 1, LINES.size()]
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
