class_name CombatGlassBackdrop
extends Node2D

const AD_CATALOG: BillboardAdCatalog = preload("res://resources/environment/billboard_ad_catalog.tres")
const GLASS_SHADER: Shader = preload("res://shaders/glass_curtain_mask.gdshader")
const OPPOSITE_TOWER_TEXTURE: Texture2D = preload("res://assets/environment/rainy_opposite_tower_v2.png")
const UI_SECTION := &"UISettings"
const FEEDBACK_QUALITY_SETTING := &"FeedbackQuality"
const REDUCED_FLASHES_SETTING := &"ReducedFlashes"
const BACKDROP_HEIGHT := 144.0
const LOGICAL_VIEWPORT_WIDTH := 640.0
const TOWER_WIDTH := 1800.0
const WALL_WIDTH := 1200.0
const WALL_HEIGHT := 124.0
const TOWER_PARALLAX := 0.38
const DISTANT_PARALLAX := 0.08
const FOG_PARALLAX := 0.13
const AD_SCROLL_SECONDS := 12.0
const AD_SCROLL_EDGE_HOLD := 0.14
const DIAGNOSTIC_IDS: Array[StringName] = [&"diagnostic_portrait", &"diagnostic_square", &"diagnostic_landscape"]

var floor_width := 1960.0
var room_width := 960.0
var room_spacing := 1000.0
var room_count := 2
var _camera_x := floor_width * 0.5
var _visual_time := 0.0
var _wall_playlist := BillboardWallPlaylist.new()
var _approved_by_id := {}
var _diagnostic_mode := true
var _glass_mask: Polygon2D
var _glass_details: Node2D


func configure(count: int, spacing: float, width: float, seed_value: int) -> void:
	room_count = maxi(count, 1)
	room_spacing = spacing
	room_width = width
	floor_width = room_width + room_spacing * maxi(room_count - 1, 0)
	_approved_by_id.clear()
	var ids: Array[StringName] = []
	for entry in AD_CATALOG.approved_entries():
		_approved_by_id[entry.id] = entry
		ids.append(entry.id)
	_diagnostic_mode = ids.is_empty()
	if _diagnostic_mode:
		ids.assign(DIAGNOSTIC_IDS)
	_wall_playlist.configure(ids, seed_value)
	if is_inside_tree():
		_rebuild_glass_mask()
	queue_redraw()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -8
	_build_glass_layers()
	queue_redraw()


func _process(delta: float) -> void:
	_visual_time += delta
	_wall_playlist.advance(delta)
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		_camera_x = camera.get_screen_center_position().x
	queue_redraw()
	if is_instance_valid(_glass_details):
		_glass_details.queue_redraw()


func _draw() -> void:
	_draw_sky()
	_draw_distant_city()
	_draw_distant_fog()
	_draw_opposite_tower()
	_draw_outdoor_rain()
	_draw_ad_light_spill()


func current_ad_id() -> StringName:
	return _wall_playlist.slot_id(0)


func visible_ad_ids() -> Array[StringName]:
	return _wall_playlist.visible_ids()


func active_panel_count() -> int:
	return _wall_playlist.slot_count()


func is_diagnostic_mode() -> bool:
	return _diagnostic_mode


func active_rain_line_count() -> int:
	return 28 if _is_low_feedback_quality() else 70


func opposite_tower_texture_size() -> Vector2:
	return OPPOSITE_TOWER_TEXTURE.get_size()


func _build_glass_layers() -> void:
	_glass_mask = Polygon2D.new()
	_glass_mask.name = "GlassMaterialMask"
	_glass_mask.z_index = 1
	var material := ShaderMaterial.new()
	material.shader = GLASS_SHADER
	_glass_mask.material = material
	add_child(_glass_mask)
	_glass_details = Node2D.new()
	_glass_details.name = "GlassDetails"
	_glass_details.z_index = 2
	_glass_details.draw.connect(_draw_glass_details.bind(_glass_details))
	add_child(_glass_details)
	_rebuild_glass_mask()


func _rebuild_glass_mask() -> void:
	if not is_instance_valid(_glass_mask):
		return
	_glass_mask.polygon = PackedVector2Array([
		Vector2(0.0, -BACKDROP_HEIGHT),
		Vector2(floor_width, -BACKDROP_HEIGHT),
		Vector2(floor_width, 4.0),
		Vector2(0.0, 4.0),
	])
	_glass_mask.uv = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0),
	])


