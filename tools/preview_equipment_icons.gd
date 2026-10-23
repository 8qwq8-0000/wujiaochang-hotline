extends SceneTree

const SPECS := [
	["armor", "缓冲装甲", "DEFENSE / 防御"],
	["smart_fire", "智能火控", "瞄准 · 追踪"],
	["explosive_magazine", "爆裂弹仓", "弹丸 · 爆破"],
	["tactical_coprocessor", "战术协处理器", "火控 · 连射"],
	["optical_intruder", "光学入侵器", "突进 · 脱锁"],
	["kill_heat_sink", "击破散热器", "击杀 · 散热"],
	["heat_threshold_pulser", "热阈震荡器", "过热 · 震荡"],
	["compound_cyberware", "复合义体", "最多四种模块"],
]

func _initialize() -> void:
	call_deferred("run")

func label(parent: Node, text: String, size: int, color: Color) -> Label:
	var value := Label.new()
	value.text = text
	value.add_theme_font_size_override("font_size", size)
	value.add_theme_color_override("font_color", color)
	parent.add_child(value)
	return value

func run() -> void:
	var background := ColorRect.new()
	background.color = Color("06110e")
	background.theme = CyberUITheme.create_theme()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	background.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)
	label(content, "整备目录 / 防御与义体", 18, CyberUITheme.HIGHLIGHT)
	label(content, "WJC EQUIPMENT · 32 PX 原生图标 / 透明 PNG", 10, CyberUITheme.MUTED)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	for spec in SPECS:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(146, 125)
		card.add_theme_stylebox_override("panel", CyberUITheme.create_box(Color("10231d"), Color("315945")))
		grid.add_child(card)
		var column := VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_theme_constant_override("separation", 6)
		card.add_child(column)
		var center := CenterContainer.new()
		column.add_child(center)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(64, 64)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.texture = load("res://assets/art/items/equipment_v1/" + spec[0] + ".png")
		center.add_child(icon)
		label(column, spec[1], 12, CyberUITheme.HIGHLIGHT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label(column, spec[2], 10, CyberUITheme.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label(content, "统一工业金属外壳 · 功能轮廓区分 · 背包 / 工坊 / 掉落共用", 10, CyberUITheme.MUTED)
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/art/validation/equipment_icons_v1/catalog.png")
	background.queue_free()
	await process_frame
	quit()
