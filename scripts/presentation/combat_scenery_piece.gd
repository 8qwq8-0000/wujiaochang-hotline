class_name CombatSceneryPiece
extends Node2D

## Each piece sorts by its ground-contact point alongside actors.
var footprint := Rect2()
var direction := "north"
var prop := ""
var corner := ""
var fixture: Texture2D
var flip_fixture := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _draw() -> void:
	if not corner.is_empty():
		draw_texture_rect(CombatArchitecture.texture(corner), footprint, false)
	elif fixture != null or not prop.is_empty():
		var source := fixture if fixture != null else WorkshopArt.asset(prop)
		var width := footprint.size.x
		var height := clampf(width * source.get_height() / source.get_width(), footprint.size.y + 8, footprint.size.y + 30)
		if flip_fixture:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
		draw_texture_rect(source, Rect2(footprint.position.x, footprint.end.y - height, width, height), false)
		if flip_fixture:
			draw_set_transform(Vector2.ZERO)
	else:
		CombatArchitecture.wall(self, footprint, direction)
