@tool
extends Node2D

## A saved scene layer, visible both in the 2D editor and in play mode.
func _draw() -> void:
	get_parent()._draw_foreground(self)
