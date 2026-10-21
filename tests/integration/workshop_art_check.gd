extends SceneTree
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
	for key in WorkshopArt.REGIONS:
		var texture := WorkshopArt.asset(key) as AtlasTexture
		var image := texture.atlas.get_image()
		check(texture.get_width()>0 and texture.get_height()>0, key + " is a usable atlas texture")
		check(Rect2(Vector2.ZERO,image.get_size()).encloses(texture.region), key + " silhouette crop stays inside source PNG")
		check(image.detect_alpha()!=Image.ALPHA_NONE if key!="floor" else image.detect_alpha()==Image.ALPHA_NONE, key + " has correct transparency")
	# A direction change must mirror the body in place, never move it off its feet.
	for profile_id in ["melee_pressure", "ranged_sightline", "heavy_anchor"]:
		var enemy: EnemyController = load("res://scenes/actors/enemies/enemy.tscn").instantiate()
		enemy.profile = load("res://resources/enemies/" + profile_id + ".tres")
		root.add_child(enemy)
		enemy.set_physics_process(false)
		var body := enemy.get_node("BodyVisual") as AnimatedSprite2D
		var initial_rect: Rect2 = body.transform * Rect2(body.offset, Vector2(EnemySpriteAnimator.CELL_SIZE, EnemySpriteAnimator.CELL_SIZE))
		check(body.position.is_equal_approx(Vector2(0, 10)) and body.offset == -EnemySpriteAnimator.FOOT_ANCHOR, profile_id + " body uses the common boot anchor")
		for frame in range(8):
			enemy.position += Vector2(3, 2)
			enemy.facing = Vector2.LEFT if frame % 2 == 0 else Vector2.RIGHT
			await process_frame
			# process_frame fires before node _process; wait for the visual update.
			await process_frame
			var world_rect: Rect2 = body.global_transform * Rect2(body.offset, Vector2(EnemySpriteAnimator.CELL_SIZE, EnemySpriteAnimator.CELL_SIZE))
			check(not body.flip_h and enemy.visuals.current_animation.ends_with("left" if frame % 2 == 0 else "right"), profile_id + " selects an authored direction without swapping weapon hands")
			check(world_rect.is_equal_approx(Rect2(initial_rect.position + enemy.global_position, initial_rect.size)), profile_id + " body follows movement without a flip offset")
		enemy.queue_free()
		await process_frame
	for id in ["loading_workshop", "interlinked_apartment"]:
		var room: CombatRoom = load("res://scenes/levels/rooms/variants/"+id+".tscn").instantiate()
		room.configure_stage(0,2)
		root.add_child(room)
		current_scene = room
		check(room.has_node("WorkshopFloor") and room.has_node("WorkshopForeground"),id + " wires runtime art")
		var floor_art: WorkshopArt = room.get_node("WorkshopFloor")
		var foreground: WorkshopArt = room.get_node("WorkshopForeground")
		check(floor_art.z_index<foreground.z_index and not room.get_node("Floor").visible,"art replaces debug floor below actors")
		var collider_count := 0
		for body in room.get_node("LayoutGeometry").get_children():
			if body is StaticBody2D:
				collider_count += 1
		check(collider_count==room.layout.covers.size()+room.layout.windows.size(),"rendering retains all authored obstacle colliders")
		check(room.spawner.remaining_objectives()==6,"art retains six pending enemies")
		room.open_side("Left")
		room.open_side("Right")
		check(foreground.left_open and foreground.right_open,"rendered walls track real passage openings")
		check(not room.get_node("ExitElevator/Label").visible,"oversized debug exit label removed")
		room.queue_free()
		await process_frame
	print("Workshop art checks: ",checks,"; failures: ",failures)
	quit(0 if failures==0 else 1)
