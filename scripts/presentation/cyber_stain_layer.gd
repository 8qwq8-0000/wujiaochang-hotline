class_name CyberStainLayer
extends Node2D

## Persistent death stains rendered by one CanvasItem. Geometry is generated
## once from a deterministic seed. Only growing or retiring stains are updated.

const PALETTES := [
	Color("ff268f"), # melee: neon magenta
	Color("24dff4"), # ranged: electric cyan
	Color("b9f23d"), # heavy: acidic lime
]
const BASE_RADII := [13.0, 14.0, 18.0]
const OUTLINE_POINT_COUNT := 22
const CLEARANCE_RAY_COUNT := 8
const MAX_RETIRED_STAINS := 4

@export_range(1, 128, 1) var stain_budget: int = 48
@export_range(0.05, 1.0, 0.01) var growth_seconds: float = 0.45
@export_range(0.05, 1.0, 0.01) var fade_seconds: float = 0.35
@export_range(1.0, 30.0, 1.0) var animation_fps: float = 12.0
@export_flags_2d_physics var obstacle_collision_mask: int = 1

var _stains: Array[Dictionary] = []
var _retired_stains: Array[Dictionary] = []
var _tick_accumulator := 0.0


func _ready() -> void:
	set_process(false)


func spawn_stain(
	world_position: Vector2,
	seed_value: int,
	kind: int = 0,
	motion_direction: Vector2 = Vector2.ZERO,
	impact_direction: Vector2 = Vector2.ZERO
) -> void:
	if _stains.size() >= stain_budget:
		var retired: Dictionary = _stains.pop_front()
		retired["fade_age"] = 0.0
		_retired_stains.append(retired)
		if _retired_stains.size() > MAX_RETIRED_STAINS:
			_retired_stains.pop_front()

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var role_index := clampi(kind, 0, PALETTES.size() - 1)
	var base_radius: float = BASE_RADII[role_index] * rng.randf_range(0.85, 1.15)
	var local_position := to_local(world_position)
	var local_motion := _local_direction(motion_direction)
	var local_impact := _local_direction(impact_direction)
	if local_motion.is_zero_approx() and local_impact.is_zero_approx():
		local_motion = Vector2.from_angle(rng.randf_range(0.0, TAU))
		local_impact = local_motion
	elif local_motion.is_zero_approx():
		local_motion = local_impact
	elif local_impact.is_zero_approx():
		local_impact = local_motion

	var clearances := _sample_clearances(world_position, base_radius * 2.25)
	var outline_data := _make_outline(rng, base_radius, local_motion, clearances)
	var outer: PackedVector2Array = outline_data["points"]
	var start_outer := _make_start_outline(rng, outer)
	var core := _make_core(rng, outer, base_radius, local_motion)
	var droplets := _make_droplets(rng, base_radius, local_impact, clearances)
	var bridge := _make_overlap_bridge(local_position, base_radius)
	var base_color := _vary_color(PALETTES[role_index], rng)
	var main_color := base_color
	main_color.a = 0.66
	var core_color := base_color.darkened(0.46)
	core_color.a = 0.84
	var highlight_color := base_color.lightened(0.38)
	highlight_color.a = 0.58
	var droplet_color := base_color.darkened(0.2)
	droplet_color.a = 0.76

	_stains.append({
		"position": local_position,
		"outer": outer,
		"start_outer": start_outer,
		"growth_delays": outline_data["growth_delays"],
		"core": core,
		"droplets": droplets,
		"bridge": bridge,
		"highlights": _make_highlights(rng, base_radius, -local_motion),
		"base_radius": base_radius,
		"main_color": main_color,
		"core_color": core_color,
		"highlight_color": highlight_color,
		"droplet_color": droplet_color,
		"motion_direction": local_motion,
		"impact_direction": local_impact,
		"age": 0.0,
	})
	set_process(true)
	queue_redraw()


func clear_stains() -> void:
	_stains.clear()
	_retired_stains.clear()
	_tick_accumulator = 0.0
	set_process(false)
	queue_redraw()


func get_stain_count() -> int:
	return _stains.size()


func get_retired_stain_count() -> int:
	return _retired_stains.size()


func get_stain_shape_hash(index: int) -> int:
	if index < 0 or index >= _stains.size():
		return 0
	var stain := _stains[index]
	return hash(str([
		stain["outer"],
		stain["droplets"],
		stain["base_radius"],
		stain["main_color"],
	]))


