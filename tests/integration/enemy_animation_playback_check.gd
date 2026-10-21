extends SceneTree

const ENEMY := preload("res://scenes/actors/enemies/enemy.tscn")
const MOTION := preload("res://tests/integration/enemy_animation_motion_probe.gd")
const PROFILES := ["melee_pressure", "ranged_sightline", "heavy_anchor"]
const DIRECTIONS := [Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2.RIGHT]
var failures := 0
var checks := 0
var actors: Array[EnemyController] = []


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func capture(index: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/hotline-native-animation/%03d.png" % index)


func run() -> void:
	Engine.max_fps = 240
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(640, 360)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute("/tmp/hotline-native-animation")
	var room := Node2D.new()
	root.add_child(room)
	current_scene = room
	var background := ColorRect.new()
	background.color = Color("17242e")
	background.size = Vector2(640, 360)
	background.z_index = -10
	room.add_child(background)
	for role in 3:
		var label := Label.new()
		label.text = ["MELEE / WALK + BATON", "RANGED / WALK + FIRE", "HEAVY / WALK + SHIELD SLAM"][role]
		label.position = Vector2(16, 12 + role * 110)
		label.add_theme_font_size_override("font_size", 10)
		room.add_child(label)
		for direction in 4:
			var enemy := ENEMY.instantiate() as EnemyController
			enemy.set_script(MOTION)
			enemy.profile = load("res://resources/enemies/" + PROFILES[role] + ".tres").duplicate()
			enemy.position = Vector2(115 + direction * 140, 85 + role * 110)
			enemy.initial_facing = DIRECTIONS[direction]
			enemy.collision_mask = 0
			room.add_child(enemy)
			enemy.set("motion", DIRECTIONS[direction] * 12.0)
			enemy.state = EnemyController.State.CHASE
			actors.append(enemy)
	await physics_frame
	await physics_frame
	# Repeated visual updates with no intervening physics tick must not reset
	# a walk loop. This fails with the old render-position comparison.
	for enemy in actors:
		enemy.visuals.update_visual(0.001)
		enemy.visuals.update_visual(0.001)
		check(enemy.visuals.current_animation.begins_with("walk_") and enemy.sprite.is_playing(), "walk keeps playing between physics ticks")
	var seen: Array[Dictionary] = []
	for enemy in actors:
		seen.append({})
	for frame in 24:
		await create_timer(0.05).timeout
		for index in actors.size():
			seen[index][actors[index].sprite.frame] = true
			check(actors[index].visuals.current_animation.begins_with("walk_"), "render frames preserve moving state")
		await capture(frame)
	for index in actors.size():
		check(seen[index].size() >= 5, "native walk advances through at least five distinct frames")
		actors[index].set("motion", Vector2.ZERO)
	await physics_frame
	await physics_frame
	await process_frame
	await process_frame
	for enemy in actors:
		check(enemy.visuals.current_animation.begins_with("idle_"), "stopped physics body returns to idle")
		# A longer anticipation makes all authored poses visible in this capture.
		enemy.profile.attack_windup = 0.5
		enemy.state = EnemyController.State.WINDUP
		enemy._attack_direction = enemy.facing
	for frame in 12:
		await create_timer(0.05).timeout
		await capture(24 + frame)
	for enemy in actors:
		check(enemy.sprite.frame == 2, "anticipation holds before contact until combat callback")
		enemy.state = EnemyController.State.ATTACK
		enemy.visuals.play_impact(enemy.facing)
		check(enemy.sprite.frame == 3 and enemy.sprite.is_playing(), "impact starts native recovery at contact")
	for frame in 8:
		await create_timer(0.05).timeout
		await capture(36 + frame)
	room.queue_free()
	await process_frame
	print("Enemy native playback checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
