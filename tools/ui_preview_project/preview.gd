extends SceneTree

const BASE := "D:/Projects/wujiaochang-hotline/"
const SOURCE := BASE + "art_sources/ai_drafts/ui_graphite_amber_v1/"
const OUTPUT := BASE + "docs/art/validation/ui_graphite_amber_v1/"
const TEXT := Color("e3e0d6")
const MUTED := Color("a9aaa3")
const AMBER := Color("c99b65")
const ICONS := ["active_neural_switch", "combat_synapse_sensor", "rhythm_pulser", "smart_fire", "explosive_magazine", "tactical_coprocessor"]

var viewport: SubViewport
var canvas: Control
var font: SystemFont
var textures := {}


func _initialize() -> void:
	call_deferred("capture")


func capture() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	combat()
	await save("combat_clean_1280_720.png")
	canvas.queue_free()
	await process_frame
	settings()
	await save("settings_clean_1280_720.png")
	canvas.queue_free()
	await process_frame
	variants()
	await save("sequence_clean_4_5_6_1280_720.png")
	canvas.queue_free()
	await process_frame
	viewport.size = Vector2i(1920, 1080)
	combat()
	canvas.scale = Vector2.ONE * 1.5
	await save("combat_clean_1920_1080.png")
	canvas.queue_free()
	await process_frame
	settings()
	canvas.scale = Vector2.ONE * 1.5
	await save("settings_clean_1920_1080.png")
	print("Clean preview captured")
	quit()


func save(filename: String) -> void:
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(OUTPUT + filename)


func init_canvas(with_room: bool) -> void:
	canvas = Control.new()
	canvas.size = Vector2(1280, 720)
	viewport.add_child(canvas)
	if with_room:
		tex(canvas, BASE + "docs/art/validation/combat_architecture_v1/loading_workshop.png", Rect2(0, 0, 1280, 720))
	else:
		rect(canvas, Rect2(0, 0, 1280, 720), Color("171b1e"))


func combat() -> void:
	init_canvas(true)
	rect(canvas, Rect2(15, 14, 152, 62), Color(0.09, 0.11, 0.12, 0.72))
	tex(canvas, SOURCE + "durability_base_v1.png", Rect2(20, 14, 137, 60))
	for index in 3:
		rect(canvas, Rect2(39 + index * 31, 37, 25, 24), TEXT if index < 2 else Color("545956"))
	rect(canvas, Rect2(811, 552, 429, 125), Color(0.09, 0.11, 0.12, 0.82))
	rect(canvas, Rect2(833, 567, 378, 3), Color(MUTED, 0.35))
	rect(canvas, Rect2(833, 567, 310, 3), AMBER)
	sequence(canvas, Vector2(833, 583), 6, 2)


func settings() -> void:
	init_canvas(true)
	rect(canvas, Rect2(0, 0, 1280, 720), Color(0.04, 0.055, 0.065, 0.88))
	rect(canvas, Rect2(153, 55, 974, 611), Color("2a3032f7"))
	tex(canvas, SOURCE + "shared_panel_frame_v1.png", Rect2(140, 42, 1000, 637))
	label(canvas, "设置", Vector2(198, 103), 27, TEXT)
	rect(canvas, Rect2(198, 152, 875, 2), Color(MUTED, 0.35))
	rect(canvas, Rect2(427, 179, 1, 396), Color(MUTED, 0.30))
	var tabs := ["显示", "视觉反馈", "音频", "输入与触控", "开发测试"]
	for index in tabs.size():
		var y := 191 + index * 68
		if index == 0:
			rect(canvas, Rect2(202, y - 8, 203, 53), Color(AMBER, 0.16))
			rect(canvas, Rect2(202, y - 8, 4, 53), AMBER)
		label(canvas, tabs[index], Vector2(220, y), 18, TEXT if index == 0 else MUTED)
	label(canvas, "显示", Vector2(469, 184), 23, TEXT)
	var names := ["分辨率", "全屏", "战斗 HUD 缩放"]
	var values := ["1920 × 1080", "开启", "100%"]
	for index in names.size():
		var y := 276 + index * 80
		rect(canvas, Rect2(469, y, 603, 62), Color(0.09, 0.11, 0.12, 0.65))
		label(canvas, names[index], Vector2(490, y + 17), 17, TEXT)
		label(canvas, values[index], Vector2(887, y + 17), 16, AMBER if index == 0 else TEXT)
	label(canvas, "返回", Vector2(993, 603), 15, MUTED)


func variants() -> void:
	init_canvas(false)
	label(canvas, "义体序列扩容", Vector2(90, 65), 27, TEXT)
	label(canvas, "四、五、六槽共用轨道", Vector2(90, 110), 15, MUTED)
	for index in 3:
		var count := index + 4
		var y := 167 + index * 158
		rect(canvas, Rect2(86, y, 1090, 132), Color("2a3032"))
		label(canvas, "%d 槽" % count, Vector2(110, y + 43), 20, TEXT)
		sequence(canvas, Vector2(258, y + 16), count, index + 1)
		label(canvas, "传导 →", Vector2(906, y + 50), 15, AMBER)


func sequence(parent: Node, point: Vector2, count: int, active: int) -> void:
	var stride := 63.0
	var width := 26.0 + stride * float(count)
	tex(parent, SOURCE + "energy_bus_backbone_v1.png", Rect2(point.x - 10, point.y + 43, width, 38))
	rect(parent, Rect2(point.x + 9, point.y + 65, stride * float(count - 1) + 38, 2), Color(AMBER, 0.22))
	rect(parent, Rect2(point.x + 9, point.y + 65, stride * float(active) + 25, 3), AMBER)
	for index in active + 1:
		rect(parent, Rect2(point.x + index * stride + 26, point.y + 63, 6, 6), AMBER)
	for index in count:
		rect(parent, Rect2(point.x + index * stride + 10, point.y + 15, 38, 38), Color(0.08, 0.10, 0.11, 0.94))
		tex(parent, BASE + "assets/art/items/equipment_v1/" + ICONS[index] + "_64.png", Rect2(point.x + index * stride + 12, point.y + 17, 34, 34))
		tex(parent, SOURCE + "cyberware_socket_bezel_v1.png", Rect2(point.x + index * stride, point.y + 5, 58, 58))
		if index == active:
			rect(parent, Rect2(point.x + index * stride + 9, point.y + 73, 40, 3), AMBER)


func rect(parent: Node, area: Rect2, color: Color) -> void:
	var item := ColorRect.new()
	item.position = area.position
	item.size = area.size
	item.color = color
	parent.add_child(item)


func tex(parent: Node, path: String, area: Rect2) -> void:
	var item := TextureRect.new()
	item.position = area.position
	item.size = area.size
	if not textures.has(path):
		var image := Image.new()
		var error := image.load(path)
		if error != OK:
			push_error("Could not load %s" % path)
			return
		textures[path] = ImageTexture.create_from_image(image)
	item.texture = textures[path]
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_SCALE
	item.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(item)


func label(parent: Node, value: String, point: Vector2, font_size: int, color: Color) -> void:
	var item := Label.new()
	item.position = point
	item.text = value
	item.add_theme_font_override("font", font)
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	parent.add_child(item)
