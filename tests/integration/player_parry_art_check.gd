extends SceneTree

const PLAYER := preload("res://scenes/actors/player/player.tscn")
var checks := 0
var failures := 0
var player: PlayerController
var visual: GuardArcVisual


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func step(seconds: float) -> void:
	player.guard.advance_timing(seconds)
	visual._process(seconds)


func run() -> void:
	var room := Node2D.new()
	root.add_child(room)
	current_scene = room
	player = PLAYER.instantiate() as PlayerController
	player.config = player.config.duplicate()
	player.position = Vector2(320, 220)
	room.add_child(player)
	player.set_input_enabled(false)
	player.set_physics_process(false)
	player.camera.enabled = false
	player.guard.set_physics_process(false)
	visual = player.visuals.guard_visual
	visual.set_process(false)
	await physics_frame
	await process_frame
	var sprite := visual.shield_sprite
	check(not sprite.visible, "idle has no shield")
	check(sprite.texture.get_size() == Vector2(312, 312), "runtime uses compact imported atlas")
	check(sprite.hframes * sprite.vframes == 9, "atlas exposes nine authored frames")
	check(sprite.texture.get_image().detect_alpha() != Image.ALPHA_NONE, "runtime atlas keeps transparency")
	player.set_input_enabled(true)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = true
	root.push_input(mouse, true)
	await process_frame
	# The synced controller consumes buffered right-click input on its physics tick.
	player._physics_process(0.0)
	check(player.guard.state == GuardComponent.State.STARTUP and sprite.visible, "right mouse input reaches player guard and displays effect")
	mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = false
	root.push_input(mouse, true)
	player.set_input_enabled(false)
	player.guard.reset_to_idle()
	check(player.guard.begin_guard(Vector2.RIGHT), "normal guard input starts effect")
	for index in 4:
		if index > 0:
			step(0.005)
		check(sprite.visible and sprite.frame == index, "startup frame %d" % (index + 1))
	step(0.006)
	check(player.guard.state == GuardComponent.State.PERFECT and sprite.frame == 4, "perfect window holds approved fifth frame")
	check(is_equal_approx(player.guard.startup_seconds, 0.02) and is_equal_approx(player.guard.perfect_seconds, 0.20), "art follows more forgiving gameplay timings")
	for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2(1, -1).normalized()]:
		visual.update_guard(player.guard.state, direction, player.guard.guard_arc_degrees)
		check(sprite.position.is_equal_approx(visual.body_center + direction * visual.shield_distance), "shield stays on aimed side: %s" % direction)
		check((visual.DIRECTION_VECTORS[visual.direction_name] as Vector2).rotated(sprite.rotation).is_equal_approx(direction), "authored shield faces aim: %s" % direction)
		check(visual.z_index == (0 if visual.direction_name == &"up" else 3), "shield stays above floor with correct depth: %s" % direction)
		check(sprite.texture == visual.DIRECTION_TEXTURES[visual.direction_name], "selects independent directional atlas: %s" % direction)
		if visual.direction_name == &"up":
			check(visual.get_index() < player.visuals.body_sprite.get_index(), "upward shield orders behind body without negative world Z")
	step(0.20)
	check(sprite.frame == 5 and player.guard.is_guard_active(), "normal block uses frame six")
	step(0.091)
	check(sprite.frame == 6, "normal block progresses to frame seven")
	step(0.09)
	check(sprite.frame == 7 and not player.guard.is_guard_active(), "recovery uses frame eight without blocking")
	step(0.111)
	check(sprite.frame == 8, "recovery reaches final fading frame")
	step(0.12)
	check(not sprite.visible and player.guard.state == GuardComponent.State.IDLE, "cycle ends hidden")
	player.guard.begin_guard(Vector2.RIGHT)
	step(0.061)
	var packet := DamagePacket.new()
	packet.source_faction = CombatFaction.Id.ENEMY
	packet.source_position = player.global_position + Vector2.RIGHT * 40
	packet.travel_direction = Vector2.LEFT
	packet.is_projectile = true
	packet.reflectable = true
	var result := player.guard.try_resolve(packet, player, CombatFaction.Id.PLAYER)
	check(result != null and result.reflected and result.packet.travel_direction == Vector2.RIGHT, "front projectile still reflects")
	check(sprite.frame == 4 and player.guard.state == GuardComponent.State.PERFECT, "reflection preserves the remaining perfect window and peak frame")
	step(0.16)
	check(sprite.frame == 5, "original perfect window expires into normal animation without extension")
	packet.source_position = player.global_position + Vector2.LEFT * 40
	check(player.guard.try_resolve(packet, player, CombatFaction.Id.PLAYER) == null, "art does not protect the player's back")
	player.guard.reset_to_idle()
	check(not sprite.visible, "explicit reset hides immediately")
	player.guard.begin_guard(Vector2.RIGHT)
	step(0.061)
	player.visuals.set_dead(true)
	visual.update_guard(player.guard.state, Vector2.RIGHT, player.guard.guard_arc_degrees)
	check(not sprite.visible, "death suppresses shield even while state updates continue")
	player.guard.reset_to_idle()
	player.visuals.set_dead(false)
	player.guard.begin_guard(Vector2.RIGHT)
	check(sprite.visible and sprite.frame == 0, "next cycle starts cleanly at frame one")
	player.guard.reset_to_idle()
	player.guard.set_physics_process(true)
	visual.set_process(true)
	player.guard.begin_guard(Vector2.RIGHT)
	paused = true
	var paused_progress := player.guard.get_state_progress()
	await create_timer(0.08, true).timeout
	check(is_equal_approx(player.guard.get_state_progress(), paused_progress), "pause freezes guard and effect timing")
	paused = false
	var observed := {sprite.frame: true}
	for i in 70:
		await create_timer(0.01).timeout
		if sprite.visible:
			observed[sprite.frame] = true
	check(observed.has(4) and observed.size() >= 6, "engine callbacks play the authored sequence")
	check(not sprite.visible, "engine callbacks finish and hide without manual stepping")
	# Each cardinal view plays the entire state sequence from its own atlas.
	player.guard.set_physics_process(false)
	visual.set_process(false)
	var direction_textures := {}
	for direction in [Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN]:
		player.guard.reset_to_idle()
		player.guard.begin_guard(direction)
		player.visuals.update_visual(direction, Vector2.ZERO, player.guard.state, player.guard.guard_arc_degrees)
		direction_textures[sprite.texture.resource_path] = true
		check(sprite.frame == 0 and sprite.visible, "directional startup starts cleanly: %s" % direction)
		step(0.061)
		check(sprite.frame == 4, "directional perfect peak: %s" % direction)
		step(0.161)
		check(sprite.frame == 5, "directional normal begins: %s" % direction)
		step(0.091)
		check(sprite.frame == 6, "directional normal progresses: %s" % direction)
		step(0.091)
		check(sprite.frame == 7, "directional recovery begins: %s" % direction)
		step(0.111)
		check(sprite.frame == 8, "directional recovery finishes: %s" % direction)
		step(0.12)
		check(not sprite.visible, "directional cycle hides: %s" % direction)
	check(direction_textures.size() == 4, "four directions use four separate authored atlases")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await capture_preview(room)
	room.queue_free()
	await process_frame
	print("Player parry art checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)


func capture_preview(room: Node2D) -> void:
	root.size = Vector2i(960, 540)
	var backdrop := Polygon2D.new()
	backdrop.polygon = PackedVector2Array([Vector2.ZERO, Vector2(960, 0), Vector2(960, 540), Vector2(0, 540)])
	backdrop.color = Color("17212c")
	backdrop.z_index = 0
	room.add_child(backdrop)
	room.move_child(backdrop, 0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/art/validation/player_parry_cardinal_v2"))
	player.position = Vector2(320, 230)
	player.scale = Vector2.ONE * 3.0
	player.guard.set_physics_process(false)
	visual.set_process(false)
	player.guard.reset_to_idle()
	player.guard.begin_guard(Vector2.RIGHT)
	step(0.061)
	for direction in [Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN]:
		player.visuals.update_visual(direction, Vector2.ZERO, player.guard.state, player.guard.guard_arc_degrees)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/art/validation/player_parry_cardinal_v2/%s.png" % visual.direction_name)
