extends SceneTree

const IDS := ["armor", "smart_fire", "explosive_magazine", "tactical_coprocessor", "optical_intruder", "kill_heat_sink", "heat_threshold_pulser"]
const TITLES := ["缓冲装甲", "智能火控", "爆裂弹仓", "战术协处理器", "光学入侵器", "击破散热器", "热阈震荡器", "复合义体"]

func _initialize() -> void:
	call_deferred("run")

func backdrop(canvas: Node2D, tile: Texture2D) -> void:
	canvas.draw_rect(Rect2(0, 0, 640, 360), Color("0b161c"))
	for y in range(64, 340, 32):
		for x in range(24, 616, 32):
			canvas.draw_texture_rect(tile, Rect2(x, y, mini(32, 616 - x), mini(32, 340 - y)), false, Color("819496"))
	canvas.draw_string(CyberUITheme.FONT, Vector2(28, 32), "义体与防御 / 地面掉落", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, CyberUITheme.HIGHLIGHT)
	canvas.draw_string(CyberUITheme.FONT, Vector2(28, 51), "实际 ComponentPickup · 原生 32px · 物品独立图标", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, CyberUITheme.MUTED)
	for index in TITLES.size():
		var at := Vector2(96 + (index % 4) * 148, 136 + (index / 4) * 116)
		canvas.draw_string(CyberUITheme.FONT, at + Vector2(-60, 35), TITLES[index], HORIZONTAL_ALIGNMENT_CENTER, 120, 12, CyberUITheme.HIGHLIGHT)

func run() -> void:
	var world := Node2D.new()
	world.add_to_group("combat_rooms")
	root.add_child(world)
	current_scene = world
	var art := preload("res://scripts/presentation/warehouse_art.gd").new()
	var background := Node2D.new()
	background.z_index = -10
	world.add_child(background)
	background.draw.connect(backdrop.bind(background, art.asset("floor")))
	background.queue_redraw()
	var camera := Camera2D.new()
	camera.position = Vector2(320, 180)
	world.add_child(camera)
	camera.make_current()
	var player := load("res://scenes/actors/player/player.tscn").instantiate() as PlayerController
	player.position = Vector2(40, 310)
	world.add_child(player)
	player.camera.enabled = false
	player.set_physics_process(false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 155
	var compound := ComponentRolls.fuse(ComponentRolls.create("smart_fire", 1, rng), ComponentRolls.create("explosive_magazine", 1, rng), rng)
	for index in 8:
		var pickup := load("res://scenes/items/component_pickup.tscn").instantiate() as ComponentPickup
		pickup.rolled_item = ComponentRolls.create(IDS[index], 2, rng) if index < IDS.size() else compound
		pickup.position = Vector2(96 + (index % 4) * 148, 136 + (index / 4) * 116)
		world.add_child(pickup)
	for frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/art/validation/equipment_icons_v1/ground.png")
	player.inventory.defense_slot.equip(ComponentRolls.create("armor", 3, rng))
	player.inventory.cyberware_slot.equip(ComponentRolls.fuse(ComponentRolls.create("smart_fire", 1, rng), ComponentRolls.create("explosive_magazine", 1, rng), rng))
	for id in IDS.slice(1):
		player.inventory.backpack.add_item(ComponentRolls.create(id, 1, rng))
	player.inventory._apply_equipment()
	player.inventory.set_open(true)
	for frame in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/art/validation/equipment_icons_v1/inventory.png")
	player.inventory.set_open(false)
	world.queue_free()
	art.free()
	await process_frame
	quit()
