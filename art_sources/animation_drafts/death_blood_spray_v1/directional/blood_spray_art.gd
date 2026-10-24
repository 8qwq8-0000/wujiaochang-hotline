extends RefCounted

const COLORS := [Color("4b1021"), Color("79172b"), Color("a12435"), Color("c83c45"), Color("e76461")]
var particles: Array[Dictionary] = []
var pools: Array[Dictionary] = []

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 24713
	for i in 31:
		particles.append({"delay": rng.randf_range(0, 0.10), "speed": rng.randf_range(35, 85), "vertical": rng.randf_range(-58, 6), "gravity": rng.randf_range(105, 165), "size": rng.randi_range(1, 3), "color": rng.randi_range(1, 3), "lane": rng.randf_range(-7, 7)})
	for i in 18:
		pools.append({"at": Vector2(rng.randf_range(1, 58), rng.randf_range(-8, 7)), "size": Vector2(rng.randi_range(1, 6), rng.randi_range(1, 3)), "delay": rng.randf_range(0.12, 0.5)})

func blob(canvas: Node2D, at: Vector2, dimensions: Vector2, color: Color) -> void:
	var extent := dimensions.round().max(Vector2.ONE)
	var p := (at - extent * 0.5).round()
	canvas.draw_rect(Rect2(p, extent), color)
	if extent.x >= 3 and extent.y >= 3:
		canvas.draw_rect(Rect2(p + Vector2(-1, 1), Vector2(extent.x + 2, extent.y - 2)), color)

func draw_frame(canvas: Node2D, age: float, heading: Vector2) -> void:
	var forward := heading.normalized()
	var side := forward.orthogonal()
	var floor_origin := Vector2(0, 19)
	# Direction turns on the floor plane; gravity always pulls toward the floor.
	if age > 0.18:
		var growth := clampf((age - 0.18) / 0.28, 0, 1)
		blob(canvas, floor_origin + forward * 7, Vector2(13, 5) * growth, COLORS[0])
		blob(canvas, floor_origin + forward * 10, Vector2(8, 3) * growth, COLORS[1])
	for pool in pools:
		if age > pool.delay:
			blob(canvas, floor_origin + forward * (4 + pool.at.x) + side * pool.at.y * 0.6, pool.size, COLORS[0] if int(pool.delay * 100) % 2 == 0 else COLORS[1])
	if age < 0.34:
		var reach := minf(1, (age + 0.045) / 0.17) * 53
		var collapse := clampf((0.35 - age) / 0.18, 0, 1)
		for lane in range(3):
			var previous := Vector2.ZERO
			for step in range(1, 15):
				var u := step / 14.0
				var point := forward * reach * u + side * (lane - 1) * 9 * u + Vector2.DOWN * (-sin(u * PI) * (6 + lane * 2) + age * age * 70 * u)
				if age < 0.16 or step % 4 != 0:
					canvas.draw_line(previous.round(), point.round(), COLORS[1 + lane], maxf(1, (5 - lane * 0.7) * (1 - u) * collapse), false)
				previous = point
		blob(canvas, forward * 4 + Vector2.UP, Vector2(8, 7) * collapse, COLORS[2])
		if age < 0.1:
			blob(canvas, forward * 3 + Vector2.UP * 2, Vector2(3, 3), COLORS[4])
	for particle in particles:
		var t: float = age - particle.delay
		if t <= 0:
			continue
		var height: float = 19 + particle.vertical * t + 0.5 * particle.gravity * t * t
		if height >= 38:
			continue
		var at: Vector2 = forward * particle.speed * t + side * particle.lane + Vector2.DOWN * (height - 19)
		var velocity: Vector2 = (forward * particle.speed + Vector2.DOWN * (particle.vertical + particle.gravity * t)).normalized()
		canvas.draw_line(at.round(), (at - velocity * clampf(4 - t * 7, 1, 4)).round(), COLORS[particle.color], particle.size, false)
		blob(canvas, at, Vector2(particle.size + 1, particle.size), COLORS[particle.color])