func get_stain_debug_data(index: int) -> Dictionary:
	if index < 0 or index >= _stains.size():
		return {}
	var stain := _stains[index]
	var droplet_positions := PackedVector2Array()
	for droplet in stain["droplets"]:
		droplet_positions.append(droplet["position"])
	return {
		"outer": (stain["outer"] as PackedVector2Array).duplicate(),
		"droplet_positions": droplet_positions,
		"motion_direction": stain["motion_direction"],
		"impact_direction": stain["impact_direction"],
		"base_radius": stain["base_radius"],
		"age": stain["age"],
	}


func _process(delta: float) -> void:
	_tick_accumulator += maxf(delta, 0.0)
	var frame_seconds := 1.0 / maxf(animation_fps, 1.0)
	if _tick_accumulator < frame_seconds:
		return
	var elapsed := floorf(_tick_accumulator / frame_seconds) * frame_seconds
	_tick_accumulator = fmod(_tick_accumulator, frame_seconds)
	var still_animating := false
	for index in _stains.size():
		var stain: Dictionary = _stains[index]
		var age := minf(float(stain["age"]) + elapsed, growth_seconds)
		stain["age"] = age
		_stains[index] = stain
		if age < growth_seconds:
			still_animating = true
	for index in range(_retired_stains.size() - 1, -1, -1):
		var stain: Dictionary = _retired_stains[index]
		var fade_age := float(stain.get("fade_age", 0.0)) + elapsed
		if fade_age >= fade_seconds:
			_retired_stains.remove_at(index)
			continue
		stain["fade_age"] = fade_age
		_retired_stains[index] = stain
		still_animating = true
	queue_redraw()
	set_process(still_animating)


func _draw() -> void:
	for stain in _retired_stains:
		var alpha := 1.0 - clampf(float(stain.get("fade_age", 0.0)) / fade_seconds, 0.0, 1.0)
		_draw_stain(stain, alpha, 1.0)
	for stain in _stains:
		var progress := clampf(float(stain["age"]) / growth_seconds, 0.0, 1.0)
		_draw_stain(stain, 1.0, progress)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_stain(stain: Dictionary, alpha: float, progress: float) -> void:
	draw_set_transform(stain["position"], 0.0, Vector2.ONE)
	var outer: PackedVector2Array = stain["outer"]
	var start_outer: PackedVector2Array = stain["start_outer"]
	var delays: PackedFloat32Array = stain["growth_delays"]
	var grown := PackedVector2Array()
	for index in outer.size():
		var local_progress := clampf((progress - delays[index]) / maxf(1.0 - delays[index], 0.01), 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - local_progress, 3.0)
		grown.append(_pixel(start_outer[index].lerp(outer[index], eased)))
	draw_colored_polygon(grown, _with_alpha(stain["main_color"], alpha))

	var core: PackedVector2Array = stain["core"]
	var grown_core := PackedVector2Array()
	var core_progress := 0.82 + 0.18 * (1.0 - pow(1.0 - progress, 2.0))
	for point in core:
		grown_core.append(_pixel(point * core_progress))
	draw_colored_polygon(grown_core, _with_alpha(stain["core_color"], alpha))

	var bridge: PackedVector2Array = stain["bridge"]
	if not bridge.is_empty():
		draw_colored_polygon(bridge, _with_alpha(stain["core_color"], alpha * 0.78))

	for droplet in stain["droplets"]:
		if droplet["elongated"]:
			draw_colored_polygon(droplet["polygon"], _with_alpha(stain["droplet_color"], alpha))
		else:
			draw_circle(droplet["position"], droplet["radius"], _with_alpha(stain["droplet_color"], alpha))
	for highlight: PackedVector2Array in stain["highlights"]:
		draw_polyline(highlight, _with_alpha(stain["highlight_color"], alpha), 1.0, false)


