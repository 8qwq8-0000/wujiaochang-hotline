extends SceneTree

const ART := preload("res://art_sources/animation_drafts/death_blood_spray_v1/directional/blood_spray_art.gd")
const OUTPUT := "res://assets/art/effects/death_blood_spray_v1/"
const FRAME_OUTPUT := "res://art_sources/animation_drafts/death_blood_spray_v1/directional/frames/"
const CELL := 192
const COUNT := 14
const ANCHOR := Vector2(96, 96)
var model := ART.new()
var age := 0.0
var direction := Vector2.RIGHT

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(CELL, CELL)
	viewport.transparent_bg = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var canvas := Node2D.new()
	canvas.position = ANCHOR
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(canvas)
	canvas.draw.connect(func() -> void: model.draw_frame(canvas, age, direction))
	for sector in 16:
		direction = Vector2.RIGHT.rotated(sector * TAU / 16.0)
		var folder := FRAME_OUTPUT + "%02d/" % sector
		DirAccess.make_dir_recursive_absolute(folder)
		var atlas := Image.create(CELL * COUNT, CELL, false, Image.FORMAT_RGBA8)
		atlas.fill(Color.TRANSPARENT)
		for frame in COUNT:
			age = frame / 15.0
			canvas.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var image := viewport.get_texture().get_image()
			image.save_png(folder + "%02d.png" % frame)
			atlas.blit_rect(image, Rect2i(0, 0, CELL, CELL), Vector2i(frame * CELL, 0))
		atlas.save_png(OUTPUT + "spray_%02d.png" % sector)
		age = 2.0
		canvas.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(OUTPUT + "stain_%02d.png" % sector)
	print("Exported 16 directions × 14 transparent frames, anchor ", ANCHOR)
	quit()
