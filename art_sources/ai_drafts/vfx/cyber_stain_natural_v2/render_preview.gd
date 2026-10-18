extends SceneTree

const STAIN_LAYER_SCRIPT := preload("res://scripts/presentation/cyber_stain_layer.gd")
const OUTPUT_PATH := "res://art_sources/ai_drafts/vfx/cyber_stain_natural_v2/preview/stain_preview_v1.png"
const VIEW_SIZE := Vector2i(640, 360)


func _initialize() -> void:
	call_deferred("_render_preview")


func _render_preview() -> void:
	var viewport := SubViewport.new()
	viewport.size = VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)

	var background := ColorRect.new()
	background.color = Color("10141d")
	background.size = VIEW_SIZE
	viewport.add_child(background)
	_add_grid(viewport)
	_add_labels(viewport)
	_add_wall(viewport)

	var layer: CyberStainLayer = STAIN_LAYER_SCRIPT.new()
	layer.name = "PreviewStains"
	layer.obstacle_collision_mask = 1
	viewport.add_child(layer)

	await physics_frame
	var xs := [90.0, 240.0, 390.0, 544.0]
	var ys := [88.0, 180.0, 272.0]
	for role in 3:
		var row_seed := 11000 + role * 100
		layer.spawn_stain(Vector2(xs[0], ys[role]), row_seed + 1, role)
		layer.spawn_stain(
			Vector2(xs[1], ys[role]),
			row_seed + 2,
			role,
			Vector2.RIGHT,
			Vector2.RIGHT
		)
		layer.spawn_stain(
			Vector2(xs[2], ys[role]),
			row_seed + 3,
			role,
			Vector2.UP,
			Vector2.RIGHT
		)
		layer.spawn_stain(
			Vector2(xs[3] - 10.0, ys[role] + 4.0),
			row_seed + 4,
			role,
			Vector2.LEFT,
			Vector2.RIGHT
		)
		layer.spawn_stain(
			Vector2(xs[3], ys[role] - 3.0),
			row_seed + 5,
			role,
			Vector2.RIGHT,
			Vector2.RIGHT
		)
	layer._process(1.0)
	await process_frame
	await RenderingServer.frame_post_draw

	var absolute_output := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
	var error := viewport.get_texture().get_image().save_png(absolute_output)
	if error != OK:
		push_error("Failed to save stain preview: %s" % error_string(error))
		quit(1)
		return
	print("Saved stain preview to %s" % absolute_output)
	quit(0)


func _add_grid(viewport: SubViewport) -> void:
	for x in range(0, VIEW_SIZE.x + 1, 16):
		var line := ColorRect.new()
		line.position = Vector2(x, 0)
		line.size = Vector2(1, VIEW_SIZE.y)
		line.color = Color(0.12, 0.17, 0.23, 0.42)
		viewport.add_child(line)
	for y in range(0, VIEW_SIZE.y + 1, 16):
		var line := ColorRect.new()
		line.position = Vector2(0, y)
		line.size = Vector2(VIEW_SIZE.x, 1)
		line.color = Color(0.12, 0.17, 0.23, 0.42)
		viewport.add_child(line)


func _add_labels(viewport: SubViewport) -> void:
	var columns := ["STATIC", "MOTION", "IMPACT", "WALL + MERGE"]
	var column_x := [56.0, 204.0, 354.0, 492.0]
	for index in columns.size():
		var label := Label.new()
		label.text = columns[index]
		label.position = Vector2(column_x[index], 12.0)
		label.add_theme_color_override("font_color", Color("aab7c8"))
		label.add_theme_font_size_override("font_size", 12)
		viewport.add_child(label)
	var rows := ["MELEE", "RANGED", "HEAVY"]
	var row_y := [48.0, 140.0, 232.0]
	for index in rows.size():
		var label := Label.new()
		label.text = rows[index]
		label.position = Vector2(8.0, row_y[index])
		label.add_theme_color_override("font_color", Color("748399"))
		label.add_theme_font_size_override("font_size", 10)
		viewport.add_child(label)


func _add_wall(viewport: SubViewport) -> void:
	var wall_visual := ColorRect.new()
	wall_visual.position = Vector2(570.0, 40.0)
	wall_visual.size = Vector2(12.0, 280.0)
	wall_visual.color = Color("354052")
	viewport.add_child(wall_visual)
	var edge := ColorRect.new()
	edge.position = Vector2(569.0, 40.0)
	edge.size = Vector2(1.0, 280.0)
	edge.color = Color("7b8ca5")
	viewport.add_child(edge)

	var wall_body := StaticBody2D.new()
	wall_body.position = Vector2(576.0, 180.0)
	wall_body.collision_layer = 1
	wall_body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(12.0, 280.0)
	shape.shape = rectangle
	wall_body.add_child(shape)
	viewport.add_child(wall_body)
