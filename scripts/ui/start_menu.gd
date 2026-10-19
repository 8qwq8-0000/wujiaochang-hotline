extends Control

const WAREHOUSE := "res://scenes/bootstrap/warehouse_main.tscn"
const PORTRAIT := preload("res://assets/art/ui/standard_chassis_cutout.png")
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
	# A quiet stage light behind the cutout; no card or opaque image backing.
	var light := TextureRect.new()
	var glow := GradientTexture2D.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.12, 0.35, 0.36, 0.23), Color(0.03, 0.07, 0.09, 0.0)])
	glow.gradient = gradient
	glow.width = 512
	glow.height = 512
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	light.texture = glow
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(light, Rect2(476, -64, 880, 850), _canvas)
	var portrait := TextureRect.new()
	portrait.texture = PORTRAIT
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(portrait, Rect2(560, 24, 710, 672), _canvas)
	_content = Control.new()
	place(_content, Rect2(96, 72, 520, 576), _canvas)
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
	button.add_theme_font_size_override("font_size", 25)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var highlighted: bool = state in ["hover", "focus", "pressed"]
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.25, 0.75, 0.7, 0.04) if highlighted else Color.TRANSPARENT
		style.border_color = CYAN
		style.border_width_left = 2 if highlighted else 0
		style.content_margin_left = 20
		button.add_theme_stylebox_override(state, style)
		button.add_theme_color_override("font_" + state + "_color" if state != "normal" else "font_color", CYAN if highlighted or primary else LIGHT)
	button.add_theme_color_override("font_disabled_color", Color("465460"))
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


func _heading(title: String, description: String = "") -> void:
	place(_label(title, 60, LIGHT), Rect2(0, 74, 520, 84), _content)
	if not description.is_empty():
		var subtitle := _label(description, 19, MUTED)
		subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		place(subtitle, Rect2(0, 184, 460, 76), _content)


func show_home() -> void:
	_clear_page("home")
	_heading("五角场热线")
	var valid: bool = store.load_profile()
	var exists: bool = store.has_saved_profile()
	_continue = _button("继续游戏", Rect2(0, 274, 360, 58), continue_game, true)
	_continue.disabled = not exists or not valid
	var new_game := _button("开始新存档", Rect2(0, 342, 360, 58), show_character)
	_button("退出游戏", Rect2(0, 410, 360, 58), func() -> void: get_tree().quit())
	var summary := "暂无存档"
	if exists and valid:
		var profile: Dictionary = store.get_profile()
		summary = "仓库装备 %d 件" % profile.chest.size()
	elif not valid:
		summary = store.error_message + "；可开始新存档。"
	_status = _label(summary, 17, MUTED if valid else AMBER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	place(_status, Rect2(20, 498, 460, 64), _content)
	if not _continue.disabled:
		_continue.grab_focus()
	else:
		new_game.grab_focus()


func show_character() -> void:
	if _busy:
		return
	_clear_page("character")
	_heading("标准机体")
	place(_label("携带制式警棍出发", 21, MUTED), Rect2(0, 190, 460, 38), _content)
	_button("开始行动", Rect2(0, 342, 360, 60), request_new_game, true)
	var back := _button("返回", Rect2(0, 420, 200, 48), show_home)
	back.add_theme_font_size_override("font_size", 19)


func request_new_game() -> void:
	if _busy:
		return
	if not store.has_saved_profile():
		start_new_game()
		return
	_clear_page("confirm")
	_heading("重新开始？", "当前装备与仓库进度将重置。\n旧存档会先备份。")
	_button("确认重开", Rect2(0, 342, 360, 60), start_new_game, true)
	_button("取消", Rect2(0, 420, 200, 48), show_character)
	_status = _label("", 18, AMBER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	place(_status, Rect2(0, 490, 460, 76), _content)


func start_new_game() -> void:
	if _busy:
		return
	if not store.create_new_profile():
		if _status == null:
			_status = _label("", 17, AMBER)
			place(_status, Rect2(0, 280, 460, 48), _content)
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
