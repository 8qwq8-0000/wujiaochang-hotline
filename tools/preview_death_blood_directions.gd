extends SceneTree

const ART := preload("res://art_sources/animation_drafts/death_blood_spray_v1/directional/blood_spray_art.gd")
const NAMES := ["右", "右下22°", "右下45°", "右下67°", "下", "左下67°", "左下45°", "左下22°", "左", "左上22°", "左上45°", "左上67°", "上", "右上67°", "右上45°", "右上22°"]
var age := 0.0
var frame_index := 0
var models: Array[Node2D] = []
var arts: Array = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var canvas := Node2D.new()
	root.add_child(canvas)
	canvas.draw.connect(func() -> void:
		canvas.draw_rect(Rect2(0, 0, 640, 360), Color("0b151a"))
		canvas.draw_string(CyberUITheme.FONT, Vector2(20, 24), "死亡喷血 / 16 个受击方向", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, CyberUITheme.HIGHLIGHT)
		canvas.draw_string(CyberUITheme.FONT, Vector2(20, 349), "箭头 = 最后一击推进方向    ·    统一喷射锚点 / 15 FPS", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, CyberUITheme.MUTED)
	)
	for sector in 16:
		var center := Vector2(92 + (sector % 4) * 152, 72 + (sector / 4) * 76)
		var cell := Node2D.new()
		cell.position = center
		canvas.add_child(cell)
		var direction := Vector2.RIGHT.rotated(sector * TAU / 16.0)
		var model := ART.new()
		arts.append(model)
		cell.draw.connect(func() -> void:
			cell.draw_rect(Rect2(-72, -30, 144, 70), Color("14252a"))
			cell.draw_line(Vector2.ZERO, direction * 17, Color("517368"), 1)
			cell.draw_line(direction * 17, direction.rotated(0.45) * 11, Color("517368"), 1)
			cell.draw_line(direction * 17, direction.rotated(-0.45) * 11, Color("517368"), 1)
			cell.draw_string(CyberUITheme.FONT, Vector2(-61, 34), "%02d / %s" % [sector, NAMES[sector]], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("93b5ac"))
			cell.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * 0.65)
			if age >= 0:
				model.draw_frame(cell, age, direction)
		)
		models.append(cell)

func _process(_delta: float) -> bool:
	frame_index += 1
	age = floorf((frame_index / 30.0 - 0.3) * 15) / 15.0
	for canvas in models:
		canvas.queue_redraw()
	return false