func _draw_sky() -> void:
	draw_rect(Rect2(0.0, -BACKDROP_HEIGHT, floor_width, BACKDROP_HEIGHT + 8.0), Color("040a12"))
	for row in 6:
		var shade := Color(0.018 + row * 0.005, 0.045 + row * 0.007, 0.075 + row * 0.010, 1.0)
		draw_rect(Rect2(0.0, -BACKDROP_HEIGHT + row * 24.0, floor_width, 24.0), shade)


func _draw_distant_city() -> void:
	for index in range(-6, 12):
		var anchor_x := float(index * 250 + 35)
		var x := _project_x(anchor_x, DISTANT_PARALLAX)
		var height := 38.0 + float(posmod(index * 31, 76))
		var width := 48.0 + float(posmod(index * 19, 46))
		var rect := Rect2(x, -height, width, height)
		draw_rect(rect, Color("0a1420"))
		for window_index in range(1, int(width / 11.0)):
			var flicker := fposmod(_visual_time * 0.10 + float(index * 7 + window_index) * 0.37, 1.0)
			if flicker > 0.80:
				var window_color := Color(0.68, 0.50, 0.24, 0.28) if window_index % 4 == 0 else Color(0.34, 0.52, 0.61, 0.24)
				draw_rect(Rect2(x + window_index * 10.0, -height + 8.0 + float(posmod(window_index * 13, int(maxf(height - 16.0, 1.0)))), 2.0, 2.0), window_color)
	var beacon_x := _project_x(floor_width * 0.78, DISTANT_PARALLAX)
	var beacon_alpha := 0.12 + 0.20 * maxf(sin(_visual_time * 1.2), 0.0)
	draw_circle(Vector2(beacon_x, -122.0), 1.0, Color(0.76, 0.19, 0.22, beacon_alpha))


func _draw_distant_fog() -> void:
	var visible_left := _camera_x - LOGICAL_VIEWPORT_WIDTH * 0.5 - 96.0
	for band_index in 2:
		var band_y := -118.0 + band_index * 50.0
		var band_height := 22.0 + band_index * 8.0
		var drift := fposmod(_visual_time * (2.4 + band_index), 190.0)
		for segment in range(-1, 6):
			var anchor := visible_left + segment * 176.0 - drift
			var x := _project_x(anchor, FOG_PARALLAX)
			var alpha := 0.035 + band_index * 0.012
			draw_rect(Rect2(x, band_y, 150.0, band_height), Color(0.24, 0.36, 0.43, alpha))


func _draw_opposite_tower() -> void:
	# The wide facade stays continuous across both rooms. Its focal main panel is
	# biased toward the first arena while the right-hand modules reveal in room two.
	var anchor := floor_width * 0.5 - 50.0
	var center_x := _project_x(anchor, TOWER_PARALLAX)
	var tower_rect := Rect2(center_x - TOWER_WIDTH * 0.5, -BACKDROP_HEIGHT + 3.0, TOWER_WIDTH, BACKDROP_HEIGHT - 5.0)
	draw_texture_rect(OPPOSITE_TOWER_TEXTURE, tower_rect, false, Color(1.06, 1.08, 1.10, 1.0))
	var slots := _wall_slot_rects(tower_rect)
	for slot_index in slots.size():
		_draw_ad_panel(slot_index, slots[slot_index])
	_draw_tower_haze(tower_rect)


func _draw_facade_structure(tower_rect: Rect2) -> void:
	for x in range(int(tower_rect.position.x) + 14, int(tower_rect.end.x), 26):
		draw_line(Vector2(x, tower_rect.position.y), Vector2(x, tower_rect.end.y), Color(0.10, 0.17, 0.22, 0.62), 1.0)
	for y in range(int(tower_rect.position.y) + 14, int(tower_rect.end.y), 18):
		draw_line(Vector2(tower_rect.position.x, y), Vector2(tower_rect.end.x, y), Color(0.05, 0.09, 0.13, 0.86), 1.0)
	for rib in range(int(tower_rect.position.x), int(tower_rect.end.x) + 1, 240):
		draw_rect(Rect2(rib - 4.0, tower_rect.position.y, 8.0, tower_rect.size.y), Color("111c24"))
		draw_line(Vector2(rib + 4.0, tower_rect.position.y), Vector2(rib + 4.0, tower_rect.end.y), Color(0.22, 0.39, 0.43, 0.24), 1.0)
	for y in [-103.0, -54.0]:
		draw_rect(Rect2(tower_rect.position.x, y, tower_rect.size.x, 4.0), Color("141f27"))
		draw_line(Vector2(tower_rect.position.x, y), Vector2(tower_rect.end.x, y), Color(0.30, 0.46, 0.49, 0.20), 1.0)
	for light_index in 5:
		var light_x := tower_rect.position.x + 120.0 + light_index * 360.0
		var pulse := 0.18 + 0.18 * maxf(sin(_visual_time * 1.15 + light_index), 0.0)
		draw_circle(Vector2(light_x, tower_rect.position.y + 4.0), 1.0, Color(0.85, 0.13, 0.18, pulse))


