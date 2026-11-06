class_name CyberUITheme
extends RefCounted

const BACKGROUND := Color("0a121d")
const PANEL := Color("12212de8")
# Legacy names remain for existing callers; the shared interface now uses
# industrial cyan rather than a full-screen green phosphor palette.
const PHOSPHOR := Color("74d9e9")
const DIM_GREEN := Color("355666")
const HIGHLIGHT := Color("edf7f9")
const WARNING := Color("ffc857")
const DANGER := Color("ff4055")
const MUTED := Color("9cb2bf")
const FONT: Font = preload("res://resources/ui/tactical_chinese_font.tres")
const PIXEL_FONT: Font = preload("res://resources/ui/chinese_font_12.tres")
const OS_FRAME: Texture2D = preload("res://assets/art/ui/os_hud/shared_os_frame_v2.png")


static func create_theme() -> Theme:
	var result := Theme.new()
	result.default_font = FONT
	result.default_font_size = 13
	for type_name in [&"Label", &"Button", &"CheckButton", &"OptionButton", &"LineEdit", &"PopupMenu"]:
		result.set_color(&"font_color", type_name, PHOSPHOR)
		result.set_color(&"font_hover_color", type_name, HIGHLIGHT)
		result.set_color(&"font_pressed_color", type_name, HIGHLIGHT)
		result.set_color(&"font_focus_color", type_name, HIGHLIGHT)
		result.set_color(&"font_disabled_color", type_name, Color(MUTED, 0.48))
	result.set_color(&"font_outline_color", &"Label", Color(BACKGROUND, 0.95))
	result.set_constant(&"outline_size", &"Label", 1)
	result.set_stylebox(&"normal", &"Button", _box(Color(PANEL, 0.92), Color(DIM_GREEN, 0.6)))
	result.set_stylebox(&"hover", &"Button", _box(Color(PHOSPHOR, 0.13), PHOSPHOR))
	result.set_stylebox(&"pressed", &"Button", _box(Color(PHOSPHOR, 0.22), HIGHLIGHT, 2))
	result.set_stylebox(&"focus", &"Button", _box(Color.TRANSPARENT, PHOSPHOR, 2))
	result.set_stylebox(&"disabled", &"Button", _box(Color(PANEL, 0.45), Color(DIM_GREEN, 0.45)))
	for type_name in [&"CheckButton", &"OptionButton", &"LineEdit", &"PopupMenu"]:
		result.set_stylebox(&"normal", type_name, _box(Color(PANEL, 0.94), Color(DIM_GREEN, 0.65)))
		result.set_stylebox(&"hover", type_name, _box(Color(PHOSPHOR, 0.08), PHOSPHOR))
		result.set_stylebox(&"focus", type_name, _box(Color.TRANSPARENT, PHOSPHOR, 2))
	result.set_stylebox(&"slider", &"HSlider", _box(Color(DIM_GREEN, 0.45), DIM_GREEN))
	result.set_stylebox(&"grabber_area", &"HSlider", _box(Color(PHOSPHOR, 0.65), PHOSPHOR))
	result.set_stylebox(&"grabber_area_highlight", &"HSlider", _box(Color(HIGHLIGHT, 0.8), HIGHLIGHT))
	result.set_stylebox(&"panel", &"TabContainer", _box(Color(PANEL, 0.72), Color(DIM_GREEN, 0.55)))
	result.set_stylebox(&"tab_selected", &"TabContainer", _box(Color(PHOSPHOR, 0.17), PHOSPHOR))
	result.set_stylebox(&"tab_hovered", &"TabContainer", _box(Color(PHOSPHOR, 0.08), DIM_GREEN))
	result.set_stylebox(&"tab_unselected", &"TabContainer", _box(Color(BACKGROUND, 0.65), Color(DIM_GREEN, 0.55)))
	result.set_color(&"font_selected_color", &"TabContainer", HIGHLIGHT)
	result.set_color(&"font_unselected_color", &"TabContainer", MUTED)
	result.set_type_variation(&"TerminalWarningLabel", &"Label")
	result.set_color(&"font_color", &"TerminalWarningLabel", WARNING)
	result.set_type_variation(&"TerminalDangerLabel", &"Label")
	result.set_color(&"font_color", &"TerminalDangerLabel", DANGER)
	result.set_type_variation(&"TerminalMutedLabel", &"Label")
	result.set_color(&"font_color", &"TerminalMutedLabel", MUTED)
	return result


static func create_os_theme() -> Theme:
	var result := create_theme()
	result.default_font_size = 9
	var amber := Color("e7ac62")
	var ink := Color("e6e1d8")
	for type_name in [&"Label", &"Button", &"CheckButton", &"OptionButton", &"PopupMenu"]:
		result.set_color(&"font_color", type_name, ink)
		result.set_color(&"font_hover_color", type_name, amber)
		result.set_color(&"font_pressed_color", type_name, amber)
		result.set_color(&"font_disabled_color", type_name, Color("aaa9a4"))
	var clear := StyleBoxEmpty.new()
	for type_name in [&"Button", &"OptionButton", &"CheckButton"]:
		result.set_stylebox(&"normal", type_name, clear)
		result.set_stylebox(&"focus", type_name, clear)
		result.set_stylebox(&"pressed", type_name, clear)
		result.set_stylebox(&"hover", type_name, clear)
		result.set_stylebox(&"disabled", type_name, clear)
	result.set_stylebox(&"panel", &"TabContainer", clear)
	return result


static func add_os_frame(parent: Control, inset: float = 0.0) -> TextureRect:
	var frame := TextureRect.new()
	frame.name = "OSFrameArt"
	frame.texture = OS_FRAME
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = inset
	frame.offset_top = inset
	frame.offset_right = -inset
	frame.offset_bottom = -inset
	return frame


static func create_box(fill: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	return _box(fill, border, width)


static func _box(fill: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(width)
	box.set_content_margin_all(5.0)
	box.corner_radius_top_left = 0
	box.corner_radius_top_right = 0
	box.corner_radius_bottom_left = 0
	box.corner_radius_bottom_right = 0
	return box
