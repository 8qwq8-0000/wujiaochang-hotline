class_name CombatSceneryPiece
extends Node2D

## Each piece sorts by its ground-contact point alongside actors.
var footprint := Rect2()
var direction := "north"
var prop := ""
var corner := ""

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _draw() -> void:
	if not corner.is_empty():
		draw_texture_rect(CombatArchitecture.texture(corner), footprint, false)
	elif not prop.is_empty():
		var source := WorkshopArt.asset(prop)
		var width := footprint.size.x
		var height := clampf(width * source.get_height() / source.get_width(), footprint.size.y + 8, footprint.size.y + 30)
		draw_texture_rect(source, Rect2(footprint.position.x, footprint.end.y - height, width, height), false)
	else:
		CombatArchitecture.wall(self, footprint, direction)