func _wall_slot_rects(tower_rect: Rect2) -> Array[Rect2]:
	var slots: Array[Rect2] = []
	# Each screen extends 20% of its former height above and below its original
	# center line. Integer logical pixels keep the low-resolution LED edges crisp.
	slots.append(Rect2(tower_rect.position.x + 562.0, -122.0, 302.0, 80.0))
	slots.append(Rect2(tower_rect.position.x + 980.0, -122.0, 298.0, 80.0))
	slots.append(Rect2(tower_rect.position.x + 425.0, -146.0, 175.0, 43.0))
	slots.append(Rect2(tower_rect.position.x + 1320.0, -51.0, 175.0, 43.0))
	return slots


func _draw_ad_panel(slot_index: int, rect: Rect2) -> void:
	var is_main := slot_index < 2
	_draw_panel_mount(rect, is_main)
	draw_rect(rect.grow(4.0), Color("020507"))
	draw_rect(rect.grow(2.0), Color("263b43"), false, 2.0)
	draw_rect(rect, Color("071016"))
	var id := _wall_playlist.slot_id(slot_index)
	var entry := _approved_by_id.get(id) as BillboardAdEntry
	if entry != null and entry.texture != null:
		_draw_approved_ad(entry, rect, is_main, slot_index)
	else:
		_draw_diagnostic_ad(id if not id.is_empty() else DIAGNOSTIC_IDS[slot_index % DIAGNOSTIC_IDS.size()], rect)
	_draw_led_matrix(rect)
	_draw_panel_refresh_texture(rect, slot_index, id, is_main)
	_draw_panel_seams(rect, is_main)
	_draw_panel_transition(rect, slot_index, is_main)


func _draw_panel_mount(rect: Rect2, is_main: bool) -> void:
	var steel := Color(0.10, 0.16, 0.19, 0.92)
	var edge := Color(0.24, 0.38, 0.41, 0.46)
	var reach := 5.0 if is_main else 7.0
	for ratio: float in [0.18, 0.82]:
		var x: float = rect.position.x + rect.size.x * ratio
		draw_line(Vector2(x, rect.position.y - reach), Vector2(x, rect.position.y), steel, 2.0)
		draw_line(Vector2(x, rect.end.y), Vector2(x, rect.end.y + reach), steel, 2.0)
	draw_line(Vector2(rect.position.x - 5.0, rect.end.y + reach), Vector2(rect.end.x + 5.0, rect.end.y + reach), steel, 2.0)
	draw_line(Vector2(rect.position.x, rect.end.y + reach - 1.0), Vector2(rect.end.x, rect.end.y + reach - 1.0), edge, 1.0)


func _draw_approved_ad(entry: BillboardAdEntry, rect: Rect2, is_main: bool, slot_index: int) -> void:
	var bounds := rect.grow(-4.0)
	var accent := _accent_for_id(entry.id)
	draw_rect(bounds, Color(accent, 0.16 if is_main else 0.12))
	for band in 3:
		var band_y := bounds.position.y + (float(band) + 0.5) * bounds.size.y / 3.0
		draw_rect(Rect2(bounds.position.x, band_y, bounds.size.x, 1.0), Color(0.55, 0.88, 0.88, 0.08 if is_main else 0.05))
	var base_brightness := 0.90 if is_main else 0.75
	var breath := sin(_visual_time * 0.48 + float(hash(String(entry.id)) % 17)) * 0.018
	var brightness := clampf(base_brightness + breath, 0.70, 0.92)
	var source_rect := _animated_source_rect(entry.texture, bounds.size, entry.focus_point, slot_index, _visual_time)
	draw_texture_rect_region(entry.texture, bounds, source_rect, Color(brightness, brightness, brightness, 1.0))


