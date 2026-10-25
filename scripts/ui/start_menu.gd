extends Control

const WAREHOUSE := "res://scenes/bootstrap/warehouse_main.tscn"
const LOBBY_MUSIC := preload("res://assets/audio/music/lobby/lobby_theme.ogg")
const PORTRAIT := preload("res://assets/art/ui/standard_chassis_cutout.png")
const HOME_BACKGROUND := preload("res://assets/art/ui/start_menu/start_menu_background_v1.png")
const HOME_CHASSIS := preload("res://assets/art/ui/start_menu/start_menu_chassis_v1.png")
const HOME_WEAPON := preload("res://assets/art/ui/start_menu/start_menu_weapon_v1.png")
const PERSONA_NARAKU := preload("res://assets/art/ui/start_menu/persona_naraku_ghost.png")
const PERSONA_XIANGSHAN := preload("res://assets/art/ui/start_menu/persona_xiangshan_ghost.png")
const PERSONA_JOHNNY := preload("res://assets/art/ui/start_menu/persona_johnny_ghost.png")
const MUTED := Color("8b9fae")
const LIGHT := Color("ebf1f3")
const CYAN := Color("75e8df")
const AMBER := Color("f3c579")
const POSTER_RED := Color("ff334d")
const POSTER_ORANGE := Color("ff8a00")
const POSTER_YELLOW := Color("ffe600")
var page := "home"
var _canvas: Control
var _content: Control
var _home_art: Control
var _legacy_art: Control
var _home_background: TextureRect
var _hero: TextureRect
var _hero_material: ShaderMaterial
var _hero_base := Vector2.ZERO
var _weapon: TextureRect
var _ghost_layers: Array[Dictionary] = []
var _window_lights: Array[Dictionary] = []
var _home_time := 0.0
var _reveal_progress := 1.0
var _reveal_active := false
var _reveal_played := false
var _reveal_tween: Tween
var _continue: Button
var _status: Label
var _busy := false
var _difficulty := "standard"
var _sound_manager: Node
@onready var store: Node = get_node("/root/WarehouseStore")


func _ready() -> void:
	get_tree().paused = false
	_sound_manager = get_node_or_null("/root/SoundManager")
	_play_lobby_music()
	_canvas = Control.new()
	_canvas.size = Vector2(1280, 720)
	add_child(_canvas)
	var background := ColorRect.new()
	background.color = Color("0b131d")
	background.size = Vector2(1280, 720)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(background)
	_build_home_art()
	_legacy_art = Control.new()
	_legacy_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(_legacy_art, Rect2(0, 0, 1280, 720), _canvas)
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
	place(light, Rect2(476, -64, 880, 850), _legacy_art)
	var portrait := TextureRect.new()
	portrait.texture = PORTRAIT
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(portrait, Rect2(560, 24, 710, 672), _legacy_art)
	_content = Control.new()
	place(_content, Rect2(96, 72, 520, 576), _canvas)
	resized.connect(_resize_canvas)
	_resize_canvas()
	show_home()


func _play_lobby_music() -> void:
	if _sound_manager == null or _sound_manager.is_music_playing(LOBBY_MUSIC):
		return
	_sound_manager.play_music(LOBBY_MUSIC, 0.75)


func _stop_lobby_music() -> void:
	if _sound_manager != null:
		_sound_manager.stop_music(0.75)


func _resize_canvas() -> void:
	var ratio := minf(size.x / 1280.0, size.y / 720.0)
	_canvas.scale = Vector2.ONE * ratio
	_canvas.position = (size - Vector2(1280, 720) * ratio) * 0.5