func _make_outline(
	rng: RandomNumberGenerator,
	base_radius: float,
	motion_direction: Vector2,
	clearances: PackedFloat32Array
) -> Dictionary:
	var noise: Array[float] = []
	var value := rng.randf_range(-0.08, 0.08)
	for _index in OUTLINE_POINT_COUNT:
		value = lerpf(value, rng.randf_range(-0.2, 0.2), 0.38)
		noise.append(value)
	for _pass in 2:
		var smoothed := noise.duplicate()
		for index in OUTLINE_POINT_COUNT:
			smoothed[index] = (
				noise[(index - 1 + OUTLINE_POINT_COUNT) % OUTLINE_POINT_COUNT]
				+ noise[index] * 2.0
				+ noise[(index + 1) % OUTLINE_POINT_COUNT]
			) * 0.25
		noise = smoothed

	var lobe_directions: Array[Vector2] = []
	var lobe_strengths: Array[float] = []
	for _index in rng.randi_range(2, 4):
		lobe_directions.append(Vector2.from_angle(rng.randf_range(0.0, TAU)))
		lobe_strengths.append(rng.randf_range(0.08, 0.24))
	var tail_direction := -motion_direction.normalized()
	var ellipse_rotation := rng.randf_range(0.0, TAU)
	var radius_x := base_radius * rng.randf_range(1.0, 1.18)
	var radius_y := base_radius * rng.randf_range(0.7, 0.9)
	var points := PackedVector2Array()
	var growth_delays := PackedFloat32Array()
	for index in OUTLINE_POINT_COUNT:
		var angle := TAU * float(index) / float(OUTLINE_POINT_COUNT)
		var ellipse_point := Vector2(cos(angle) * radius_x, sin(angle) * radius_y).rotated(ellipse_rotation)
		var direction := ellipse_point.normalized()
		var distance := ellipse_point.length() * (1.0 + noise[index])
		distance += base_radius * 0.62 * pow(maxf(direction.dot(tail_direction), 0.0), 7.0)
		for lobe_index in lobe_directions.size():
			distance += base_radius * lobe_strengths[lobe_index] * pow(
				maxf(direction.dot(lobe_directions[lobe_index]), 0.0),
				10.0
			)
		var clearance := _clearance_for_direction(direction, clearances)
		distance = minf(distance, maxf(clearance - 1.0, base_radius * 0.3))
		points.append(_pixel(direction * distance))
		var tongue_delay := rng.randf_range(0.0, 0.18)
		if direction.dot(tail_direction) > 0.65:
			tongue_delay += rng.randf_range(0.05, 0.14)
		growth_delays.append(minf(tongue_delay, 0.28))
	return {"points": points, "growth_delays": growth_delays}


