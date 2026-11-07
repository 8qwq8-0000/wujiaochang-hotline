extends "res://preview_v2.gd"

const FRAME_OUTPUT := OUTPUT + "motion_frames_v2/"
const CARD_COUNT := 6
const CARD_SIZE := 68.0
const STRIDE := 77.0
const START_X := 85.0
const BASE_Y := 153.0
const FPS := 24.0

var cards: Array[Control] = []
var positions_x: Array[float] = []
var positions_y: Array[float] = []
var velocities_x: Array[float] = []
var velocities_y: Array[float] = []
var bumps: Array[float] = []


func capture() -> void:
	DirAccess.make_dir_recursive_absolute(FRAME_OUTPUT)
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 360)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	canvas = Control.new()
	canvas.size = Vector2(640, 360)
	viewport.add_child(canvas)
	rect(canvas, Rect2(0, 0, 640, 360), Color("171b1e"))
	label(canvas, "义体自动补位", Vector2(40, 28), 20, TEXT)
	label(canvas, "拖动后沿轨道回弹", Vector2(40, 57), 12, MUTED)
	tex(canvas, SOURCE_V2 + "energy_bus_backbone_v1.png", Rect2(65, 201, 520, 91))
	rect(canvas, Rect2(94, 263, 445, 2), Color(AMBER, 0.24))
	rect(canvas, Rect2(94, 263, 242, 3), AMBER)
	for index in CARD_COUNT:
		var card := Control.new()
		card.size = Vector2.ONE * CARD_SIZE
		canvas.add_child(card)
		rect(card, Rect2(9, 9, 50, 50), Color(0.07, 0.10, 0.11, 0.96))
		tex(card, BASE + "assets/art/items/equipment_v1/" + ICONS[index] + "_64.png", Rect2(15, 15, 38, 38))
		tex(card, SOURCE_V2 + "cyberware_socket_bezel_v1.png", Rect2(0, 0, CARD_SIZE, CARD_SIZE))
		cards.append(card)
		positions_x.append(START_X + index * STRIDE)
		positions_y.append(BASE_Y)
		velocities_x.append(0.0)
		velocities_y.append(0.0)
		bumps.append(0.0)
	for frame in 36:
		advance_frame(frame)
		await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(FRAME_OUTPUT + "frame_%03d.png" % frame)
	print("Motion preview frames captured")
	quit()


func advance_frame(frame: int) -> void:
	var dt := 1.0 / FPS
	var targets_x: Array[float] = []
	var targets_y: Array[float] = []
	for index in CARD_COUNT:
		var target_x := START_X + index * STRIDE
		var target_y := BASE_Y
		if frame >= 5 and index > 2 and index < 5:
			target_x -= STRIDE
		if index == 2 and frame >= 5:
			target_x = 245.0 if frame < 10 else START_X + 4.0 * STRIDE
			target_y = 68.0 if frame < 16 else BASE_Y
		if frame >= 16:
			if index == 3:
				target_x = START_X + 2.0 * STRIDE
			elif index == 4:
				target_x = START_X + 3.0 * STRIDE
		targets_x.append(target_x)
		targets_y.append(target_y)
	for index in CARD_COUNT:
		velocities_x[index] += (targets_x[index] - positions_x[index]) * 170.0 * dt
		velocities_y[index] += (targets_y[index] - positions_y[index]) * 170.0 * dt
		velocities_x[index] *= exp(-12.0 * dt)
		velocities_y[index] *= exp(-12.0 * dt)
		positions_x[index] += velocities_x[index] * dt
		positions_y[index] += velocities_y[index] * dt
		bumps[index] = move_toward(bumps[index], 0.0, 2.0 * dt)
	for index in CARD_COUNT:
		for other in range(index + 1, CARD_COUNT):
			if absf(positions_y[index] - positions_y[other]) > 46.0:
				continue
			var distance := positions_x[other] - positions_x[index]
			var overlap := CARD_SIZE - absf(distance)
			if overlap <= 0.0:
				continue
			var direction := 1.0 if distance >= 0.0 else -1.0
			positions_x[index] -= direction * overlap * 0.5
			positions_x[other] += direction * overlap * 0.5
			velocities_x[index] -= direction * overlap * 2.5
			velocities_x[other] += direction * overlap * 2.5
			bumps[index] = 1.0
			bumps[other] = 1.0
	for index in CARD_COUNT:
		cards[index].position = Vector2(positions_x[index], positions_y[index])
		cards[index].scale = Vector2.ONE * (1.0 + bumps[index] * 0.08 + (0.07 if index == 2 and frame >= 5 and frame < 16 else 0.0))
		cards[index].rotation = (sin(float(frame) * 0.65) * 0.045 if index == 2 and frame >= 5 and frame < 16 else velocities_x[index] * 0.0004)
		cards[index].z_index = 2 if index == 2 and frame >= 5 and frame < 16 else 0