func _animated_source_rect(texture: Texture2D, target_size: Vector2, focus_point: Vector2, slot_index: int, time_seconds: float) -> Rect2:
	var source_rect := _cover_source_rect(texture, target_size, focus_point)
	var scroll_range := maxf(texture.get_height() - source_rect.size.y, 0.0)
	if scroll_range < 1.0:
		return source_rect
	var phase := fposmod(time_seconds / AD_SCROLL_SECONDS + float(slot_index) * 0.25, 1.0)
	var scroll_progress := _vertical_scroll_progress(phase)
	source_rect.position.y = roundf(scroll_range * scroll_progress)
	return source_rect


func _vertical_scroll_progress(phase: float) -> float:
	# Hold briefly at both ends so headlines and footers remain readable, then
	# ease between them. Only the sampled texture region moves; the physical LED
	# cabinet, refresh scan, seams, and glass mask remain fixed to the building.
	var wrapped := fposmod(phase, 1.0)
	if wrapped <= AD_SCROLL_EDGE_HOLD:
		return 0.0
	if wrapped < 0.5:
		return smoothstep(AD_SCROLL_EDGE_HOLD, 0.5, wrapped)
	if wrapped <= 0.5 + AD_SCROLL_EDGE_HOLD:
		return 1.0
	return 1.0 - smoothstep(0.5 + AD_SCROLL_EDGE_HOLD, 1.0, wrapped)


func _cover_source_rect(texture: Texture2D, target_size: Vector2, focus_point: Vector2) -> Rect2:
	var source_size := texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0 or target_size.x <= 0.0 or target_size.y <= 0.0:
		return Rect2(Vector2.ZERO, source_size)
	var focus := Vector2(clampf(focus_point.x, 0.0, 1.0), clampf(focus_point.y, 0.0, 1.0))
	var target_aspect := target_size.x / target_size.y
	var source_aspect := source_size.x / source_size.y
	if source_aspect > target_aspect:
		var crop_width := source_size.y * target_aspect
		var max_x := source_size.x - crop_width
		return Rect2(roundf(max_x * focus.x), 0.0, floorf(crop_width), source_size.y)
	var crop_height := source_size.x / target_aspect
	var max_y := source_size.y - crop_height
	return Rect2(0.0, roundf(max_y * focus.y), source_size.x, floorf(crop_height))


func _draw_diagnostic_ad(id: StringName, rect: Rect2) -> void:
	var inner := rect.grow(-4.0)
	draw_rect(inner, Color("091820"))
	if id == &"diagnostic_portrait":
		var portrait := Rect2(inner.get_center().x - inner.size.y * 0.28, inner.position.y, inner.size.y * 0.56, inner.size.y)
		draw_rect(portrait, Color("7f294b"))
	elif id == &"diagnostic_square":
		var edge := minf(inner.size.x, inner.size.y)
		var square := Rect2(inner.get_center() - Vector2(edge, edge) * 0.5, Vector2(edge, edge))
		draw_rect(square, Color("16475a"))
	else:
		for band in 5:
			var color := Color("183b4a") if band % 2 == 0 else Color("742947")
			draw_rect(Rect2(inner.position.x, inner.position.y + band * inner.size.y / 5.0, inner.size.x, inner.size.y / 5.0), color)


func _draw_led_matrix(rect: Rect2) -> void:
	var shadow := Color(0.0, 0.012, 0.018, 0.065)
	for x in range(int(rect.position.x) + 3, int(rect.end.x), 6):
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), shadow, 1.0)
	for y in range(int(rect.position.y) + 3, int(rect.end.y), 6):
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), shadow, 1.0)


func _draw_panel_refresh_texture(rect: Rect2, slot_index: int, id: StringName, is_main: bool) -> void:
	var scan_y := rect.position.y + fposmod(_visual_time * (3.2 if is_main else 2.2) + slot_index * 19.0, rect.size.y)
	draw_rect(Rect2(rect.position.x, scan_y, rect.size.x, 2.0), Color(0.44, 0.84, 0.86, 0.045 if is_main else 0.03))
	var seed_value := absi(hash(String(id))) + slot_index * 97
	for pixel_index in 5:
		var x := rect.position.x + 4.0 + float(posmod(seed_value + pixel_index * 37, maxi(int(rect.size.x) - 8, 1)))
		var y := rect.position.y + 4.0 + float(posmod(seed_value / 7 + pixel_index * 23, maxi(int(rect.size.y) - 8, 1)))
		var color := Color(0.0, 0.0, 0.0, 0.30) if pixel_index % 3 else Color(0.42, 0.92, 0.90, 0.18)
		draw_rect(Rect2(roundf(x), roundf(y), 1.0, 1.0), color)