func _make_start_outline(rng: RandomNumberGenerator, outer: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in outer:
		result.append(_pixel(point * rng.randf_range(0.46, 0.58)))
	return result


func _make_core(
	rng: RandomNumberGenerator,
	outer: PackedVector2Array,
	base_radius: float,
	motion_direction: Vector2
) -> PackedVector2Array:
	var result := PackedVector2Array()
	var offset := -motion_direction * base_radius * rng.randf_range(0.02, 0.08)
	for index in outer.size():
		var factor := rng.randf_range(0.5, 0.66)
		if index % 3 == 0:
			factor *= rng.randf_range(0.88, 1.05)
		result.append(_pixel(outer[index] * factor + offset))
	return result


func _make_droplets(
	rng: RandomNumberGenerator,
	base_radius: float,
	impact_direction: Vector2,
	clearances: PackedFloat32Array
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var elongated_count := rng.randi_range(1, 2)
	var total_count := elongated_count + rng.randi_range(2, 4)
	for index in total_count:
		var position := Vector2.ZERO
		var radius := 1.0
		var direction := impact_direction
		var accepted := false
		for _attempt in 8:
			direction = impact_direction.rotated(rng.randf_range(-0.72, 0.72)).normalized()
			var normalized_distance := rng.randf_range(0.0, 1.0)
			var distance := lerpf(base_radius * 0.88, base_radius * 1.72, normalized_distance)
			radius = lerpf(2.6, 0.8, normalized_distance) * rng.randf_range(0.82, 1.12)
			position = _pixel(direction * distance)
			if distance + radius > _clearance_for_direction(direction, clearances) - 0.5:
				continue
			var separated := true
			for existing in result:
				if position.distance_to(existing["position"]) < radius + float(existing["radius"]) + 1.5:
					separated = false
					break
			if separated:
				accepted = true
				break
		if not accepted:
			continue
		var elongated := index < elongated_count
		var polygon := PackedVector2Array()
		if elongated:
			var tangent := Vector2(-direction.y, direction.x)
			polygon.append(_pixel(position - direction * radius * 0.72))
			polygon.append(_pixel(position + tangent * radius * 0.72))
			polygon.append(_pixel(position + direction * radius * 1.45))
			polygon.append(_pixel(position - tangent * radius * 0.72))
		result.append({
			"position": position,
			"radius": maxf(1.0, roundf(radius)),
			"elongated": elongated,
			"polygon": polygon,
		})
	return result


func _make_highlights(
	rng: RandomNumberGenerator,
	base_radius: float,
	tail_direction: Vector2
) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var axis := tail_direction.normalized()
	var normal := Vector2(-axis.y, axis.x)
	for _index in rng.randi_range(2, 3):
		var center := axis * rng.randf_range(-0.05, 0.24) * base_radius
		center += normal * rng.randf_range(-0.35, 0.2) * base_radius
		var half_length := base_radius * rng.randf_range(0.12, 0.24)
		var bend := normal * rng.randf_range(-0.08, 0.08) * base_radius
		var segment := PackedVector2Array([
			_pixel(center - axis * half_length),
			_pixel(center + bend),
			_pixel(center + axis * half_length),
		])
		result.append(segment)
	return result


func _make_overlap_bridge(local_position: Vector2, base_radius: float) -> PackedVector2Array:
	var closest := Vector2.ZERO
	var closest_distance := INF
	for stain in _stains:
		var relative: Vector2 = stain["position"] - local_position
		var distance := relative.length()
		var other_radius := float(stain["base_radius"])
		if distance > 3.0 and distance < (base_radius + other_radius) * 1.15 and distance < closest_distance:
			closest = relative
			closest_distance = distance
	if closest_distance == INF:
		return PackedVector2Array()
	var direction := closest.normalized()
	var normal := Vector2(-direction.y, direction.x)
	var center := closest * 0.5
	var half_length := minf(closest_distance * 0.34, base_radius * 0.72)
	var half_width := maxf(1.0, minf(base_radius * 0.18, 3.0))
	return PackedVector2Array([
		_pixel(center - direction * half_length - normal * half_width),
		_pixel(center + direction * half_length - normal * half_width),
		_pixel(center + direction * half_length + normal * half_width),
		_pixel(center - direction * half_length + normal * half_width),
	])


func _sample_clearances(world_position: Vector2, maximum_distance: float) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(CLEARANCE_RAY_COUNT)
	result.fill(maximum_distance)
	if not is_inside_tree() or obstacle_collision_mask == 0:
		return result
	var space_state := get_world_2d().direct_space_state
	for index in CLEARANCE_RAY_COUNT:
		var direction := Vector2.from_angle(TAU * float(index) / float(CLEARANCE_RAY_COUNT))
		var query := PhysicsRayQueryParameters2D.create(
			world_position,
			world_position + direction * maximum_distance,
			obstacle_collision_mask
		)
		query.collide_with_areas = false
		var hit := space_state.intersect_ray(query)
		if not hit.is_empty():
			result[index] = maxf(2.0, world_position.distance_to(hit["position"]) - 1.0)
	return result


func _clearance_for_direction(direction: Vector2, clearances: PackedFloat32Array) -> float:
	if clearances.is_empty():
		return INF
	var angle := fposmod(direction.angle(), TAU)
	var index := int(roundf(angle / TAU * float(CLEARANCE_RAY_COUNT))) % CLEARANCE_RAY_COUNT
	return clearances[index]


func _local_direction(world_direction: Vector2) -> Vector2:
	if world_direction.is_zero_approx():
		return Vector2.ZERO
	return world_direction.rotated(-global_rotation).normalized()


func _vary_color(base_color: Color, rng: RandomNumberGenerator) -> Color:
	return Color.from_hsv(
		fposmod(base_color.h + rng.randf_range(-6.0 / 360.0, 6.0 / 360.0), 1.0),
		clampf(base_color.s * rng.randf_range(0.92, 1.08), 0.0, 1.0),
		clampf(base_color.v * rng.randf_range(0.92, 1.08), 0.0, 1.0),
		1.0
	)


func _with_alpha(color: Color, multiplier: float) -> Color:
	var result := color
	result.a *= clampf(multiplier, 0.0, 1.0)
	return result


func _pixel(point: Vector2) -> Vector2:
	return Vector2(roundf(point.x), roundf(point.y))
