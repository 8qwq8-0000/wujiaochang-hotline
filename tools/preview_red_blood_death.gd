extends SceneTree
var world: Node2D
var enemies: Array[EnemyController] = []
var counter := 0
var directions := [Vector2.RIGHT, Vector2.UP, Vector2(-1, 1).normalized()]
var floor_texture: Texture2D

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	world = Node2D.new()
	world.add_to_group("combat_rooms")
	root.add_child(world)
	current_scene = world
	floor_texture = load("res://assets/art/environment/warehouse/floor.png")
	world.draw.connect(draw_background)
	var camera := Camera2D.new()
	camera.position = Vector2(320,180)
	world.add_child(camera)
	camera.make_current()
	var manager := preload("res://scripts/presentation/vfx_manager.gd").new()
	manager.prewarm_count = 1
	world.add_child(manager)
	for i in 3:
		var enemy := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
		enemy.profile = load("res://resources/enemies/" + ["melee_pressure", "ranged_sightline", "heavy_anchor"][i] + ".tres").duplicate()
		enemy.profile.self_destruct_enabled = false
		enemy.profile.patrol_enabled = false
		enemy.position = Vector2(130 + i * 190, 225)
		world.add_child(enemy)
		enemy.set_physics_process(false)
		enemies.append(enemy)

func _process(_delta: float) -> bool:
	if enemies.size() != 3:
		return false
	counter += 1
	for i in 3:
		if counter == 15 + i * 9:
			var packet := DamagePacket.new()
			packet.travel_direction = directions[i]
			enemies[i].health.apply_damage(100, packet)
	if counter == 90:
		capture.call_deferred()
	return false

func capture() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art_sources/animation_drafts/death_blood_spray_v1/directional/ground_imprints.png")

func draw_background() -> void:
	world.draw_rect(Rect2(0,0,640,360),Color("0a1519"))
	for y in range(65, 325, 32):
		for x in range(24,616,32):
			world.draw_texture_rect(floor_texture,Rect2(x,y,mini(32,616-x),mini(32,325-y)),false,Color("88999c"))
	world.draw_string(CyberUITheme.FONT,Vector2(24,30),"死亡效果 / 红色喷血与落地印记",HORIZONTAL_ALIGNMENT_LEFT,-1,18,CyberUITheme.HIGHLIGHT)
	world.draw_string(CyberUITheme.FONT,Vector2(24,50),"无敌人淡出残影 · 无彩色血迹 · 血印留在地面",HORIZONTAL_ALIGNMENT_LEFT,-1,11,CyberUITheme.MUTED)
	for i in 3:
		world.draw_string(CyberUITheme.FONT,Vector2(60+i*190,290),["左侧受击 → 右喷", "下侧受击 → 上喷", "右上受击 → 左下喷"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,10,CyberUITheme.HIGHLIGHT)
