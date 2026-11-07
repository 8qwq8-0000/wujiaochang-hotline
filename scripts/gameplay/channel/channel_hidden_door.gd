class_name ChannelHiddenDoor
extends StaticBody2D

signal broken
enum State { SEALED, BROKEN }
const HITS_TO_OPEN := 3
var state := State.SEALED
var available := false
var hits_received := 0
const IMPACT_SECONDS := 0.18
const BREAK_SECONDS := 0.48
var _break_elapsed := BREAK_SECONDS
var _impact_remaining := 0.0
var _hit_material: ShaderMaterial
var _door_texture: Texture2D
var _shape: CollisionShape2D


func _ready() -> void:
	_door_texture = ExitElevator.door_texture()
	collision_layer = 1
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 96)
	_shape.shape = shape
	add_child(_shape)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
	uniform float hit_flash = 0.0;
	uniform float fracture = 0.0;
	varying vec2 door_pixel;
	void vertex() { door_pixel = VERTEX; }
	void fragment() {
		vec4 base = texture(TEXTURE, UV) * COLOR;
		if (base.a < 0.04) { discard; }
		// Tear only the inner steel leaf; preserve the authored frame and step.
		float tooth = mod(floor((door_pixel.y + 30.0) / 5.0), 2.0) * 1.4;
		float opening = (3.1 + tooth) * smoothstep(0.0, 0.7, fracture);
		if (fracture > 0.0 && abs(door_pixel.x + 7.8) < opening && abs(door_pixel.y + 1.0) < 29.0 * fracture) { discard; }
		COLOR = vec4(mix(base.rgb, vec3(1.0), hit_flash), base.a);
	}"""
	_hit_material = ShaderMaterial.new()
	_hit_material.shader = shader
	material = _hit_material
	set_process(false)


func receive_projectile_hit(packet: DamagePacket) -> void:
	if not available or state != State.SEALED or get_tree().paused or packet == null:
		return
	if packet.source_faction != CombatFaction.Id.PLAYER or not (packet.is_projectile or packet.is_beam) or packet.base_damage <= 0:
		return
	hits_received += 1
	_impact_remaining = IMPACT_SECONDS
	_hit_material.set_shader_parameter("hit_flash", 0.85)
	set_process(true)
	if hits_received >= HITS_TO_OPEN:
		break_open()
	else:
		queue_redraw()


func _process(delta: float) -> void:
	_impact_remaining = maxf(0.0, _impact_remaining - delta)
	var fraction := _impact_remaining / IMPACT_SECONDS
	_hit_material.set_shader_parameter("hit_flash", fraction * fraction * 0.85)
	if state == State.BROKEN:
		_break_elapsed = minf(BREAK_SECONDS, _break_elapsed + delta)
		_hit_material.set_shader_parameter("fracture", _break_elapsed / BREAK_SECONDS)
	queue_redraw()
	if _impact_remaining <= 0.0 and _break_elapsed >= BREAK_SECONDS:
		set_process(false)


func break_open(animate: bool = true) -> void:
	if state == State.BROKEN:
		return
	state = State.BROKEN
	_break_elapsed = 0.0 if animate else BREAK_SECONDS
	_hit_material.set_shader_parameter("fracture", 0.0 if animate else 1.0)
	set_process(animate)
	_shape.set_deferred("disabled", true)
	queue_redraw()
	broken.emit()


func _draw() -> void:
	# Visual recoil only; the physical door and camera stay fixed.
	var fraction := _impact_remaining / IMPACT_SECONDS
	var elapsed := IMPACT_SECONDS - _impact_remaining
	var shake := Vector2(sin(elapsed * 105.0) * 2.5, sin(elapsed * 73.0) * 0.8) * fraction
	draw_set_transform(shake)
	# Keep the normal elevator frame while tearing a hole through the inner leaf.
	var size := _door_texture.get_size() * ExitElevator.DOOR_SCALE
	var rect := Rect2(Vector2(-9, -6) - size * 0.5, size)
	draw_texture_rect(_door_texture, rect, false, Color.WHITE if state == State.BROKEN else Color(0.78, 0.8, 0.83))
	if state == State.BROKEN:
		_draw_broken_leaf()
		return
	# Successive impacts leave persistent dents and torn seams in the steel.
	for index in mini(hits_received, HITS_TO_OPEN - 1):
		var center := Vector2(-9, -17 + index * 34)
		var crack := PackedVector2Array([center + Vector2(-6, -7), center + Vector2(1, -2), center + Vector2(-3, 2), center + Vector2(5, 8)])
		draw_polyline(crack, Color("101721"), 3)
		draw_polyline(crack, Color("c17d49"), 1)
		draw_line(center + Vector2(-6, 5), center + Vector2(5, -4), Color("94a9b6"), 1)


func _draw_broken_leaf() -> void:
	var progress := _break_elapsed / BREAK_SECONDS
	# Jagged cut edges expose torn metal without replacing the full doorway.
	for side: int in [-1, 1]:
		var edge := PackedVector2Array()
		for index in 13:
			var y := -30.0 + index * 5.0
			edge.append(Vector2(-7.8 + side * (3.1 + (index % 2) * 1.4) * minf(progress / 0.7, 1.0), y * progress))
		draw_polyline(edge, Color(0.56, 0.65, 0.7, progress * 0.9), 1)
	# Small plates kick out, drop and fade. These are harmless visual debris.
	if progress < 1.0:
		for index in 7:
			var t := progress * BREAK_SECONDS
			var point := Vector2(-11 - (20 + index % 3 * 22) * t, -24 + index * 8 - 20 * t + 100 * t * t)
			var angle := t * (5 + index)
			var polygon := PackedVector2Array()
			for corner: Vector2 in [Vector2(-2, -3), Vector2(2, -2), Vector2(3, 2), Vector2(-1, 3)]:
				polygon.append(point + corner.rotated(angle))
			draw_colored_polygon(polygon, Color(0.4, 0.48, 0.56, 1.0 - progress * progress))
			draw_line(point, point + Vector2(2, -1).rotated(angle), Color(0.85, 0.9, 0.91, 1.0 - progress), 1)
	# Settled fragments remain beside the threshold, rather than an explosion.
	if progress > 0.5:
		for index in 3:
			var point := Vector2(-22 - index * 4, 39 + index % 2 * 3)
			draw_colored_polygon(PackedVector2Array([point, point + Vector2(4, -1), point + Vector2(5, 2), point + Vector2(1, 3)]), Color(0.31, 0.38, 0.44, (progress - 0.5) * 2.0))