func _build_home_art() -> void:
	_home_art = Control.new()
	_home_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(_home_art, Rect2(0, 0, 1280, 720), _canvas)

	_home_background = TextureRect.new()
	_home_background.texture = HOME_BACKGROUND
	_home_background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_home_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_home_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_home_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(_home_background, Rect2(0, 0, 1280, 720), _home_art)

	# A dark editorial wash preserves a calm reading column over the city plate.
	var wash := TextureRect.new()
	var wash_texture := GradientTexture2D.new()
	var wash_gradient := Gradient.new()
	wash_gradient.offsets = PackedFloat32Array([0.0, 0.34, 0.62, 1.0])
	wash_gradient.colors = PackedColorArray([
		Color(0.02, 0.025, 0.03, 0.98),
		Color(0.02, 0.025, 0.03, 0.86),
		Color(0.02, 0.025, 0.03, 0.2),
		Color(0.02, 0.025, 0.03, 0.0),
	])
	wash_texture.gradient = wash_gradient
	wash_texture.width = 1280
	wash_texture.height = 720
	wash_texture.fill = GradientTexture2D.FILL_LINEAR
	wash_texture.fill_from = Vector2(0.0, 0.5)
	wash_texture.fill_to = Vector2(1.0, 0.5)
	wash.texture = wash_texture
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(wash, Rect2(0, 0, 1280, 720), _home_art)

	_add_ghost(PERSONA_NARAKU, Rect2(446, -72, 470, 470), POSTER_RED, 0.21, 0.0)
	_add_ghost(PERSONA_XIANGSHAN, Rect2(718, 68, 430, 430), CYAN, 0.16, 2.1)
	_add_ghost(PERSONA_JOHNNY, Rect2(1002, -46, 404, 404), POSTER_YELLOW, 0.18, 4.2)

	_hero = TextureRect.new()
	_hero.texture = HOME_CHASSIS
	_hero.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_material = ShaderMaterial.new()
	var hero_shader := Shader.new()
	hero_shader.code = """
shader_type canvas_item;
uniform float pulse = 1.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float cyan = smoothstep(0.10, 0.34, ((tex.g + tex.b) * 0.5) - tex.r);
	float plane = smoothstep(0.28, 0.92, dot(tex.rgb, vec3(0.299, 0.587, 0.114)));
	vec3 ink = mix(vec3(0.012, 0.016, 0.019), vec3(0.085, 0.09, 0.088), plane * 0.42);
	vec3 signal = vec3(0.18, 1.0, 0.92) * (0.72 + 0.28 * pulse);
	COLOR = vec4(mix(ink, signal, cyan), tex.a);
}
"""
	_hero_material.shader = hero_shader
	_hero.material = _hero_material
	place(_hero, Rect2(632, -18, 690, 758), _home_art)
	_hero_base = _hero.position

	_weapon = TextureRect.new()
	_weapon.texture = HOME_WEAPON
	_weapon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_weapon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_weapon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_weapon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_weapon.modulate = Color(0.31, 0.39, 0.4, 0.42)
	place(_weapon, Rect2(528, 430, 828, 214), _home_art)
	_weapon.pivot_offset = _weapon.size * 0.5
	_weapon.rotation = deg_to_rad(-5.5)

	for definition in [
		[Vector2(855, 135), 0.2], [Vector2(902, 211), 1.1],
		[Vector2(1018, 155), 2.3], [Vector2(1088, 286), 3.4],
		[Vector2(1168, 117), 4.6], [Vector2(1216, 238), 5.3],
	]:
		var light := ColorRect.new()
		light.color = Color(1.0, 0.78, 0.25, 0.0)
		light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		place(light, Rect2(definition[0], Vector2(4, 8)), _home_art)
		_window_lights.append({"node": light, "phase": definition[1]})


func _add_ghost(texture: Texture2D, rect: Rect2, tint: Color, opacity: float, phase: float) -> void:
	var echo := TextureRect.new()
	echo.texture = texture
	echo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	echo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	echo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	echo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	echo.modulate = Color(tint.r, tint.g, tint.b, opacity * 0.28)
	place(echo, Rect2(rect.position + Vector2(9, 1), rect.size), _home_art)
	_ghost_layers.append({
		"node": echo,
		"base": echo.position,
		"alpha": opacity * 0.28,
		"phase": phase + 0.14,
		"echo": true,
	})

	var portrait := TextureRect.new()
	portrait.texture = texture
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.modulate = Color(tint.r, tint.g, tint.b, opacity)
	place(portrait, rect, _home_art)
	_ghost_layers.append({
		"node": portrait,
		"base": portrait.position,
		"alpha": opacity,
		"phase": phase,
		"echo": false,
	})


