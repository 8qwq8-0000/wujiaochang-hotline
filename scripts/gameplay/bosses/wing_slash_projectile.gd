class_name WingSlashProjectile
extends Area2D

const ROOK_TEXTURE := preload("res://assets/art/effects/boss/rook_slash_arc.png")
const QUEEN_TEXTURE := preload("res://assets/art/effects/boss/queen_slash_arc.png")

var owner_guard: WingGuard
var target_player: PlayerController
var travel := Vector2.RIGHT
var remaining := 64.0
var speed := 320.0
var struck := false


func launch(guard: WingGuard, player: PlayerController, direction: Vector2, cells: int) -> void:
	owner_guard = guard
	target_player = player
	travel = direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	remaining = float(cells) * BossFloorGeometry.CELL_SIZE
	global_position = guard.global_position + travel * 14.0
	rotation = travel.angle()
	collision_layer = 0
	collision_mask = 8
	monitoring = true
	var shape := CircleShape2D.new()
	shape.radius = 19.0 if cells == 2 else 24.0
	var hitbox := CollisionShape2D.new()
	hitbox.shape = shape
	add_child(hitbox)
	var sprite := Sprite2D.new()
	sprite.texture = ROOK_TEXTURE if cells == 2 else QUEEN_TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = Vector2(0.055, 0.055) if cells == 2 else Vector2(0.07, 0.07)
	add_child(sprite)
	area_entered.connect(_on_area_entered)
	get_tree().create_timer(0.45, false).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	var step := minf(speed * delta, remaining)
	global_position += travel * step
	remaining -= step
	var board := Rect2(BossFloorGeometry.ORIGIN, Vector2(24, 14) * BossFloorGeometry.CELL_SIZE)
	if remaining <= 0.0 or not board.has_point(global_position):
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if struck or not is_instance_valid(owner_guard) or not is_instance_valid(target_player):
		return
	if area == target_player.get_node_or_null("HurtBox"):
		struck = true
		owner_guard._hit_player(true, &"kinetic")
