class_name RedBloodStainLayer
extends Node2D

## Settled red pixels from the approved spray. No role tint, growth or fade.
const SPRAY := preload("res://scripts/presentation/death_blood_spray.gd")
@export_range(1, 128, 1) var stain_budget := 48
var _stains: Array[Sprite2D] = []

func spawn_stain(world_position: Vector2, _seed: int, _kind: int = 0, motion: Vector2 = Vector2.ZERO, impact: Vector2 = Vector2.ZERO) -> void:
	if _stains.size() >= stain_budget:
		var oldest: Sprite2D = _stains.pop_front()
		oldest.queue_free()
	var direction := impact if not impact.is_zero_approx() else motion
	var stain := Sprite2D.new()
	stain.texture = load("res://assets/art/effects/death_blood_spray_v1/stain_%02d.png" % SPRAY.sector_for(direction))
	stain.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stain.centered = false
	stain.offset = -SPRAY.ANCHOR
	stain.scale = Vector2.ONE * 0.75
	add_child(stain)
	stain.global_position = world_position + Vector2(0, -14)
	stain.add_to_group("red_blood_stains")
	_stains.append(stain)

func get_stain_count() -> int:
	return _stains.size()

func clear_stains() -> void:
	for stain in _stains:
		if is_instance_valid(stain):
			stain.queue_free()
	_stains.clear()