func _process(delta: float) -> void:
	if _home_art == null or not _home_art.visible:
		return
	_home_time += delta
	for layer in _ghost_layers:
		var ghost := layer.node as TextureRect
		var phase: float = layer.phase
		var drift := Vector2(sin(_home_time * 0.31 + phase) * 2.2, cos(_home_time * 0.23 + phase) * 1.6)
		var glitch := fmod(_home_time + phase * 1.7, 8.0) < 0.09
		if glitch:
			drift.x += 7.0 if layer.echo else -4.0
		ghost.position = layer.base + drift
		ghost.modulate.a = layer.alpha * (0.88 + sin(_home_time * 0.42 + phase) * 0.12) * _ghost_reveal()
	if _hero_material != null:
		_hero_material.set_shader_parameter("pulse", 0.82 + sin(_home_time * 1.15) * 0.18)
	for definition in _window_lights:
		var light := definition.node as ColorRect
		var brightness := maxf(0.0, sin(_home_time * 0.7 + float(definition.phase)))
		light.color.a = brightness * 0.48 * _background_reveal()


func _background_reveal() -> float:
	return clampf(_reveal_progress / 0.34, 0.0, 1.0)


func _ghost_reveal() -> float:
	return clampf((_reveal_progress - 0.18) / 0.38, 0.0, 1.0)


func _hero_reveal() -> float:
	return clampf((_reveal_progress - 0.34) / 0.34, 0.0, 1.0)


func _content_reveal() -> float:
	return clampf((_reveal_progress - 0.68) / 0.32, 0.0, 1.0)


func _set_reveal_progress(value: float) -> void:
	_reveal_progress = value
	if _home_background != null:
		_home_background.modulate.a = _background_reveal()
	if _hero != null:
		var hero_amount := _hero_reveal()
		_hero.modulate.a = hero_amount
		_hero.position = _hero_base + Vector2(42.0 * (1.0 - hero_amount), 0.0)
	if _weapon != null:
		_weapon.modulate.a = 0.42 * _hero_reveal()
	if _content != null:
		_content.modulate.a = _content_reveal()


