extends Control

const WAREHOUSE := "res://scenes/bootstrap/warehouse_main.tscn"
const PORTRAIT := preload("res://assets/art/ui/standard_chassis_portrait.png")
const INK := Color("101d27")
const MUTED := Color("8b9fae")
const LIGHT := Color("ebf1f3")
const CYAN := Color("75e8df")
const AMBER := Color("f3c579")
var page := "home"
var _canvas: Control
var _content: Control
var _continue: Button
var _status: Label
var _busy := false
@onready var store: Node = get_node("/root/WarehouseStore")


func _ready() -> void:
	get_tree().paused = false
	_canvas = Control.new()
	_canvas.size = Vector2(1280, 720)
	add_child(_canvas)
	var background := ColorRect.new()
	background.color = Color("0b131d")
	background.size = Vector2(1280, 720)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(background)
	var top := _label("WJC  /  五角场热线", 19, LIGHT)
	place(top, Rect2(64, 32, 600, 32), _canvas)
	var channel := _label("接线终端   //   CHANNEL 01", 16, MUTED)
	channel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	place(channel, Rect2(800, 32, 416, 32), _canvas)
	var line := ColorRect.new()
	line.color = Color("2b3c47")
	place(line, Rect2(64, 81, 1152, 1), _canvas)
	var card := Panel.new()
	card.add_theme_stylebox_override("panel", CyberUITheme.create_box(Color("fafafa"), Color("fafafa"), 0))
	place(card, Rect2(704, 112, 512, 548), _canvas)
	var portrait := TextureRect.new()
	portrait.texture = PORTRAIT
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(portrait, Rect2(714, 122, 492, 510), _canvas)
	var tag := _label("01   /   标准机体", 16, INK)
	place(tag, Rect2(726, 625, 450, 26), _canvas)
	var footer := _label("WASD 移动    /    鼠标攻击    /    E 交互    /    Tab 配装", 15, MUTED)
	place(footer, Rect2(64, 677, 1152, 26), _canvas)
	_content = Control.new()
	place(_content, Rect2(64, 112, 584, 548), _canvas)
	resized.connect(_resize_canvas)
	_resize_canvas()
	show_home()


func _resize_canvas() -> void:
	var ratio := minf(size.x / 1280.0, size.y / 720.0)
	_canvas.scale = Vector2.ONE * ratio
	_canvas.position = (size - Vector2(1280, 720) * ratio) * 0.5


func place(node: Control, rect: Rect2, parent: Control) -> void:
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", CyberUITheme.FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(value: String, rect: Rect2, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = value
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", CyberUITheme.FONT)
	button.add_theme_font_size_override("font_size", 22)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var highlighted: bool = state in ["hover", "focus", "pressed"]
		var fill := CYAN if primary else Color("152431")
		if highlighted:
			fill = Color("c4fff5") if primary else Color("263e4c")
		if state == "disabled":
			fill = Color("131c25")
		var style := CyberUITheme.create_box(fill, CYAN if highlighted else fill, 1)
		style.content_margin_left = 22
		button.add_theme_stylebox_override(state, style)
		button.add_theme_color_override("font_" + state + "_color" if state != "normal" else "font_color", INK if primary else LIGHT)
	button.add_theme_color_override("font_disabled_color", Color("50606e"))
	button.pressed.connect(action)
	place(button, rect, _content)
	if primary:
		button.grab_focus()
	return button


func _clear_page(next_page: String) -> void:
	page = next_page
	for node in _content.get_children():
		_content.remove_child(node)
		node.queue_free()
	_status = null


func _heading(kicker: String, title: String, description: String) -> void:
	place(_label(kicker, 16, CYAN), Rect2(0, 2, 580, 28), _content)
	place(_label(title, 46, LIGHT), Rect2(0, 46, 580, 66), _content)
	var subtitle := _label(description, 19, MUTED)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	place(subtitle, Rect2(0, 132, 548, 75), _content)


func show_home() -> void:
	_clear_page("home")
	_heading("CONNECTION READY  /  等待接入", "五角场热线", "接起热线，进入行动。\n选择继续当前进度，或从新的存档开始。")
	var valid: bool = store.load_profile()
	var exists: bool = store.has_saved_profile()
	_continue = _button("继续当前存档    →", Rect2(0, 236, 548, 64), continue_game, true)
	_continue.disabled = not exists or not valid
	var new_game := _button("开始新存档", Rect2(0, 314, 548, 64), show_character)
	_button("退出游戏", Rect2(0, 392, 548, 58), func() -> void: get_tree().quit())
	var summary := "还没有存档，从新存档开始你的第一次行动。"
	if exists and valid:
		var profile: Dictionary = store.get_profile()
		summary = "当前存档可继续  ·  仓库装备 %d 件" % profile.chest.size()
	elif not valid:
		summary = store.error_message + "；可开始新存档。"
	_status = _label(summary, 17, MUTED if valid else AMBER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	place(_status, Rect2(0, 474, 548, 64), _content)
	if not _continue.disabled:
		_continue.grab_focus()
	else:
		new_game.grab_focus()


func show_character() -> void:
	if _busy:
		return
	_clear_page("character")
	_heading("SELECT CHASSIS  /  角色选择", "标准机体", "确认这台机体，开始新的行动记录。\n当前开放一个可选角色。")
	place(_label("01  标准机体   /   已选择", 23, CYAN), Rect2(0, 238, 548, 42), _content)
	var detail := _label("初始装备  /  制式警棍 × 1\n基础移动  /  步行\n轮式组件可在行动中获取并装备", 19, LIGHT)
	place(detail, Rect2(0, 296, 548, 92), _content)
	_button("确认机体 · 开始新存档    →", Rect2(0, 414, 548, 64), request_new_game, true)
	_button("返回", Rect2(0, 492, 548, 52), show_home)


func request_new_game() -> void:
	if _busy:
		return
	if not store.has_saved_profile():
		start_new_game()
		return
	_clear_page("confirm")
	_heading("NEW RECORD  /  确认新存档", "重新开始？", "当前装备和仓库进度将重置。\n旧存档会先备份，再创建新存档。")
	_button("备份旧存档并开始    →", Rect2(0, 256, 548, 64), start_new_game, true)
	_button("取消，返回角色选择", Rect2(0, 334, 548, 64), show_character)
	_status = _label("", 18, AMBER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	place(_status, Rect2(0, 432, 548, 100), _content)


func start_new_game() -> void:
	if _busy:
		return
	if not store.create_new_profile():
		if _status == null:
			_status = _label("", 17, AMBER)
			place(_status, Rect2(0, 388, 548, 26), _content)
		_status.text = store.error_message
		return
	_enter_warehouse()


func continue_game() -> void:
	if _busy or not store.has_saved_profile() or not store.load_profile():
		return
	_enter_warehouse()


func _enter_warehouse() -> void:
	_busy = true
	get_node("/root/RunManager").begin_run()
	get_node("/root/RunManager").set_scene_payload({})
	var error := get_tree().change_scene_to_file(WAREHOUSE)
	if error != OK:
		_busy = false
		show_home()
		_status.text = "无法进入仓库，请重试。"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _busy:
		if page == "confirm":
			show_character()
		elif page == "character":
			show_home()
