extends CanvasLayer

const INTRO := "到仓库了，先歇会儿吧。看见那边的保险箱了吗？过去看看，身上的装备可以存在那里。"
const STORAGE := "就是这个，按 E 打开就行。出门带着的武器，死了会掉落；存在箱子里的会一直保留。舍不得丢的，就先放在这里吧。"
var room: Node2D
var _layout: Control
var _panel: CyberDialoguePanel
var _text: Label
var _marker: Label
var _talking := false
var _introduced := false
var _explained := false
var _owns_pause := false
var _finished := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 31
	_layout = Control.new()
	_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layout)
	_panel = CyberDialoguePanel.new()
	_panel.compact = true
	_panel.title = "AI 接线员 / 通信中  [轻触屏幕继续]" if OS.has_feature("mobile") else "AI 接线员 / 通信中  [Enter 或点击继续]"
	_panel.position = Vector2(14, 272)
	_panel.size = Vector2(612, 78)
	_layout.add_child(_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	_panel.add_child(column)
	var speaker := Label.new()
	speaker.text = "接线员"
	speaker.add_theme_font_override("font", CyberUITheme.FONT)
	speaker.add_theme_font_size_override("font_size", 11)
	speaker.add_theme_color_override("font_color", CyberUITheme.ACCENT)
	speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(speaker)
	_text = Label.new()
	_text.add_theme_font_override("font", CyberUITheme.FONT)
	_text.add_theme_font_size_override("font_size", 13)
	_text.add_theme_color_override("font_color", CyberUITheme.HIGHLIGHT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_text)
	_marker = Label.new()
	_marker.text = "▼"
	_marker.position = Vector2(-12, -64)
	_marker.theme = CyberUITheme.create_theme()
	_marker.add_theme_color_override("font_color", Color("f3c579"))
	_marker.add_theme_font_size_override("font_size", 22)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.get_node("Chest").add_child(_marker)
	room.panel.get("_overlay").visibility_changed.connect(_on_storage_opened)
	_say(INTRO)


func _say(line: String) -> void:
	_text.text = ControlPrompts.adapt(line)
	_panel.show()
	_talking = true
	_owns_pause = not get_tree().paused
	get_tree().paused = true
	room.player.set_input_enabled(false)


func _process(_delta: float) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var ratio := minf(viewport_size.x / 640.0, viewport_size.y / 360.0)
	_layout.scale = Vector2.ONE * ratio
	_layout.position = (viewport_size - Vector2(640, 360) * ratio) * 0.5
	if _finished or _talking or not _introduced or _explained or get_tree().paused:
		return
	if room.player.global_position.distance_to(room.get_node("Chest").global_position) <= 32.0:
		_explained = true
		_say(STORAGE)


func _input(event: InputEvent) -> void:
	if not _talking or event.is_echo():
		return
	var clicked := DialogueAdvanceInput.is_tap(event)
	if clicked or (event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_ESCAPE]):
		get_viewport().set_input_as_handled()
		_introduced = true
		_close_radio()


func _close_radio() -> void:
	_talking = false
	_panel.hide()
	if _owns_pause:
		get_tree().paused = false
	_owns_pause = false
	room.player.set_input_enabled(true)


func _on_storage_opened() -> void:
	if not room.panel.is_open:
		return
	_finished = true
	room.set("_storage_guide_active", false)
	_marker.hide()
	hide()


func _exit_tree() -> void:
	if _owns_pause:
		get_tree().paused = false