func _play_home_reveal() -> void:
	if _reveal_played:
		_set_reveal_progress(1.0)
		return
	_reveal_played = true
	_reveal_active = true
	_set_reveal_progress(0.0)
	_reveal_tween = create_tween()
	_reveal_tween.tween_method(_set_reveal_progress, 0.0, 1.0, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_reveal_tween.finished.connect(func() -> void: _reveal_active = false)


func _finish_home_reveal() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_active = false
	_set_reveal_progress(1.0)


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


func _home_button(value: String, rect: Rect2, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = value
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", CyberUITheme.FONT)
	button.add_theme_font_size_override("font_size", 27)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var highlighted: bool = state in ["hover", "focus", "pressed"]
		var style := StyleBoxFlat.new()
		style.bg_color = CYAN if highlighted else Color(0.015, 0.02, 0.025, 0.7)
		style.border_color = Color("0b1114") if highlighted else Color(0.95, 0.95, 0.9, 0.62)
		style.border_width_left = 9 if highlighted else 4
		style.border_width_bottom = 2 if highlighted else 0
		style.content_margin_left = 20
		style.content_margin_right = 16
		button.add_theme_stylebox_override(state, style)
		var color := Color("111318") if highlighted else LIGHT
		if state == "disabled":
			color = Color("657078")
		button.add_theme_color_override("font_" + state + "_color" if state != "normal" else "font_color", color)
	button.add_theme_color_override("font_disabled_color", Color("657078"))
	button.pressed.connect(action)
	place(button, rect, _content)
	if primary:
		button.grab_focus()
	return button


func _home_title() -> void:
	var edition := _label("WUJIAOCHANG HOTLINE", 14, CYAN)
	edition.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	edition.add_theme_constant_override("shadow_offset_x", 2)
	edition.add_theme_constant_override("shadow_offset_y", 2)
	place(edition, Rect2(4, 18, 500, 24), _content)

	var title_shadow := _label("五角场热线", 76, POSTER_RED)
	title_shadow.add_theme_color_override("font_outline_color", Color("090b0d"))
	title_shadow.add_theme_constant_override("outline_size", 7)
	place(title_shadow, Rect2(10, 56, 510, 104), _content)
	var title := _label("五角场热线", 76, Color("f4f1e8"))
	title.add_theme_color_override("font_outline_color", Color("090b0d"))
	title.add_theme_constant_override("outline_size", 4)
	place(title, Rect2(0, 48, 510, 104), _content)

	var signal_bar := ColorRect.new()
	signal_bar.color = POSTER_ORANGE
	signal_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(signal_bar, Rect2(2, 166, 320, 8), _content)
	var signal_tip := ColorRect.new()
	signal_tip.color = CYAN
	signal_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place(signal_tip, Rect2(330, 166, 76, 8), _content)


func _clear_page(next_page: String) -> void:
	page = next_page
	var is_home := next_page == "home"
	_home_art.visible = is_home
	_legacy_art.visible = not is_home
	_content.position = Vector2(72, 42) if is_home else Vector2(96, 72)
	_content.size = Vector2(520, 636) if is_home else Vector2(520, 576)
	if not is_home and _reveal_active:
		_finish_home_reveal()
	_content.modulate.a = 1.0
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
	_home_title()
	var valid: bool = store.load_profile()
	var exists: bool = store.has_saved_profile()
	_continue = _home_button("继续游戏", Rect2(0, 292, 392, 58), continue_game, true)
	_continue.disabled = not exists or not valid
	var new_game := _home_button("开始新存档", Rect2(0, 360, 392, 58), show_difficulty)
	_home_button("退出游戏", Rect2(0, 428, 392, 58), func() -> void: get_tree().quit())
	var summary := "暂无存档"
	if exists and valid:
		var profile: Dictionary = store.get_profile()
		summary = "仓库装备 %d 件" % profile.chest.size()
	elif not valid:
		summary = store.error_message + "；可开始新存档。"
	_status = _label(summary, 17, MUTED if valid else AMBER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	place(_status, Rect2(20, 520, 460, 64), _content)
	if not _continue.disabled:
		_continue.grab_focus()
	else:
		new_game.grab_focus()
	_play_home_reveal()


func show_difficulty() -> void:
	_clear_page("difficulty")
	place(_label("选择难度", 36, LIGHT), Rect2(0, 70, 460, 64), _content)
	place(_label("仅影响敌人的感知与支援范围", 18, MUTED), Rect2(0, 148, 490, 40), _content)
	_button("低压", Rect2(0, 218, 360, 48), _select_difficulty.bind("low_pressure"))
	var standard := _button("标准", Rect2(0, 282, 360, 48), _select_difficulty.bind("standard"), true)
	_button("高压", Rect2(0, 346, 360, 48), _select_difficulty.bind("high_pressure"))
	_button("返回", Rect2(0, 440, 200, 48), show_home)
	standard.grab_focus()


func _select_difficulty(difficulty: String) -> void:
	_difficulty = difficulty
	show_character()


func show_character() -> void:
	if _busy:
		return
	_clear_page("character")
	_heading("标准机体")
	place(_label("携带制式手枪出发，当前难度：" + {"low_pressure": "低压", "standard": "标准", "high_pressure": "高压"}.get(_difficulty, "标准"), 21, MUTED), Rect2(0, 190, 460, 38), _content)
	_button("开始行动", Rect2(0, 342, 360, 60), request_new_game, true)
	var back := _button("返回", Rect2(0, 420, 200, 48), show_difficulty)
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
	if not store.create_new_profile(_difficulty):
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
	var difficulty: String = store.get_profile().get("difficulty", ["low_pressure", "standard", "high_pressure"][int(get_node("/root/GameSettings").difficulty)])
	get_node("/root/GameSettings").set_difficulty(["low_pressure", "standard", "high_pressure"].find(difficulty) as GameSettingsController.Difficulty, false)
	get_node("/root/RunManager").begin_run()
	get_node("/root/RunManager").set_scene_payload({})
	_stop_lobby_music()
	var error := get_tree().change_scene_to_file(WAREHOUSE)
	if error != OK:
		_busy = false
		show_home()
		_play_lobby_music()
		_status.text = "无法进入仓库，请重试。"


func _unhandled_input(event: InputEvent) -> void:
	var skip_reveal: bool = (
		(event is InputEventKey and event.pressed)
		or (event is InputEventMouseButton and event.pressed)
		or (event is InputEventJoypadButton and event.pressed)
	)
	if _reveal_active and skip_reveal:
		_finish_home_reveal()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and not _busy:
		if page == "confirm":
			show_character()
		elif page == "character":
			show_difficulty()
		elif page == "difficulty":
			show_home()
