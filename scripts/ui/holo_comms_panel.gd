class_name HoloCommsPanel
extends Control

const COLLAPSED_SIZE := Vector2(72.0, 72.0)
const EXPANDED_SIZE := Vector2(304.0, 72.0)

var accent_color := Color("55d9ff")
var _portrait: TextureRect
var _name_label: Label
var _dialogue_label: Label
var _text_root: Control
var _expanded := false
var _armed := false
var _spent := false
var _pulse_time := 0.0
var _size_tween: Tween


func _ready() -> void:
	custom_minimum_size = COLLAPSED_SIZE
	size = COLLAPSED_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_build_contents()
	set_process(true)


func _process(delta: float) -> void:
	_pulse_time += delta
	queue_redraw()


func set_persona(texture: Texture2D, display_name: String, color: Color) -> void:
	_portrait.texture = texture
	_name_label.text = display_name
	accent_color = color
	_name_label.add_theme_color_override("font_color", color)
	queue_redraw()


func set_message(text: String) -> void:
	_dialogue_label.text = text


func set_takeover_state(charges: int, armed: bool) -> void:
	_spent = charges <= 0
	_armed = armed and not _spent
	queue_redraw()


func set_expanded(value: bool, animate: bool = true) -> void:
	if animate and _expanded == value and ((_text_root.visible and value) or (not _text_root.visible and not value)):
		return
	_expanded = value
	if _size_tween != null and _size_tween.is_valid():
		_size_tween.kill()
	var target := EXPANDED_SIZE if value else COLLAPSED_SIZE
	if value:
		_text_root.show()
	if not animate:
		custom_minimum_size = target
		size = target
		_text_root.modulate.a = 1.0 if value else 0.0
		_text_root.visible = value
		queue_redraw()
		return
	_size_tween = create_tween().set_parallel(true)
	_size_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_size_tween.tween_property(self, "custom_minimum_size", target, 0.16)
	_size_tween.tween_property(self, "size", target, 0.16)
	_size_tween.tween_property(_text_root, "modulate:a", 1.0 if value else 0.0, 0.12)
	# Control minimum-size updates can clamp a simultaneous size tween. Snap
	# both after layout settles so collapse always reaches the portrait width.
	_size_tween.chain().tween_callback(func() -> void:
		custom_minimum_size = target
		size = target
	)
	if not value:
		_size_tween.chain().tween_callback(_text_root.hide)


func is_expanded() -> bool:
	return _expanded


func _build_contents() -> void:
	_portrait = TextureRect.new()
	_portrait.position = Vector2(5.0, 5.0)
	_portrait.size = Vector2(62.0, 62.0)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait)

	_text_root = Control.new()
	_text_root.position = Vector2(72.0, 0.0)
	_text_root.size = Vector2(232.0, 72.0)
	_text_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_root.modulate.a = 0.0
	_text_root.hide()
	add_child(_text_root)

	_name_label = Label.new()
	_name_label.position = Vector2(10.0, 5.0)
	_name_label.size = Vector2(214.0, 18.0)
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_root.add_child(_name_label)

	_dialogue_label = Label.new()
	_dialogue_label.position = Vector2(10.0, 25.0)
	_dialogue_label.size = Vector2(214.0, 42.0)
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_label.max_lines_visible = 2
	_dialogue_label.add_theme_font_size_override("font_size", 13)
	_dialogue_label.add_theme_color_override("font_color", Color("e9f8f4"))
	_dialogue_label.add_theme_color_override("font_outline_color", Color("071017"))
	_dialogue_label.add_theme_constant_override("outline_size", 2)
	_dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_root.add_child(_dialogue_label)


func _draw() -> void:
	var frame_color := Color(CyberUITheme.MUTED, 0.55) if _spent else accent_color
	if _armed:
		frame_color.a = 0.62 + sin(_pulse_time * 4.0) * 0.3
	var cut := 6.0
	var points := PackedVector2Array([
		Vector2(0.0, cut), Vector2(cut, 0.0), Vector2(size.x - cut, 0.0),
		Vector2(size.x, cut), Vector2(size.x, size.y - cut), Vector2(size.x - cut, size.y),
		Vector2(cut, size.y), Vector2(0.0, size.y - cut), Vector2(0.0, cut),
	])
	draw_colored_polygon(points, Color("071017", 0.82))
	draw_polyline(points, frame_color, 1.0, false)
	draw_line(Vector2(71.0, 5.0), Vector2(71.0, 67.0), Color(frame_color, 0.8), 1.0)
	if _expanded:
		draw_line(Vector2(80.0, 23.0), Vector2(size.x - 8.0, 23.0), Color(frame_color, 0.55), 1.0)
	for y in range(8, 66, 6):
		draw_line(Vector2(6.0, y), Vector2(66.0, y), Color(frame_color, 0.08), 1.0)
	if _spent:
		draw_line(Vector2(9.0, 9.0), Vector2(63.0, 63.0), Color(CyberUITheme.MUTED, 0.55), 2.0)
