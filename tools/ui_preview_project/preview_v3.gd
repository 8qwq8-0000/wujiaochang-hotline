extends "res://preview_v2.gd"

const SOURCE_V3 := BASE + "art_sources/ai_drafts/ui_graphite_amber_v3/"
const OUTPUT_V3 := BASE + "docs/art/validation/ui_graphite_amber_v3/"

var card_texture: Texture2D


func capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_V3)
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
	var image_file := Image.new()
	image_file.load(SOURCE_V3 + "cyberware_card_graphite_draft_a.png")
	var atlas := AtlasTexture.new()
	atlas.atlas = ImageTexture.create_from_image(image_file)
	atlas.region = Rect2(35, 35, 1184, 1184)
	card_texture = atlas
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	combat()
	await save_v3("combat_card_a_1280_720.png")
	canvas.queue_free()
	await process_frame
	variants()
	await save_v3("card_a_4_5_6_1280_720.png")
	print("Graphite card draft captured")
	quit()


func save_v3(filename: String) -> void:
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(OUTPUT_V3 + filename)


func sequence(parent: Node, point: Vector2, count: int, active: int) -> void:
	var stride := 52.0
	var width := stride * float(count)
	tex(parent, SOURCE_V2 + "energy_bus_backbone_v1.png", Rect2(point.x - 8, point.y + 43, width + 16, 40))
	rect(parent, Rect2(point.x + 2, point.y + 74, width - 4, 2), Color(AMBER, 0.27))
	rect(parent, Rect2(point.x + 2, point.y + 74, width * 0.65, 2), AMBER)
	for index in count:
		var card := TextureRect.new()
		card.texture = card_texture
		card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.stretch_mode = TextureRect.STRETCH_SCALE
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(card)
		card.position = point + Vector2(index * stride, 2)
		card.size = Vector2(52, 52)
		tex(parent, BASE + "assets/art/items/equipment_v1/" + ICONS[index] + "_64.png", Rect2(point.x + index * stride + 6, point.y + 8, 40, 40))
		if index == active:
			rect(parent, Rect2(point.x + index * stride + 9, point.y + 55, 34, 2), AMBER)
