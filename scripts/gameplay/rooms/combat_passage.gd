class_name CombatPassage
extends Node2D

var unlocked := false
var return_sealed := false
var length := 72.0
var _barrier: CollisionShape2D
var _label: Label
var _link: NavigationLink2D


func _ready() -> void:
	y_sort_enabled = true
	var floor_art := Node2D.new()
	floor_art.name = "PassageFloor"
	floor_art.z_index = -2
	add_child(floor_art)
	floor_art.draw.connect(func() -> void: WorkshopArt.draw_floor_tiles(floor_art, Rect2(0, -40, length, 80)))
	floor_art.queue_redraw()
	for definition in [[Rect2(0, -60, length, 20), "north"], [Rect2(0, 40, length, 14), "south"]]:
		var bounds: Rect2 = definition[0]
		_add_wall(bounds.get_center(), bounds.size)
		var wall := CombatSceneryPiece.new()
		wall.position = Vector2(length / 2, bounds.end.y)
		wall.footprint = Rect2(Vector2(-length / 2, -bounds.size.y), bounds.size)
		wall.direction = definition[1]
		add_child(wall)
	_barrier = _add_wall(Vector2(length / 2, 0), Vector2(8, 80))
	_label = Label.new()
	_label.name = "PassageSign"
	_label.theme = CyberUITheme.create_theme()
	_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_label.position = Vector2(-148, -84)
	_label.size = Vector2(140, 24)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.z_index = 10
	# Match the current HUD communication text.
	_label.add_theme_font_override("font", CyberUITheme.FONT)
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color("e9f8f4"))
	_label.add_theme_color_override("font_outline_color", Color("071017"))
	_label.add_theme_constant_override("outline_size", 2)
	_label.text = "清场后通行"
	add_child(_label)
	_link = NavigationLink2D.new()
	_link.start_position = Vector2(-24, 0)
	_link.end_position = Vector2(length + 24, 0)
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
	if unlocked or return_sealed:
		return
	unlocked = true
	_barrier.set_deferred("disabled", true)
	_link.enabled = true
	_label.text = "前往下一区 →"
	queue_redraw()


func seal_return() -> void:
	if return_sealed or not unlocked:
		return
	return_sealed = true
	_barrier.set_deferred("disabled", false)
	_link.enabled = false
	_label.text = "后方通道已封闭"
	queue_redraw()


func _draw() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not unlocked or return_sealed:
		draw_line(Vector2(length / 2, -40), Vector2(length / 2, 40), Color("e37662"), 5)
	else:
		draw_line(Vector2(10, 0), Vector2(length - 10, 0), Color("83e6ad"), 3)
		draw_line(Vector2(length - 10, 0), Vector2(length - 21, -8), Color("83e6ad"), 3)
		draw_line(Vector2(length - 10, 0), Vector2(length - 21, 8), Color("83e6ad"), 3)
