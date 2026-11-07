extends SceneTree

# Isolated visual proof. It never changes the game's live UI or assets.
const OUTPUT := "res://docs/art/validation/ui_graphite_amber_v1/"
const SOURCE := "res://art_sources/ai_drafts/ui_graphite_amber_v1/"
const WIDTH := 1280
const HEIGHT := 720
const GRAPHITE := Color("171b1e")
const PANEL := Color("2a3032")
const TEXT := Color("e3e0d6")
const MUTED := Color("a9aaa3")
const AMBER := Color("c99b65")
const FONT: Font = preload("res://resources/ui/tactical_chinese_font.tres")

var _viewport: SubViewport
var _canvas: Control


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	_viewport = SubViewport.new()
	_viewport.name = "GraphiteAmberPreview"
	_viewport.size = Vector2i(WIDTH, HEIGHT)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_show_combat()
	await _save("combat_1280_720.png")
	_canvas.queue_free()
	await process_frame
	_show_sequence_variants()
	await _save("sequence_4_5_6_1280_720.png")
	_canvas.queue_free()
	await process_frame
	_show_settings()
	await _save("settings_1280_720.png")
	print("Graphite amber UI previews saved: ", OUTPUT)
	quit()


func _save(filename: String) -> void:
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	_viewport.get_texture().get_image().save_png(OUTPUT + filename)


func _new_canvas() -> void:
	_canvas = Control.new()
	_canvas.size = Vector2(WIDTH, HEIGHT)
	_canvas.theme = CyberUITheme.create_theme()
	_viewport.add_child(_canvas)
	var background := _texture(_canvas, "res://docs/art/validation/combat_architecture_v1/loading_workshop.png", Rect2(0, 0, WIDTH, HEIGHT))
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _show_combat() -> void:
	_new_canvas()
	_rect(_canvas, Rect2(15, 14, 152, 62), Color(GRAPHITE, 0.72))
	_texture(_canvas, SOURCE + "durability_base_v1.png", Rect2(20, 14, 137, 60))
	for index in 3:
		_rect(_canvas, Rect2(39 + index * 31, 37, 25, 24), TEXT if index < 2 else Color("545956"))
	_rect(_canvas, Rect2(811, 552, 429, 125), Color(GRAPHITE, 0.82))
	_rect(_canvas, Rect2(833, 567, 378, 3), Color(MUTED, 0.35))
	_rect(_canvas, Rect2(833, 567, 310, 3), AMBER)
	_draw_sequence(_canvas, Vector2(833, 583), 6, 2)


func _show_sequence_variants() -> void:
	_canvas = Control.new()
	_canvas.size = Vector2(WIDTH, HEIGHT)
	_viewport.add_child(_canvas)
	_rect(_canvas, Rect2(0, 0, WIDTH, HEIGHT), GRAPHITE)
	_label(_canvas, "义体序列扩容", Vector2(90, 65), 27, TEXT)
	_label(_canvas, "四、五、六槽共用轨道", Vector2(90, 110), 15, MUTED)
	for index in 3:
		var count := index + 4
		var y := 183 + index * 158
		_rect(_canvas, Rect2(86, y - 16, 1090, 132), PANEL)
		_label(_canvas, "%d 槽" % count, Vector2(110, y + 25), 20, TEXT)
		_draw_sequence(_canvas, Vector2(258, y + 3), count, mini(index + 1, count - 1))
		_label(_canvas, "传导  →", Vector2(906, y + 37), 15, AMBER)


func _draw_sequence(parent: Node, point: Vector2, count: int, active: int) -> void:
	var stride := 63.0
	var width := 26.0 + stride * float(count)
	_texture(parent, SOURCE + "energy_bus_backbone_v1.png", Rect2(point.x - 10, point.y + 43, width, 38))
	# The light is a separate dynamic layer; the bitmap remains usable at any slot count.
	_rect(parent, Rect2(point.x + 9, point.y + 65, stride * float(count - 1) + 38.0, 2), Color(AMBER, 0.22))
	_rect(parent, Rect2(point.x + 9, point.y + 65, stride * float(active) + 25.0, 3), AMBER)
	for index in active + 1:
		_rect(parent, Rect2(point.x + index * stride + 26, point.y + 63, 6, 6), AMBER)
	var icons := [
		"active_neural_switch_64.png",
		"combat_synapse_sensor_64.png",
		"rhythm_pulser_64.png",
		"smart_fire_64.png",
		"explosive_magazine_64.png",
		"tactical_coprocessor_64.png",
	]
	for index in count:
		_rect(parent, Rect2(point.x + index * stride + 10, point.y + 15, 38, 38), Color(0.08, 0.10, 0.11, 0.94))
		_texture(parent, "res://assets/art/items/equipment_v1/" + icons[index], Rect2(point.x + index * stride + 12, point.y + 17, 34, 34))
		_texture(parent, SOURCE + "cyberware_socket_bezel_v1.png", Rect2(point.x + index * stride, point.y + 5, 58, 58))
		if index == active:
			_rect(parent, Rect2(point.x + index * stride + 9, point.y + 73, 40, 3), AMBER)


func _show_settings() -> void:
	_new_canvas()
	_rect(_canvas, Rect2(0, 0, WIDTH, HEIGHT), Color(0.04, 0.055, 0.065, 0.88))
	_rect(_canvas, Rect2(153, 55, 974, 611), Color(PANEL, 0.97))
	_texture(_canvas, SOURCE + "shared_panel_frame_v1.png", Rect2(140, 42, 1000, 637))
	_label(_canvas, "设置", Vector2(198, 103), 27, TEXT)
	_rect(_canvas, Rect2(198, 152, 875, 2), Color(MUTED, 0.35))
	_rect(_canvas, Rect2(427, 179, 1, 396), Color(MUTED, 0.30))
	var tabs := ["显示", "视觉反馈", "音频", "输入与触控", "开发测试"]
	for index in tabs.size():
		var y := 191 + index * 68
		if index == 0:
			_rect(_canvas, Rect2(202, y - 8, 203, 53), Color(AMBER, 0.16))
			_rect(_canvas, Rect2(202, y - 8, 4, 53), AMBER)
		_label(_canvas, tabs[index], Vector2(220, y), 18, TEXT if index == 0 else MUTED)
	_label(_canvas, "显示", Vector2(469, 184), 23, TEXT)
	var names := ["分辨率", "全屏", "战斗 HUD 缩放"]
	var values := ["1920 × 1080", "开启", "100%"]
	for index in names.size():
		var y := 288 + index * 80
		_rect(_canvas, Rect2(469, y - 12, 603, 62), Color(GRAPHITE, 0.65))
		_label(_canvas, names[index], Vector2(490, y), 17, TEXT)
		_label(_canvas, values[index], Vector2(887, y), 16, AMBER if index == 0 else TEXT)
		_rect(_canvas, Rect2(1050, y + 2, 4, 20), Color(AMBER, 0.6) if index == 0 else Color(MUTED, 0.35))
	_label(_canvas, "返回", Vector2(993, 603), 15, MUTED)


func _rect(parent: Node, region: Rect2, color: Color) -> ColorRect:
	var node := ColorRect.new()
	node.position = region.position
	node.size = region.size
	node.color = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


func _texture(parent: Node, path: String, region: Rect2) -> TextureRect:
	var node := TextureRect.new()
	node.position = region.position
	node.size = region.size
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Cannot load preview image: %s (%d)" % [path, error])
	else:
		node.texture = ImageTexture.create_from_image(image)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


func _label(parent: Node, value: String, point: Vector2, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.position = point
	node.text = value
	node.add_theme_font_override("font", FONT)
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node
