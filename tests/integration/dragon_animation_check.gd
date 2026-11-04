extends SceneTree

const VISUAL := preload("res://scenes/actors/companions/dragon_visual.tscn")
const DIRECTIONS := [Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2.RIGHT]
const NAMES := ["down", "left", "up", "right"]
var checks := 0
var failures := 0
var stage: Node2D
var sprites: Array[DragonSpriteAnimator] = []


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func run_checks() -> void:
	root.content_scale_size = Vector2i(960, 540)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = Vector2i(1280, 720)
	stage = Node2D.new()
	root.add_child(stage)
	current_scene = stage
	stage.draw.connect(func() -> void:
		stage.draw_rect(Rect2(0, 0, 960, 540), Color("121d2b"))
		for index in 4:
			stage.draw_line(Vector2(130 + index * 225, 285), Vector2(280 + index * 225, 285), Color("365067"), 2)
	)
	stage.queue_redraw()
	var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	player.position = Vector2(430, 460)
	stage.add_child(player)
	player.camera.enabled = false
	player.set_input_enabled(false)
	for index in 4:
		var sprite: DragonSpriteAnimator = VISUAL.instantiate()
		sprite.position = Vector2(160 + index * 215, 285)
		sprite.scale = Vector2.ONE * 0.7
		stage.add_child(sprite)
		sprites.append(sprite)
		var label := Label.new()
		label.text = NAMES[index] + " / 6 frames / paced walk"
		label.position = sprite.position + Vector2(-60, 25)
		stage.add_child(label)
		var clip := StringName("walk_" + NAMES[index])
		check(sprite.sprite_frames.get_frame_count(clip) == 6, "six walking frames for " + NAMES[index])
		sprite.update_motion(DIRECTIONS[index] * 100, player.visuals.body_sprite)
		check(sprite.animation == clip, "actual movement chooses " + NAMES[index])
		await create_timer(0.2).timeout
		check(sprite.frame > 0, "walk advances visibly for " + NAMES[index])
		player.visuals.body_sprite.speed_scale = 0.75
		sprite.update_motion(DIRECTIONS[index] * 25, player.visuals.body_sprite)
		var source_fps := player.visuals.body_sprite.sprite_frames.get_animation_speed(clip) * player.visuals.body_sprite.speed_scale
		var codex_fps := sprite.sprite_frames.get_animation_speed(clip) * sprite.speed_scale
		check(is_equal_approx(source_fps, codex_fps), "different movement speed still shares protagonist pace " + NAMES[index])
		player.visuals.body_sprite.speed_scale = 1.0
		sprite.update_motion(Vector2.ZERO)
		check(sprite.animation == StringName("idle_" + NAMES[index]), "stopping retains last direction " + NAMES[index])
		check(sprite.offset == Vector2(-128, -232), "foot origin remains fixed " + NAMES[index])
		sprite.update_motion(DIRECTIONS[index] * 100, player.visuals.body_sprite)
	# Actor-sized comparison beside the real protagonist.
	var actual: DragonSpriteAnimator = VISUAL.instantiate()
	actual.position = Vector2(510, 460)
	stage.add_child(actual)
	actual.update_motion(Vector2.RIGHT * 100, player.visuals.body_sprite)
	var note := Label.new()
	note.text = "Actor scale comparison / player + dragon"
	note.position = Vector2(315, 475)
	stage.add_child(note)
	await process_frame
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/hotline-dragon-animation.png")
	print("Dragon animation checks: ", checks, "; failures: ", failures)
	if "--preview" not in OS.get_cmdline_user_args():
		stage.queue_free()
		await process_frame
		quit(0 if failures == 0 else 1)