func _draw_panel_seams(rect: Rect2, is_main: bool) -> void:
	var columns := 3 if is_main else 2
	var rows := 1
	for column in range(1, columns):
		var x := rect.position.x + column * rect.size.x / float(columns)
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), Color(0.01, 0.025, 0.03, 0.48), 1.0)
	for row in range(1, rows):
		var y := rect.position.y + row * rect.size.y / float(rows)
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), Color(0.01, 0.025, 0.03, 0.44), 1.0)


func _draw_panel_transition(rect: Rect2, slot_index: int, is_main: bool) -> void:
	if _wall_playlist.transition_slot() != slot_index:
		return
	var progress := _wall_playlist.transition_progress()
	if _reduced_flashes():
		var scan_y := rect.position.y + floorf(progress * rect.size.y)
		draw_rect(rect, Color(0.005, 0.015, 0.022, 0.24))
		draw_rect(Rect2(rect.position.x, scan_y - 2.0, rect.size.x, 4.0), Color(0.08, 0.28, 0.31, 0.40))
		return
	var darkness := 0.15 + sin(progress * PI) * (0.27 if is_main else 0.18)
	draw_rect(rect, Color(0.005, 0.012, 0.018, darkness))
	var strip_count := 3 if is_main else 2
	for strip in strip_count:
		var y := rect.position.y + fposmod(progress * 79.0 + strip * 31.0, rect.size.y)
		var offset := float((strip % 3) - 1) * (5.0 if is_main else 2.0)
		var cyan := Color(0.10, 0.70, 0.72, 0.25 if is_main else 0.17)
		var magenta := Color(0.72, 0.12, 0.42, 0.14 if is_main else 0.08)
		draw_rect(Rect2(rect.position.x + offset, y, rect.size.x - absf(offset), 2.0), cyan)
		if is_main:
			draw_rect(Rect2(rect.position.x - offset, y + 2.0, rect.size.x - absf(offset), 1.0), magenta)


func _draw_wall_service_details(wall_rect: Rect2, slots: Array[Rect2]) -> void:
	draw_line(Vector2(wall_rect.position.x, wall_rect.position.y + 62.0), Vector2(wall_rect.end.x, wall_rect.position.y + 62.0), Color("1b2930"), 3.0)
	for slot_rect in slots:
		draw_circle(slot_rect.position + Vector2(2.0, 2.0), 1.0, Color(0.20, 0.76, 0.72, 0.50))
		draw_circle(Vector2(slot_rect.end.x - 2.0, slot_rect.position.y + 2.0), 1.0, Color(0.68, 0.16, 0.20, 0.38))
	for vent_x in range(int(wall_rect.position.x) + 1128, int(wall_rect.end.x) - 12, 16):
		draw_line(Vector2(vent_x, wall_rect.position.y + 18.0), Vector2(vent_x + 7.0, wall_rect.end.y - 18.0), Color(0.24, 0.35, 0.38, 0.34), 2.0)


func _draw_tower_haze(tower_rect: Rect2) -> void:
	draw_rect(Rect2(tower_rect.position.x, tower_rect.position.y, tower_rect.size.x, 10.0), Color(0.24, 0.34, 0.40, 0.06))
	draw_rect(Rect2(tower_rect.position.x, tower_rect.position.y, 46.0, tower_rect.size.y), Color(0.20, 0.31, 0.38, 0.05))
	draw_rect(Rect2(tower_rect.end.x - 46.0, tower_rect.position.y, 46.0, tower_rect.size.y), Color(0.20, 0.31, 0.38, 0.05))


func _draw_outdoor_rain() -> void:
	if _is_low_feedback_quality():
		_draw_rain_layer(28, 116.0, 6.0, Color(0.46, 0.69, 0.75, 0.25), 31)
		return
	_draw_rain_layer(28, 58.0, 3.0, Color(0.34, 0.49, 0.56, 0.14), 17)
	var lit_rain := _current_wall_accent().lerp(Color("76aab6"), 0.58)
	lit_rain.a = 0.22
	_draw_rain_layer(24, 102.0, 5.0, lit_rain, 31)
	_draw_rain_layer(18, 152.0, 8.0, Color(0.52, 0.76, 0.82, 0.31), 47)


