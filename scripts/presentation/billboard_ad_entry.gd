class_name BillboardAdEntry
extends Resource

enum Layout {
	PORTRAIT,
	SQUARE,
	LANDSCAPE,
}

@export var id: StringName
@export var texture: Texture2D
@export var layout := Layout.LANDSCAPE
@export var focus_point := Vector2(0.5, 0.5)
@export var approved := false


func is_ready_for_rotation() -> bool:
	return approved and not id.is_empty() and texture != null
