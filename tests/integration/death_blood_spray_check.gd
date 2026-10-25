extends SceneTree

const SPRAY := preload("res://scripts/presentation/death_blood_spray.gd")
const VFX := preload("res://scripts/presentation/vfx_manager.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var room := Node2D.new()
	room.add_to_group("combat_rooms")
	root.add_child(room)
	current_scene = room
	var manager := VFX.new()
	manager.prewarm_count = 1
	room.add_child(manager)
	var shared := SPRAY.shared_frames()
	check(shared.get_animation_names().size() == 16, "sixteen separate directional animations")
	for sector in 16:
		var heading := Vector2.RIGHT.rotated(sector * TAU / 16.0)
		check(SPRAY.sector_for(heading) == sector, "direction selection sector %d" % sector)
		var clip := StringName("spray_%02d" % sector)
		check(shared.get_frame_count(clip) == 14 and not shared.get_animation_loop(clip), "fourteen frames play once per direction")
		check(shared.get_frame_count(clip) / shared.get_animation_speed(clip) < 0.35, "spray finishes within 350ms for a sharp impact")
		var texture := shared.get_frame_texture(clip, 2)
		var image := texture.get_image()
		check(texture.get_size() == Vector2(192,192) and image.detect_alpha() != Image.ALPHA_NONE and image.get_used_rect().size != Vector2i.ZERO, "transparent nonempty frame in every direction")
		var clear_edges := true
		for frame in SPRAY.FRAME_COUNT:
			var bounds := shared.get_frame_texture(clip, frame).get_image().get_used_rect()
			clear_edges = clear_edges and bounds.position.x > 0 and bounds.position.y > 0 and bounds.end.x < SPRAY.CELL_SIZE and bounds.end.y < SPRAY.CELL_SIZE
		check(clear_edges, "all directional frames keep a transparent border without clipping")
		var enemy := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
		enemy.profile = load("res://resources/enemies/melee_pressure.tres").duplicate()
		enemy.profile.patrol_enabled = false
		enemy.position = Vector2(180,180)
		room.add_child(enemy)
		enemy.set_physics_process(false)
		var packet := DamagePacket.new()
		packet.travel_direction = heading
		packet.knockback = -heading * 50
		enemy.health.apply_damage(enemy.health.max_health, packet)
		check(manager.find_children("*", "DeathBurstEffect", true, false).is_empty(), "no fading enemy copy or colored death burst is spawned")
		var effects := get_nodes_in_group("death_blood_sprays")
		check(effects.size() == 1 and effects[0].direction_index == sector, "actual enemy death uses final attack direction rather than knockback")
		if not effects.is_empty():
			check(effects[0].get_parent() == room and effects[0].offset == -SPRAY.ANCHOR, "room ownership and fixed effect anchor")
			effects[0].queue_free()
		await process_frame
	var fallback := load("res://scenes/actors/enemies/enemy.tscn").instantiate() as EnemyController
	fallback.profile = load("res://resources/enemies/melee_pressure.tres").duplicate()
	fallback.position = Vector2(150,100)
	room.add_child(fallback)
	fallback.set_physics_process(false)
	var packet := DamagePacket.new()
	packet.source_position = Vector2(150,180)
	fallback.health.apply_damage(100,packet)
	var effect: AnimatedSprite2D = get_first_node_in_group("death_blood_sprays")
	check(effect != null and effect.direction_index == 12, "source below the enemy sprays upward when direction fields are absent")
	await create_timer(0.15).timeout
	check(effect.frame > 0, "animation actually advances")
	paused = true
	var held_frame := effect.frame
	await create_timer(0.15, true).timeout
	check(effect.frame == held_frame, "spray freezes during pause")
	paused = false
	await create_timer(0.3).timeout
	check(get_nodes_in_group("death_blood_sprays").is_empty(), "finished spray is released")
	check(manager.get_stain_count() == 1 and get_nodes_in_group("red_blood_stains").size() == 1, "spray leaves one persistent red ground imprint")
	var imprint := get_first_node_in_group("red_blood_stains") as Sprite2D
	check(imprint != null and imprint.texture.resource_path.ends_with("stain_12.png"), "ground imprint matches upward spray direction")
	await create_timer(0.4).timeout
	check(is_instance_valid(imprint) and is_equal_approx(imprint.modulate.a, 1), "red imprint stays without fading or role colors")
	room.queue_free()
	await process_frame
	check(get_nodes_in_group("death_blood_sprays").is_empty(), "room exit leaves no orphan effect")
	check(get_nodes_in_group("red_blood_stains").is_empty(), "room unload removes the persistent red stain")
	print("Death blood spray checks: ",checks,"; failures: ",failures)
	quit(0 if failures == 0 else 1)
