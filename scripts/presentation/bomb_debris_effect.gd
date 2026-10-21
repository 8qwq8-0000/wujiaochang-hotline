class_name BombDebrisEffect
extends Node2D

const SHEET := "res://assets/art/effects/bomb/debris_sheet_v1.png"
var settled_count := 0

func _ready() -> void:
	var source := load(SHEET) as Texture2D
	var cell := source.get_size() / Vector2(4, 2)
	var random := RandomNumberGenerator.new()
	random.seed = hash(global_position)
	for index in 8:
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = Rect2(Vector2(index % 4, index / 4) * cell, cell)
		var piece := Sprite2D.new()
		piece.name = "BombShard%d" % index
		piece.texture = atlas
		piece.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var size := random.randf_range(19, 29) if index < 5 else random.randf_range(12, 18)
		piece.scale = Vector2.ONE * size / cell.x
		piece.position = Vector2(random.randf_range(-6, 6), -10)
		piece.rotation = random.randf_range(-0.6, 0.6)
		piece.z_index = 5
		add_child(piece)
		var angle := index * TAU / 8.0 + random.randf_range(-0.3, 0.3)
		var distance := random.randf_range(22, 49)
		var ground := Vector2(cos(angle) * distance, sin(angle) * distance * 0.55 + 8)
		var peak := ground * 0.5 + Vector2(0, -random.randf_range(20, 33))
		var tween := piece.create_tween()
		tween.set_parallel(true)
		tween.tween_property(piece, "position", peak, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(piece, "rotation", random.randf_range(-2.2, 2.2), 0.16)
		tween.chain().tween_property(piece, "position", ground, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_callback(func() -> void:
			piece.z_as_relative = false
			piece.z_index = -1
			piece.modulate = Color(0.68, 0.68, 0.7)
			settled_count += 1
		)
