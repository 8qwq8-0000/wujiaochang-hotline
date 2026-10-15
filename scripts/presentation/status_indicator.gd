extends Node2D

@export var statuses_path: NodePath = NodePath("../StatusComponent")
@onready var statuses: Node = get_node(statuses_path)
var label: Label
func _ready() -> void:
	z_index = 15
	label = Label.new()
	label.position = Vector2(-44,-37)
	label.size.x = 88
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",11)
	label.add_theme_color_override("font_color",Color("80e8ff"))
	label.add_theme_color_override("font_outline_color",Color.BLACK)
	label.add_theme_constant_override("outline_size",3)
	add_child(label)
	visible = false
func _process(_delta: float) -> void:
	var lines: PackedStringArray = []
	for entry in [[&"conductive","导电"],[&"oiled","浸油"],[&"burning","燃烧"],[&"knocked_down","击倒"]]:
		if statuses.has_status(entry[0]):
			lines.append("%s %.1fs" % [entry[1],statuses.remaining_seconds(entry[0])])
	visible = not lines.is_empty()
	label.text = "\n".join(lines)
	label.position.y = -37 - maxi(lines.size()-1,0)*14
	queue_redraw()
func _draw() -> void:
	if statuses.has_status(&"conductive"):
		draw_arc(Vector2.ZERO,16,0,TAU,24,Color("62d8ef"),2)
	if statuses.has_status(&"oiled"):
		draw_arc(Vector2.ZERO,19,0,TAU,24,Color("c4a550"),3)
	if statuses.has_status(&"burning"):
		draw_arc(Vector2.ZERO,21,0,TAU,24,Color("ff873a"),3)
		draw_colored_polygon(PackedVector2Array([Vector2(-5,-8),Vector2(0,-25),Vector2(7,-8)]),Color("ffcf69"))
	if statuses.has_status(&"knocked_down"):
		draw_arc(Vector2(0,-16),10,0,TAU,18,Color("f4d779"),2)
