class_name ChannelTerminal
extends Area2D

const ART := preload("res://assets/art/environment/warehouse/terminal.png")
var title := "通信终端"
var action: Callable
var enabled := true
var highlighted := false
var accent := Color("75e8df")
var _label: Label


func _ready() -> void:
	collision_layer = 32
	collision_mask = 0
	monitoring = false
	var shape := CircleShape2D.new()
	shape.radius = 24
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	_label = Label.new()
	_label.theme = CyberUITheme.create_theme()
	_label.position = Vector2(-112, -58)
	_label.size = Vector2(224, 42)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_outline_color", Color("061018"))
	_label.add_theme_constant_override("outline_size", 3)
	_label.z_index = 40
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _process(_delta: float) -> void:
	var actor := get_tree().get_first_node_in_group("player") as PlayerController
	_label.text = title + ("\n[E] 操作" if enabled and actor != null and actor.global_position.distance_to(global_position) < 78 else "")
	queue_redraw()


func can_interact(actor: Node2D) -> bool:
	return enabled and not get_tree().paused and actor is PlayerController and actor.is_input_enabled() and not actor.health.is_dead() and actor.global_position.distance_to(global_position) < 78


func interact(actor: Node2D) -> void:
	if can_interact(actor) and action.is_valid():
		action.call()


func _draw() -> void:
	var color := accent if enabled or highlighted else Color("52616a")
	draw_texture_rect_region(ART, Rect2(-24, -24, 48, 40), Rect2(137, 208, 1021, 844), Color.WHITE if enabled or highlighted else Color(0.6, 0.65, 0.7))
	draw_line(Vector2(-20, 20), Vector2(20, 20), color, 2)
	if highlighted:
		for index in 12:
			var angle := float(index) / 12 * TAU
			draw_arc(Vector2.ZERO, 72, angle, angle + 0.28, 8, Color(color, 0.65), 1.5)
