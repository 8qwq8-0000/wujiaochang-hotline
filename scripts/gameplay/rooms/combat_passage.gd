class_name CombatPassage
extends Node2D

var unlocked := false
var length := 72.0
var _barrier: CollisionShape2D
var _label: Label
var _link: NavigationLink2D


func _ready() -> void:
	for y in [-44.0, 44.0]:
		_add_wall(Vector2(length / 2, y), Vector2(length, 8))
	_barrier = _add_wall(Vector2(length / 2, 0), Vector2(8, 80))
	_label = Label.new()
	_label.position = Vector2(-30, -72)
	_label.add_theme_font_size_override("font_size", 12)
	_label.text = "清场后通行"
	add_child(_label)
	_link = NavigationLink2D.new()
	_link.start_position = Vector2(-12, 0)
	_link.end_position = Vector2(length + 12, 0)
	_link.enabled = false
	add_child(_link)
	queue_redraw()


func _add_wall(point: Vector2, size: Vector2) -> CollisionShape2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = point
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	return collider


func unlock() -> void:
	if unlocked:
		return
	unlocked = true
	_barrier.set_deferred("disabled", true)
	_link.enabled = true
	_label.text = "前往下一区 →"
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, -48, length, 96), Color("172934"))
	for y in [-48.0, 40.0]:
		draw_rect(Rect2(0, y, length, 8), Color("45596c"))
	if not unlocked:
		draw_line(Vector2(length / 2, -40), Vector2(length / 2, 40), Color("e37662"), 5)
	else:
		draw_line(Vector2(10, 0), Vector2(length - 10, 0), Color("83e6ad"), 3)
		draw_line(Vector2(length - 10, 0), Vector2(length - 21, -8), Color("83e6ad"), 3)
		draw_line(Vector2(length - 10, 0), Vector2(length - 21, 8), Color("83e6ad"), 3)
