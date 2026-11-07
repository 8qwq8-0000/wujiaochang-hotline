extends "res://preview.gd"

const CARD_SOURCE := BASE + "art_sources/ai_drafts/persona_os_card_v1/persona_choice_card_source.png"
const OUTPUT_PERSONA := BASE + "docs/art/validation/persona_os_card_v1/"

var card_texture: Texture2D


func capture() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_PERSONA)
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
	var source := Image.new()
	if source.load(CARD_SOURCE) != OK:
		push_error("Persona card source is missing")
		quit(1)
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = ImageTexture.create_from_image(source)
	atlas.region = Rect2(55, 95, 2060, 500)
	card_texture = atlas
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	persona_screen()
	for frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(OUTPUT_PERSONA + "persona_rest_preview_1280_720.png")
	print("Persona card preview captured")
	quit()


func persona_screen() -> void:
	init_canvas(false)
	rect(canvas, Rect2(0, 0, 1280, 720), Color("1b2226"))
	tex(canvas, BASE + "assets/art/ui/os_hud/shared_os_frame_v2.png", Rect2(8, 8, 1264, 704))
	label(canvas, "第 1 层人格整备", Vector2(30, 24), 23, TEXT)
	label(canvas, "待确认", Vector2(1170, 29), 16, AMBER)
	rect(canvas, Rect2(26, 72, 1228, 1), Color(MUTED, 0.35))
	label(canvas, "人格饮料", Vector2(30, 87), 17, TEXT)
	var names := ["赤黑余烬   深渊忍者", "向山难越   传奇宗师", "龙舌兰   摇滚奇侠"]
	var summaries := ["标记连杀", "看破格挡", "开火反馈"]
	var colors := [Color("b66d68"), Color("72aeba"), Color("c1ae68")]
	var bottles := ["drink_naraku_64.png", "drink_xiangshan_64.png", "drink_johnny_tequila_64.png"]
	for index in 3:
		var y := 119 + index * 119
		card(canvas, Rect2(24, y, 336, 100))
		tex(canvas, BASE + "assets/art/items/personality_drinks/" + bottles[index], Rect2(42, y + 15, 64, 64))
		label(canvas, names[index], Vector2(116, y + 22), 16, TEXT)
		label(canvas, summaries[index], Vector2(116, y + 54), 14, colors[index])
		if index == 1:
			rect(canvas, Rect2(37, y + 86, 309, 3), AMBER)
	label(canvas, "传奇宗师  Lv.1", Vector2(399, 94), 21, TEXT)
	label(canvas, "已解析攻击  ·  看破格挡", Vector2(400, 130), 14, Color("72aeba"))
	rect(canvas, Rect2(398, 160, 845, 1), Color(MUTED, 0.32))
	var talents := ["校正窗口", "代拟架势", "反证收益", "代行一招", "开放模型", "宗师气场"]
	for index in talents.size():
		var col := index % 2
		var row := index / 2
		var point := Vector2(398 + col * 421, 184 + row * 106)
		rect(canvas, Rect2(point.x, point.y, 400, 76), Color("2b3235"))
		var edge := AMBER if index == 0 else Color(MUTED, 0.46 if index < 2 else 0.25)
		rect(canvas, Rect2(point.x, point.y, 400, 1), edge)
		rect(canvas, Rect2(point.x, point.y + 75, 400, 1), edge)
		rect(canvas, Rect2(point.x, point.y, 1, 76), edge)
		rect(canvas, Rect2(point.x + 399, point.y, 1, 76), edge)
		label(canvas, talents[index], point + Vector2(14, 12), 16, TEXT if index < 2 else MUTED)
		label(canvas, "当前可选" if index < 2 else "后续等级解锁", point + Vector2(14, 41), 12, AMBER if index < 2 else MUTED)
	rect(canvas, Rect2(26, 635, 1228, 1), Color(MUTED, 0.32))
	label(canvas, "可撤回本次选择，离开时才生效", Vector2(28, 655), 13, MUTED)
	label(canvas, "撤回选择", Vector2(1010, 653), 14, TEXT)
	label(canvas, "确认并离开", Vector2(1127, 653), 14, AMBER)


func card(parent: Node, area: Rect2) -> void:
	var item := TextureRect.new()
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_SCALE
	item.texture = card_texture
	item.position = area.position
	item.size = area.size
	parent.add_child(item)
	item.size = area.size
