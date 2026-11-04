extends SceneTree

## Run with a display to export native rendered animation frames into /tmp.
const ENEMY := preload("res://scenes/actors/enemies/enemy.tscn")
const OUTPUT := "/tmp/hotline-signal-animation"
var room: Node2D
var source: EnemyController
var caption: Label
var frame_index := 0


func _initialize() -> void:
	call_deferred("run")


func spawn(id: String, point: Vector2) -> EnemyController:
	var enemy := ENEMY.instantiate() as EnemyController
	enemy.profile = load("res://resources/enemies/" + id + ".tres")
	enemy.position = point
	room.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy


func frames(count: int) -> void:
	for index in count:
		await create_timer(1.0 / 12.0).timeout
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(OUTPUT + "/%03d.png" % frame_index)
		frame_index += 1


func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Animation preview requires a display")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(960, 540))
	root.size = Vector2i(640, 360)
	room = Node2D.new()
	room.add_to_group("combat_rooms")
	root.add_child(room)
	current_scene = room
	var background := Polygon2D.new()
	background.polygon = PackedVector2Array([Vector2.ZERO, Vector2(640, 0), Vector2(640, 360), Vector2(0, 360)])
	background.color = Color("101722")
	background.z_index = -10
	room.add_child(background)
	caption = Label.new()
	caption.theme = CyberUITheme.create_theme()
	caption.position = Vector2(38, 30)
	caption.add_theme_font_size_override("font_size", 20)
	room.add_child(caption)
	source = spawn("signal_amplifier", Vector2(205, 245))
	source.facing = Vector2.DOWN
	spawn("melee_pressure", Vector2(345, 245))
	spawn("ranged_sightline", Vector2(460, 245))
	caption.text = "举旗传令兵 · 增幅光环"
	await frames(12)
	var directions := [Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2.RIGHT]
	source.visuals.set_process(false)
	for direction in directions:
		caption.text = "四方向移动 · 持旗与脚下光环"
		source.facing = direction
		source.sprite.play("walk_" + source.visuals.direction_name(direction))
		for index in 6:
			source.position += direction * 2
			await frames(1)
	source.visuals.set_process(true)
	caption.text = "攻击蓄力 · 低频射击"
	source.state = EnemyController.State.WINDUP
	source._attack_direction = Vector2.RIGHT
	await frames(6)
	source.visuals.play_impact(Vector2.RIGHT)
	source.state = EnemyController.State.ATTACK
	await frames(4)
	caption.text = "受击反馈 · 广播持续"
	source.state = EnemyController.State.STAGGERED
	source.visuals.flash_hit()
	source.visuals.play_hit_reaction(Vector2.LEFT, 1.0)
	await frames(5)
	caption.text = "击破信号源 · 敌方强化解除"
	var packet := DamagePacket.new()
	packet.source_faction = CombatFaction.Id.PLAYER
	packet.base_damage = 100
	source.hurt_box.receive_hit(packet)
	await frames(14)
	room.queue_free()
	await process_frame
	print("Signal animation preview frames: ", frame_index)
	quit()