func _draw_rain_layer(count: int, speed: float, length: float, color: Color, salt: int) -> void:
	var visible_left := _camera_x - LOGICAL_VIEWPORT_WIDTH * 0.5 - 48.0
	for index in count:
		var x := visible_left + fposmod(float(index * (73 + salt)) + _visual_time * (9.0 + salt * 0.13), LOGICAL_VIEWPORT_WIDTH + 96.0)
		var y := -BACKDROP_HEIGHT + fposmod(float(index * (37 + salt)) + _visual_time * speed, BACKDROP_HEIGHT + 18.0)
		draw_line(Vector2(roundf(x), roundf(y)), Vector2(roundf(x + 2.0), roundf(y + length)), color, 1.0)


func _draw_ad_light_spill() -> void:
	var accent := _current_wall_accent()
	draw_rect(Rect2(0.0, -BACKDROP_HEIGHT, floor_width, BACKDROP_HEIGHT), Color(accent, 0.018))
	for band in 4:
		var alpha := 0.052 * (1.0 - float(band) / 4.0)
		draw_rect(Rect2(0.0, float(band * 6), floor_width, 6.0), Color(accent, alpha))


func _draw_glass_details(canvas: Node2D) -> void:
	var frame_dark := Color("17232a")
	var frame_light := Color(0.25, 0.48, 0.53, 0.62)
	canvas.draw_line(Vector2(0.0, -BACKDROP_HEIGHT), Vector2(floor_width, -BACKDROP_HEIGHT), frame_dark, 4.0)
	canvas.draw_line(Vector2(0.0, 0.0), Vector2(floor_width, 0.0), frame_dark, 5.0)
	canvas.draw_line(Vector2(0.0, -72.0), Vector2(floor_width, -72.0), frame_light, 1.0)
	for room_index in room_count:
		var room_start := room_index * room_spacing
		for x in range(int(room_start), int(room_start + room_width) + 1, 176):
			canvas.draw_line(Vector2(x, -BACKDROP_HEIGHT), Vector2(x, 0.0), frame_dark, 3.0 if x == int(room_start) else 2.0)
			canvas.draw_line(Vector2(x + 2.0, -BACKDROP_HEIGHT), Vector2(x + 2.0, 0.0), Color(0.34, 0.62, 0.66, 0.16), 1.0)
	if room_count > 1:
		for seam_index in range(room_count - 1):
			var seam_start := seam_index * room_spacing + room_width
			canvas.draw_rect(Rect2(seam_start, -BACKDROP_HEIGHT, room_spacing - room_width, BACKDROP_HEIGHT), Color("111a20"))
	if not _is_low_feedback_quality():
		_draw_glass_rivulets(canvas)


func _draw_glass_rivulets(canvas: Node2D) -> void:
	var accent := _current_wall_accent().lerp(Color("94c5cd"), 0.68)
	accent.a = 0.15
	for index in 12:
		var anchor := floor_width * float(index + 1) / 13.0
		var y := -BACKDROP_HEIGHT + fposmod(_visual_time * (4.0 + index * 0.17) + index * 19.0, BACKDROP_HEIGHT + 26.0)
		var length := 8.0 + float(posmod(index * 11, 18))
		canvas.draw_line(Vector2(roundf(anchor), roundf(y)), Vector2(roundf(anchor), roundf(minf(y + length, 0.0))), accent, 1.0)


func _current_wall_accent() -> Color:
	return _accent_for_id(_wall_playlist.slot_id(0))


func _accent_for_id(id: StringName) -> Color:
	if id.is_empty():
		return Color("4a9eaa")
	var hue := fposmod(float(hash(String(id))) / 997.0, 1.0)
	return Color.from_hsv(hue, 0.54, 0.78)


func _project_x(anchor_world_x: float, parallax: float) -> float:
	return anchor_world_x * parallax + _camera_x * (1.0 - parallax)


func _is_low_feedback_quality() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return int(PlayerConfig.get_config(UI_SECTION, FEEDBACK_QUALITY_SETTING, 1)) == 0


func _reduced_flashes() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return bool(PlayerConfig.get_config(UI_SECTION, REDUCED_FLASHES_SETTING, false))
