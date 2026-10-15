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
	visible = statuses.has_status(&"conductive")
	if visible:
		label.text = "导电 %.1fs" % statuses.remaining_seconds(&"conductive")
		queue_redraw()
func _draw() -> void:
	draw_arc(Vector2.ZERO,16,0,TAU,24,Color("62d8ef"),2)
	draw_line(Vector2(-3,-12),Vector2(2,-3),Color("fff2a2"),2)
	draw_line(Vector2(2,-3),Vector2(-2,5),Color("fff2a2"),2)
