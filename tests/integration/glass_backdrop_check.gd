extends SceneTree

const OUTPUT_DIR := "res://docs/art/validation/glass_curtain_backdrop_v1"
const EXPECTED_AD_IDS: Array[StringName] = [
	&"ti_hu_di_bo",
	&"rapid_growth_food",
	&"hero_stability_milk",
	&"royal_brain_cache",
	&"family_time_credit",
	&"forbidden_cat_vehicle_novel",
	&"lifespan_withdrawal_scam",
	&"private_air_stick",
	&"mens_13_in_1",
	&"anti_prayer_device",
]

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run_checks")


func check(value: bool, message: String) -> void:
	checks += 1
	if value:
		return
	failures += 1
	push_error(message)


func run_checks() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(640, 360)
	var packed := load("res://scenes/levels/floors/combat_prototype.tscn") as PackedScene
	var floor := packed.instantiate() as Node2D
	root.add_child(floor)
	for frame in 5:
		await process_frame
	var assembler := floor.get_node("FloorAssembler") as FloorAssembler
	var player := floor.get_node("Player") as PlayerController
	var backdrop := floor.get_node("GlassCurtainBackdrop") as CombatGlassBackdrop
	var catalog := load("res://resources/environment/billboard_ad_catalog.tres") as BillboardAdCatalog
	var approved_ids: Array[StringName] = []
	var all_ads_support_giant_display := true
	for entry in catalog.approved_entries():
		approved_ids.append(entry.id)
		all_ads_support_giant_display = all_ads_support_giant_display and entry.texture.get_width() >= 768
	check(assembler.generated_rooms.size() == 2, "formal floor keeps two generated combat rooms")
	check(backdrop != null, "formal floor owns the shared glass curtain backdrop")
	check(not backdrop.is_diagnostic_mode(), "approved catalog replaces diagnostic content")
	check(approved_ids.size() == EXPECTED_AD_IDS.size(), "catalog contains the complete approved advert set")
	for expected_id in EXPECTED_AD_IDS:
		check(expected_id in approved_ids, "catalog contains approved advert: %s" % expected_id)
	check(all_ads_support_giant_display, "approved advert textures retain enough horizontal detail for giant displays")
	check(backdrop.current_ad_id() in EXPECTED_AD_IDS, "an approved advert enters the live rotation")
	check(backdrop.active_panel_count() == 4, "advert wall renders two oversized hero canvases and two edge fragments")
	check(_unique_string_name_count(backdrop.visible_ad_ids()) == 4, "visible advert wall never repeats an advert")
	check(backdrop.opposite_tower_texture_size().is_equal_approx(Vector2(1800.0, 139.0)), "accepted rainy tower plate is loaded at its runtime drawing size")
	var scroll_probe := catalog.approved_entries()[0]
	var scroll_start := backdrop._animated_source_rect(scroll_probe.texture, Vector2(294.0, 49.0), scroll_probe.focus_point, 0, 0.0)
	var scroll_end := backdrop._animated_source_rect(scroll_probe.texture, Vector2(294.0, 49.0), scroll_probe.focus_point, 0, 6.0)
	check(scroll_end.position.y > scroll_start.position.y, "vertically cropped adverts scroll from their headline toward lower content")
	check(is_equal_approx(scroll_start.size.y, scroll_end.size.y), "advert scrolling moves the crop without resizing the LED image")
	check(is_equal_approx(backdrop.floor_width, 1960.0), "shared exterior spans both rooms and passage")
	check(backdrop.active_rain_line_count() in [28, 70], "runtime rain follows the medium-rain quality budget")
	for room in assembler.generated_rooms:
		check(is_equal_approx(room.camera_north_extension, 144.0), "formal room extends only its north camera boundary")
		var top_shape := room.get_node("TopWall/CollisionShape2D").shape as RectangleShape2D
		check(top_shape.size.is_equal_approx(Vector2(960.0, 16.0)), "north wall collision remains unchanged")
	player.set_physics_process(false)
	player.camera.position_smoothing_enabled = false
	player.camera.limit_left = 0
	player.camera.limit_top = -144
	player.camera.limit_right = 1960
	player.camera.limit_bottom = 540
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for stage in [
		["first_room", Vector2(480.0, 42.0)],
		["passage", Vector2(980.0, 42.0)],
		["second_room", Vector2(1480.0, 42.0)],
	]:
		player.global_position = stage[1]
		await process_frame
		await process_frame
		if DisplayServer.get_name() == "headless":
			continue
		var viewport_texture := root.get_texture()
		if viewport_texture == null:
			continue
		var image := viewport_texture.get_image()
		if image == null:
			continue
		var result := image.save_png(OUTPUT_DIR + "/" + stage[0] + ".png")
		check(result == OK, "save rendered " + stage[0] + " validation image")
	if DisplayServer.get_name() != "headless":
		var started_usec := Time.get_ticks_usec()
		for frame in 120:
			await process_frame
		var elapsed_seconds := float(Time.get_ticks_usec() - started_usec) / 1_000_000.0
		var measured_fps := 120.0 / maxf(elapsed_seconds, 0.001)
		print("Glass backdrop measured FPS: ", snappedf(measured_fps, 0.1))
		check(measured_fps >= 110.0, "Compatibility renderer sustains the agreed 110 FPS backdrop budget")
	floor.queue_free()
	await process_frame
	print("Glass backdrop checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)


func _unique_string_name_count(values: Array[StringName]) -> int:
	var unique := {}
	for value in values:
		unique[value] = true
	return unique.size()
