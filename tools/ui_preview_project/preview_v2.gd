extends "res://preview.gd"

const SOURCE_V2 := BASE + "art_sources/ai_drafts/ui_graphite_amber_v2/"


func capture() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	combat()
	await save("combat_v2_1280_720.png")
	canvas.queue_free()
	await process_frame
	settings()
	await save("settings_v2_1280_720.png")
	canvas.queue_free()
	await process_frame
	variants()
	await save("sequence_v2_4_5_6_1280_720.png")
	canvas.queue_free()
	await process_frame
	viewport.size = Vector2i(1920, 1080)
	combat()
	canvas.scale = Vector2.ONE * 1.5
	await save("combat_v2_1920_1080.png")
	canvas.queue_free()
	await process_frame
	settings()
	canvas.scale = Vector2.ONE * 1.5
	await save("settings_v2_1920_1080.png")
	print("Second UI preview captured")
	quit()


func combat() -> void:
	init_canvas(true)
	tex(canvas, SOURCE_V2 + "durability_base_v1.png", Rect2(13, 10, 160, 68))
	for index in 3:
		var path := "durability_gem_filled_v2.png" if index < 2 else "durability_gem_empty_v2.png"
		tex(canvas, SOURCE_V2 + path, Rect2(22 + index * 41, 17, 39, 39))
	for index in 10:
		var path := "heat_fin_hot_v2.png" if index < 6 else "heat_fin_cold_v2.png"
		tex(canvas, SOURCE_V2 + path, Rect2(22 + index * 15, 62, 14, 26))
	sequence(canvas, Vector2(930, 609), 6, 2)
	rect(canvas, Rect2(929, 596, 276, 2), Color(MUTED, 0.35))
	rect(canvas, Rect2(929, 596, 210, 2), AMBER)


func settings() -> void:
	init_canvas(true)
	rect(canvas, Rect2(0, 0, 1280, 720), Color(0.025, 0.035, 0.045, 0.78))
	tex(canvas, SOURCE_V2 + "shared_os_frame_v2.png", Rect2(140, 42, 1000, 637))
	label(canvas, "设置", Vector2(199, 106), 27, TEXT)
	rect(canvas, Rect2(198, 154, 875, 1), Color(MUTED, 0.40))
	rect(canvas, Rect2(432, 182, 1, 404), Color(MUTED, 0.30))
	var tabs := ["显示", "视觉反馈", "音频", "输入与触控", "开发测试"]
	for index in tabs.size():
		var y := 196 + index * 66
		if index == 0:
			rect(canvas, Rect2(205, y - 5, 3, 40), AMBER)
		label(canvas, tabs[index], Vector2(224, y), 18, TEXT if index == 0 else MUTED)
	label(canvas, "显示", Vector2(477, 192), 23, TEXT)
	var names := ["分辨率", "全屏", "战斗 HUD 缩放"]
	var values := ["1920 × 1080", "开启", "100%"]
	for index in names.size():
		var y := 297 + index * 74
		label(canvas, names[index], Vector2(489, y), 17, TEXT)
		label(canvas, values[index], Vector2(881, y), 16, AMBER if index == 0 else TEXT)
		rect(canvas, Rect2(477, y + 45, 588, 1), Color(MUTED, 0.28))
		if index == 0:
			rect(canvas, Rect2(1058, y + 10, 3, 16), AMBER)
	label(canvas, "返回", Vector2(994, 602), 15, MUTED)


func variants() -> void:
	init_canvas(false)
	label(canvas, "义体序列扩容", Vector2(90, 65), 27, TEXT)
	for index in 3:
		var count := index + 4
		var y := 190 + index * 155
		label(canvas, "%d 槽" % count, Vector2(108, y + 20), 20, TEXT)
		sequence(canvas, Vector2(260, y), count, index + 1)
		rect(canvas, Rect2(92, y + 105, 1080, 1), Color(MUTED, 0.25))


func sequence(parent: Node, point: Vector2, count: int, active: int) -> void:
	var stride := 46.0
	var width := 20.0 + stride * float(count)
	tex(parent, SOURCE_V2 + "energy_bus_backbone_v1.png", Rect2(point.x - 10, point.y + 31, width, 45))
	rect(parent, Rect2(point.x + 4, point.y + 61, stride * float(count - 1) + 33, 2), Color(AMBER, 0.24))
	rect(parent, Rect2(point.x + 4, point.y + 61, stride * float(active) + 24, 3), AMBER)
	for index in active + 1:
		rect(parent, Rect2(point.x + index * stride + 20, point.y + 59, 5, 6), AMBER)
	for index in count:
		rect(parent, Rect2(point.x + index * stride + 7, point.y + 8, 30, 30), Color(0.08, 0.10, 0.11, 0.94))
		tex(parent, BASE + "assets/art/items/equipment_v1/" + ICONS[index] + "_64.png", Rect2(point.x + index * stride + 9, point.y + 10, 26, 26))
		tex(parent, SOURCE_V2 + "cyberware_socket_bezel_v1.png", Rect2(point.x + index * stride, point.y + 2, 44, 44))
		if index == active:
			rect(parent, Rect2(point.x + index * stride + 7, point.y + 70, 30, 3), AMBER)


func label(parent: Node, value: String, point: Vector2, font_size: int, color: Color) -> void:
	var item := Label.new()
	item.position = point
	item.text = value
	item.add_theme_font_override("font", font)
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.02, 0.72))
	item.add_theme_constant_override("outline_size", 2)
	parent.add_child(item)
