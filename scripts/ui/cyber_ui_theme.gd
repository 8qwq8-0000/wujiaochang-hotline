class_name CyberUITheme
extends RefCounted

const BACKGROUND := Color("04100d")
const PANEL := Color("071a16e8")
const PHOSPHOR := Color("72ff9a")
const DIM_GREEN := Color("286b45")
const HIGHLIGHT := Color("d8ffe2")
const WARNING := Color("ffc857")
const DANGER := Color("ff4055")
const MUTED := Color("7fa890")
const FONT: Font = preload("res://resources/ui/chinese_font_12.tres")


static func create_theme() -> Theme:
	var result := Theme.new()
	result.default_font = FONT
	result.default_font_size = 12
	for type_name in [&"Label", &"Button", &"CheckButton", &"OptionButton", &"LineEdit", &"PopupMenu"]:
		result.set_color(&"font_color", type_name, PHOSPHOR)
		result.set_color(&"font_hover_color", type_name, HIGHLIGHT)
		result.set_color(&"font_pressed_color", type_name, HIGHLIGHT)
		result.set_color(&"font_focus_color", type_name, HIGHLIGHT)
		result.set_color(&"font_disabled_color", type_name, Color(MUTED, 0.48))
	result.set_color(&"font_outline_color", &"Label", Color(BACKGROUND, 0.95))
	result.set_constant(&"outline_size", &"Label", 1)
	result.set_stylebox(&"normal", &"Button", _box(Color(PANEL, 0.82), DIM_GREEN))
	result.set_stylebox(&"hover", &"Button", _box(Color(PHOSPHOR, 0.08), PHOSPHOR))
	result.set_stylebox(&"pressed", &"Button", _box(Color(PHOSPHOR, 0.16), HIGHLIGHT, 2))
	result.set_stylebox(&"focus", &"Button", _box(Color.TRANSPARENT, PHOSPHOR, 2))
	result.set_stylebox(&"disabled", &"Button", _box(Color(PANEL, 0.45), Color(DIM_GREEN, 0.45)))
	for type_name in [&"CheckButton", &"OptionButton", &"LineEdit", &"PopupMenu"]:
		result.set_stylebox(&"normal", type_name, _box(Color(PANEL, 0.86), DIM_GREEN))
		result.set_stylebox(&"hover", type_name, _box(Color(PHOSPHOR, 0.08), PHOSPHOR))
		result.set_stylebox(&"focus", type_name, _box(Color.TRANSPARENT, PHOSPHOR, 2))
	result.set_stylebox(&"slider", &"HSlider", _box(Color(DIM_GREEN, 0.45), DIM_GREEN))
	result.set_stylebox(&"grabber_area", &"HSlider", _box(Color(PHOSPHOR, 0.65), PHOSPHOR))
	result.set_stylebox(&"grabber_area_highlight", &"HSlider", _box(Color(HIGHLIGHT, 0.8), HIGHLIGHT))
	result.set_type_variation(&"TerminalWarningLabel", &"Label")
	result.set_color(&"font_color", &"TerminalWarningLabel", WARNING)
	result.set_type_variation(&"TerminalDangerLabel", &"Label")
	result.set_color(&"font_color", &"TerminalDangerLabel", DANGER)
	result.set_type_variation(&"TerminalMutedLabel", &"Label")
	result.set_color(&"font_color", &"TerminalMutedLabel", MUTED)
	return result


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
