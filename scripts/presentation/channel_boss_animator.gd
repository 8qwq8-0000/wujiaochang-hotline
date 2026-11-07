class_name ChannelBossAnimator
extends AnimatedSprite2D

const FRAMES := preload("res://assets/art/characters/bosses/rooftop_whale_goddess/channel_returned_v1/frames.tres")
const TAIL_SHADER := preload("res://shaders/channel_boss_tail.gdshader")
const FRAME_CELL := Vector2(384, 512)
const HIT_TIME := 0.18
const IDLE := &"idle"
const HALO_POSES := [-0.74, -0.40, 0.0, 0.10, 0.26, 0.46, 0.64]
const PROTECT_POSES := [-0.54, -0.34, -0.14, 0.0, 0.11, 0.28, 0.45]

var _drift := 0.0
var _glide := 0.0
var _hover_phase := 0.0
var _idle_clock := 0.0
var _hit_flash := 0.0
var _cast: StringName
var _cast_clock := 0.0
var _first_release := 0.0
var _echo_interval := 0.0
var _release := 0.0
var _recovering := false
var _tail_side := 1.0
var _tail_rig: MeshInstance2D
var _tail_quad: QuadMesh
var _tail_material: ShaderMaterial


func _ready() -> void:
	sprite_frames = FRAMES
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = false
	offset = Vector2(-192, -470)
	scale = Vector2.ONE * 0.4
	animation = IDLE
	_tail_quad = QuadMesh.new()
	_tail_quad.subdivide_width = 31
	_tail_quad.subdivide_depth = 47
	_tail_material = ShaderMaterial.new()
	_tail_material.shader = TAIL_SHADER
	_tail_rig = MeshInstance2D.new()
	_tail_rig.mesh = _tail_quad
	_tail_rig.material = _tail_material
	_tail_rig.hide()
	add_child(_tail_rig)


func _process(delta: float) -> void:
	if _recovering:
		update_cast(_cast_clock + delta)
		if _cast_clock >= _first_release + 2.0 * _echo_interval + 0.20:
			_resume_idle()
	_glide = lerpf(_glide, _drift, 1.0 - exp(-delta * 8.0))
	var motion := absf(_glide)
	_hover_phase = fposmod(_hover_phase + delta * (2.4 + 0.7 * motion), TAU)
	_idle_clock = fposmod(_idle_clock + delta * lerpf(4.2, 6.2, motion), 8.0)
	_hit_flash = maxf(_hit_flash - delta, 0.0)
	var hover_weight := 1.0 if _cast == &"" else 0.45
	position.y = sin(_hover_phase) * (2.0 + motion) * hover_weight + _release * 2.0
	rotation = _glide * 0.032
	if _cast == &"tail":
		var stroke := _tail_stroke(_cast_clock - _first_release)
		rotation += _tail_side * 0.047 * stroke
		_tail_material.set_shader_parameter(&"stroke", stroke)
	var cast_color := Color(1.20, 1.09, 0.87) if _cast == &"halo" else Color(0.85, 1.11, 1.18)
	var tint := Color.WHITE.lerp(cast_color, _release).lerp(Color(1.34, 0.83, 0.74), _hit_flash / HIT_TIME)
	self_modulate = Color(tint, 0.0) if _cast == &"tail" else tint
	_tail_rig.self_modulate = tint
	if _cast == &"":
		set_frame_and_progress(int(_idle_clock), 0.0)


func play_cast(skill: StringName, first_release: float, echo_interval := 0.0) -> void:
	_tail_rig.hide()
	_cast = skill
	_drift = 0.0
	_first_release = first_release
	_echo_interval = echo_interval
	_recovering = false
	animation = skill
	update_cast(0.0)


func play_tail(aim_x: float) -> void:
	var pose := FRAMES.get_frame_texture(IDLE, int(_idle_clock)) as AtlasTexture
	var region := pose.region
	var atlas_size := pose.atlas.get_size()
	_tail_quad.size = region.size
	_tail_rig.texture = pose.atlas
	_tail_rig.position = offset + pose.margin.position + region.size * 0.5
	_tail_material.set_shader_parameter(&"atlas_region", Vector4(
		region.position.x / atlas_size.x, region.position.y / atlas_size.y,
		region.size.x / atlas_size.x, region.size.y / atlas_size.y))
	_tail_material.set_shader_parameter(&"frame_origin", Vector2(
		fposmod(region.position.x, FRAME_CELL.x), fposmod(region.position.y, FRAME_CELL.y)))
	_tail_material.set_shader_parameter(&"region_size", region.size)
	_tail_material.set_shader_parameter(&"stroke", 0.0)
	_tail_rig.show()
	_tail_side = -1.0 if aim_x < 0.0 else 1.0
	_cast = &"tail"
	_drift = 0.0
	_recovering = false
	_first_release = ChannelBossEffect.TAIL_WARNING
	animation = IDLE
	update_cast(0.0)


func _tail_stroke(since_release: float) -> float:
	var coil := -0.64 * smoothstep(-_first_release, -0.065, since_release)
	var snap := smoothstep(-0.048, 0.012, since_release)
	var settle := smoothstep(0.025, ChannelBossEffect.TAIL_FADE, since_release)
	return lerpf(coil, 1.0 - settle, snap)


func update_cast(clock: float) -> void:
	_cast_clock = clock
	var pose := 0
	var since_release := clock - _first_release
	match _cast:
		&"echo":
			if since_release < 0.0:
				pose = _pose_at(since_release, [-0.8, -0.16])
			else:
				var beat := mini(int(since_release / _echo_interval), 2)
				since_release -= beat * _echo_interval
				if beat < 2 and since_release >= _echo_interval - 0.16:
					pose = 2
				else:
					pose = 3 + _pose_at(since_release, [0.06, 0.18, 0.27, 0.34])
		&"halo":
			pose = _pose_at(since_release, HALO_POSES)
		&"protect":
			pose = _pose_at(since_release, PROTECT_POSES)
		&"tail":
			pose = frame
	_release = 1.0 - smoothstep(0.0, 0.20, since_release) if since_release >= 0.0 else 0.0
	set_frame_and_progress(pose, 0.0)


func _pose_at(clock: float, boundaries: Array) -> int:
	var pose := 0
	for boundary in boundaries:
		if clock < boundary:
			break
		pose += 1
	return pose


func update_motion(drift: float) -> void:
	_drift = clampf(drift, -1.0, 1.0)
	if _cast == &"echo":
		# The last impact lands just before gameplay recovery starts. Let its pose settle.
		_recovering = true
	elif _cast != &"":
		_resume_idle()


func _resume_idle() -> void:
	_tail_rig.hide()
	_recovering = false
	_cast = &""
	_release = 0.0
	animation = IDLE
	set_frame_and_progress(int(_idle_clock), 0.0)


func flash_hit(_amount: int, _packet: DamagePacket) -> void:
	_hit_flash = HIT_TIME


func freeze(defeated: bool) -> void:
	set_process(false)
	if defeated:
		_resume_idle()
		position = Vector2.ZERO
		rotation = 0.0
		self_modulate = Color(0.75, 0.84, 0.94, 0.65)
