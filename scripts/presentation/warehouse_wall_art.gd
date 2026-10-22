@tool
extends Node2D

## Real architecture draws over whole floor sprites, including doorway sigils.
func _draw() -> void:
	get_parent()._draw_walls(self)
