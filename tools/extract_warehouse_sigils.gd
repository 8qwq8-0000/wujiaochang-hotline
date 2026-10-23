extends SceneTree
const OUTPUT := "res://art_sources/ai_drafts/warehouse_sigils_extracted_v1/"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var source: Script = load(OUTPUT + "source_geometry.gd")
	for spec in [["parry",Color(0.4,0.9,1),0],["trial",Color(0.36,1,0.72),0],["boss",Color(0.75,0.55,1),0],["deploy",Color(1,0.75,0.35),1]]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(512,256)
		viewport.transparent_bg = true
		viewport.world_2d = World2D.new()
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var glyph: Node2D = source.new()
		glyph.position = Vector2(256,128)
		glyph.scale = Vector2(6,6)
		glyph.set("tint",spec[1])
		glyph.set("facing",spec[2])
		viewport.add_child(glyph)
		glyph.set_process(false)
		glyph.set("_proximity",1.0)
		glyph.call("_redraw_glyph")
		await process_frame
		await RenderingServer.frame_post_draw
		var result := viewport.get_texture().get_image().save_png(OUTPUT + spec[0] + "_half_raw.png")
		print(spec[0]," half extraction: ",result)
		viewport.queue_free()
		await process_frame
	quit()
