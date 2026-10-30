extends SceneTree

const ENEMY := preload("res://scenes/actors/enemies/enemy.tscn")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func make_room() -> Node2D:
	var room := Node2D.new()
	room.add_user_signal("room_cleared")
	room.add_to_group("combat_rooms")
	root.add_child(room)
	return room


func spawn(room: Node2D, id: String, at: Vector2) -> EnemyController:
	var enemy := ENEMY.instantiate() as EnemyController
	enemy.profile = load("res://resources/enemies/" + id + ".tres")
	enemy.position = at
	room.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy


func hit(enemy: EnemyController, amount: int) -> DamageResult:
	var packet := DamagePacket.new()
	packet.source_faction = CombatFaction.Id.PLAYER
	packet.base_damage = amount
	packet.blockable = false
	return enemy.hurt_box.receive_hit(packet)


func run() -> void:
	root.size = Vector2i(640, 360)
	var room := make_room()
	current_scene = room
	var other := make_room()
	var melee := spawn(room, "melee_pressure", Vector2(330, 230))
	melee.health.configure_max_health(100)
	var ranged := spawn(room, "ranged_sightline", Vector2(440, 230))
	var outsider := spawn(other, "melee_pressure", Vector2(330, 230))
	check(not melee.has_signal_boost(), "no source means no boost")
	var source := spawn(room, "signal_amplifier", Vector2(200, 230))
	check(melee.has_signal_boost() and ranged.has_signal_boost(), "source boosts every allied role in its area")
	check(not source.has_signal_boost(), "source never buffs itself")
	check(not outsider.has_signal_boost(), "nearby enemies in another area are excluded")
	check(is_equal_approx(melee.effective_move_speed(), 130.0), "melee gets 30 percent speed")
	check(is_equal_approx(ranged.effective_attack_cooldown(), 1.008), "attack interval reduced by 30 percent")
	check(is_equal_approx(melee.profile.attack_windup, 0.3), "windup unchanged")
	check(is_equal_approx(melee.profile.move_speed, 100.0), "shared source profile never modified")
	var second := spawn(room, "signal_amplifier", Vector2(110, 230))
	check(not second.has_signal_boost(), "emitters cannot buff one another")
	check(is_equal_approx(melee.effective_move_speed(), 130.0), "multiple sources do not stack")
	var dealt := 0
	var absorbed := 0
	for index in 5:
		var result := hit(melee, 1)
		dealt += result.final_damage
		absorbed += result.absorbed_damage
	check(dealt == 3 and absorbed == 2, "five one-point hits deal three damage: exactly 40 percent reduction")
	check(hit(melee, 10).final_damage == 6, "large hit reduced by 40 percent")
	check(hit(source, 1).final_damage == 1, "source takes full damage")
	# Queued and killed emitters must stop protecting allies immediately.
	second.queue_free()
	check(melee.has_signal_boost(), "remaining source retains boost")
	hit(source, 100)
	check(not melee.has_signal_boost(), "source death removes boost in the same tick")
	check(is_equal_approx(melee.effective_move_speed(), 100.0), "speed returns to base")
	check(is_equal_approx(melee.effective_attack_cooldown(), 0.82), "cooldown returns to base")
	check(hit(melee, 1).final_damage == 1, "damage returns to full after source death")
	await create_timer(0.6).timeout
	# Recreate for visual verification and inspect all native directional clips.
	source = spawn(room, "signal_amplifier", Vector2(200, 230))
	check(source.sprite.sprite_frames != load("res://assets/art/characters/enemies/animated/ranged_frames.tres"), "herald uses its own sprite atlas")
	check(source.sprite.offset == Vector2(-128, -224), "dedicated atlas keeps aligned boots")
	for direction in ["down", "left", "up", "right"]:
		check(source.sprite.sprite_frames.has_animation("walk_" + direction), "four-direction walk clip " + direction)
		check(source.sprite.sprite_frames.has_animation("attack_" + direction), "four-direction attack clip " + direction)
		check(source.sprite.sprite_frames.get_frame_count("walk_" + direction) == 6, "six authored walking poses per direction")
	source.visuals.set_process(false)
	source.sprite.play("walk_down")
	var first_frame := source.sprite.frame
	await create_timer(0.25).timeout
	check(source.sprite.frame != first_frame, "native walking animation advances")
	check(source.signal_visual.elapsed > 0.0 and source.signal_visual.visible, "broadcast animation runs")
	check(melee.signal_visual.visible, "recipient marker appears")
	var ring := source.signal_visual.get_node("BroadcastRing") as Node2D
	check(ring.visible and ring.z_index + source.signal_visual.z_index < 0, "broadcast ring draws under the herald")
	var ring_before := ring.global_position
	source.position += Vector2(25, 12)
	check(ring.global_position.is_equal_approx(ring_before + Vector2(25, 12)), "broadcast ring follows movement without lag")
	second = spawn(other, "signal_amplifier", Vector2(110, 230))
	hit(source, 100)
	# process_frame is emitted before Node._process; let the presentation tick run.
	await process_frame
	await process_frame
	check(not melee.signal_visual.visible, "head marker disappears when last source in this area dies")
	check(outsider.has_signal_boost(), "source in another area retains its own buffs")

	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/hotline-signal-preview.png")
	room.queue_free()
	other.queue_free()
	await process_frame
	print("Enemy signal checks: ", checks, "; failures: ", failures)
	quit(1 if failures else 0)
