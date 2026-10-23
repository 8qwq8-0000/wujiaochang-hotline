class_name ExitElevator
extends Area2D

signal entered
signal exited

@export var show_exit_art := true
var enabled: bool = false
var _door_art: Sprite2D
var _sigil: Sprite2D


func _ready() -> void:
	var texture := AtlasTexture.new()
	texture.atlas = preload("res://assets/art/environment/warehouse/elevator_east_v3.png")
	texture.region = Rect2(148, 75, 652, 1717)
	_door_art = Sprite2D.new()
	_door_art.name = "DoorArt"
	_door_art.texture = texture
	_door_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_door_art.position = Vector2(19.3, -6)
	_door_art.scale = Vector2.ONE * 0.051252183
	_door_art.visible = show_exit_art
	add_child(_door_art)
	_sigil = preload("res://scripts/presentation/warehouse_door_sigil.gd").new()
	_sigil.name = "DoorSigil"
	_sigil.texture = preload("res://assets/art/effects/warehouse_sigils/deploy_complete.png")
	_sigil.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sigil.scale = Vector2.ONE * 0.225
	# Place the projection slightly lower, at the entry step.
	_sigil.position = Vector2(22, 14)
	_sigil.visible = show_exit_art
	call_deferred("_clip_sigil_to_room")
	add_child(_sigil)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_art()


func _clip_sigil_to_room() -> void:
	if get_parent() is CombatRoom:
		# The full warehouse projection must stop at the room's inner wall.
		# Keep the original sprite origin while cropping only the exterior side.
		var source_size := _sigil.texture.get_size()
		var wall_x := CombatRoom.ROOM_SIZE.x - 16.0
		var visible_width := clampf((wall_x - position.x - _sigil.position.x) / _sigil.scale.x + source_size.x * 0.5, 0, source_size.x)
		_sigil.region_enabled = true
		_sigil.region_filter_clip_enabled = true
		_sigil.region_rect = Rect2(Vector2.ZERO, Vector2(visible_width, source_size.y))
		_sigil.offset.x = (visible_width - source_size.x) * 0.5


func set_enabled(value: bool) -> void:
	enabled = value
	monitoring = value
	_update_art()
	var label := get_node_or_null("Label") as Label
	if label != null:
		label.text = "出口可用" if value else "清除必杀目标"


func can_interact(actor: Node2D) -> bool:
	return enabled and is_instance_valid(actor) and global_position.distance_to(actor.global_position) <= 70.0


func _update_art() -> void:
	if is_instance_valid(_door_art):
		_door_art.modulate = Color.WHITE if enabled else Color(0.48, 0.48, 0.48)
	if is_instance_valid(_sigil):
		_sigil.modulate = Color.WHITE if enabled else Color(0.45, 0.3, 0.2)
	if not show_exit_art:
		var label := get_node_or_null("Label") as Label
		if label != null:
			label.visible = enabled


func _on_body_entered(body: Node) -> void:
	if enabled and body.is_in_group("player"):
		entered.emit()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		exited.emit()
