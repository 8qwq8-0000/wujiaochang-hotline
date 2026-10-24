extends SceneTree

const DURATION := 2.4
const PALETTE := [Color("4b1021"), Color("79172b"), Color("a12435"), Color("c83c45"), Color("e76461")]
var _frame := 0
var _canvas: Node2D
var _actor: Sprite2D
var _floor_texture: Texture2D
var _phase: Label
var _particles: Array[Dictionary] = []
var _pools: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("build")

func build() -> void:
	var background := ColorRect.new()
	background.color = Color("081115")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.theme = CyberUITheme.create_theme()
	root.add_child(background)
	var title := Label.new()
	title.position = Vector2(32, 14)
	title.text = "死亡喷血 / 动画预览 01"
	title.add_theme_font_size_override("font_size", 18)
	background.add_child(title)
	_phase = Label.new()
	_phase.position = Vector2(405, 21)
	_phase.add_theme_font_size_override("font_size", 10)
	_phase.add_theme_color_override("font_color", CyberUITheme.MUTED)
	background.add_child(_phase)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(192, 88)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_2d = World2D.new()
	root.add_child(viewport)
	_canvas = Node2D.new()
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(_canvas)
	_canvas.draw.connect(draw_scene)
	_floor_texture = load("res://assets/art/environment/warehouse/floor.png")
	var frames := load("res://assets/art/characters/enemies/animated/melee_frames.tres") as SpriteFrames
	_actor = Sprite2D.new()
	_actor.texture = frames.get_frame_texture("idle_right", 0)
	_actor.centered = false
	_actor.offset = Vector2(-96, -168)
	_actor.scale = Vector2.ONE * 0.26
	_actor.position = Vector2(52, 66)
	_actor.z_index = 1
	_canvas.add_child(_actor)
	var preview := TextureRect.new()
	preview.position = Vector2(32, 55)
	preview.size = Vector2(576, 264)
	preview.texture = viewport.get_texture()
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.add_child(preview)
	var note := Label.new()
	note.position = Vector2(32, 330)
	note.text = "受击方向 → 喷射 → 血滴落地    /    仅动画草稿，未接入游戏"
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", CyberUITheme.MUTED)
	background.add_child(note)
	var rng := RandomNumberGenerator.new()
	rng.seed = 24713
	for i in 31:
		_particles.append({"delay": rng.randf_range(0, 0.10), "speed": rng.randf_range(35, 125), "vertical": rng.randf_range(-58, 6), "gravity": rng.randf_range(105, 165), "size": rng.randi_range(1, 3), "color": rng.randi_range(1, 3), "lane": rng.randf_range(-7, 7)})
	for i in 18:
		_pools.append({"at": Vector2(rng.randf_range(1, 62), rng.randf_range(-8, 7)), "size": Vector2(rng.randi_range(1, 6), rng.randi_range(1, 3)), "delay": rng.randf_range(0.12, 0.5)})
	_canvas.queue_redraw()

func _process(_delta: float) -> bool:
	if _canvas == null:
		return false
	_frame += 1
	var time := float(_frame) / 30.0
	var age := floorf(maxf(time - 0.4, 0) * 15.0) / 15.0
	_actor.modulate = Color.WHITE if time < 0.4 else Color(0.7, 0.5, 0.5, maxf(0, 1 - age * 5))
	_phase.text = "15 FPS · 命中前" if time < 0.4 else ("15 FPS · 定向喷射" if age < 0.32 else "15 FPS · 落地收尾")
	_canvas.queue_redraw()
	return false

func pixel_blob(at: Vector2, dimensions: Vector2, color: Color) -> void:
	var p := at.round()
	var extent := dimensions.round().max(Vector2.ONE)
	_canvas.draw_rect(Rect2(p - extent * 0.5, extent), color)
	if extent.x >= 3 and extent.y >= 3:
		_canvas.draw_rect(Rect2(p + Vector2(-extent.x * 0.5 - 1, -extent.y * 0.5 + 1), Vector2(extent.x + 2, extent.y - 2)), color)

func draw_scene() -> void:
	_canvas.draw_rect(Rect2(0, 0, 192, 88), Color("172329"))
	for y in range(0, 88, 16):
		for x in range(0, 192, 16):
			_canvas.draw_texture_rect(_floor_texture, Rect2(x, y, 16, 16), false, Color("829598"))
	for x in range(8, 184, 24):
		_canvas.draw_line(Vector2(x, 80), Vector2(x + 8, 80), Color("445b59"), 1)
	var time := float(_frame) / 30.0
	if time < 0.4:
		return
	var age := floorf((time - 0.4) * 15.0) / 15.0
	var origin := Vector2(52, 47)
	# Pool and settled droplets remain on the floor after the airborne spray.
	if age > 0.18:
		var growth := clampf((age - 0.18) / 0.28, 0.0, 1.0)
		pixel_blob(Vector2(59, 66), Vector2(13 * growth, 5 * growth), PALETTE[0])
		pixel_blob(Vector2(62, 65), Vector2(8 * growth, 3 * growth), PALETTE[1])
	for pool in _pools:
		if age > pool.delay:
			pixel_blob(Vector2(56, 66) + pool.at, pool.size, PALETTE[0] if int(pool.delay * 100) % 2 == 0 else PALETTE[1])
	# Three connected tapered ribbons, opening quickly and breaking into drops.
	if age < 0.34:
		var reach := minf(1.0, (age + 0.045) / 0.17) * 53.0
		var collapse := clampf((0.35 - age) / 0.18, 0, 1)
		for lane in range(3):
			var previous := origin
			for step in range(1, 15):
				var u := step / 14.0
				var point := origin + Vector2(reach * u, (lane - 1) * 9 * u - sin(u * PI) * (6 + lane * 2) + age * age * 70 * u)
				var width := maxf(1, (5 - lane * 0.7) * (1 - u) * collapse)
				if age < 0.16 or step % 4 != 0:
					_canvas.draw_line(previous.round(), point.round(), PALETTE[1 + lane], width, false)
				previous = point
		pixel_blob(origin + Vector2(4, -1), Vector2(8, 7) * collapse, PALETTE[2])
		if age < 0.1:
			pixel_blob(origin + Vector2(3, -2), Vector2(3, 3), PALETTE[4])
	for particle in _particles:
		var t: float = age - particle.delay
		if t <= 0:
			continue
		var at := origin + Vector2(particle.speed * t, particle.vertical * t + 0.5 * particle.gravity * t * t + particle.lane)
		var floor_y: float = 66 + particle.lane * 0.6
		if at.y >= floor_y:
			continue
		var velocity := Vector2(particle.speed, particle.vertical + particle.gravity * t).normalized()
		var tail: float = clampf(4 - t * 7, 1, 4)
		_canvas.draw_line(at.round(), (at - velocity * tail).round(), PALETTE[particle.color], particle.size, false)
		pixel_blob(at, Vector2(particle.size + 1, particle.size), PALETTE[particle.color])
