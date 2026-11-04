extends Node2D

## Isolated visual preview. No damage, ending, or save progression is committed.
const ART := "res://art_sources/ai_drafts/rooftop_boss/"
const SKILLS := ["echo", "halo", "protect"]
const TITLES := ["回声落点", "光环裁断", "护子震波"]
const CAST_DURATIONS := [0.35, 0.16, 0.18, 0.12, 0.16, 0.16, 0.16, 0.55]
const FX_DURATIONS := {
	"echo": [0.26, 0.18, 0.22, 0.14, 0.10, 0.11, 0.14, 0.40],
	"halo": [0.26, 0.22, 0.20, 0.10, 0.11, 0.10, 0.14, 0.42],
	"protect": [0.16, 0.10, 0.10, 0.10, 0.10, 0.10, 0.14, 0.42],
}

var player: PlayerController
var actor: Node2D
var body: Sprite2D
var caption: Label
var controls: Label
var textures: Dictionary = {}
var effects: Array[Dictionary] = []
var cast := ""
var cast_clock := 0.0
var total_clock := 0.0
var cycle_clock := 3.5
var sequence := 0
var automatic := true
var next_echo := -1.0
var echo_count := 0
var pulse_pending := false
var skills_shown := [0, 0, 0]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for clip in ["idle", "move", "echo", "halo", "protect"]:
		var frames: Array[Texture2D] = []
		for index in 8:
			var file := ART + "skills_v1/%s/frames/%s_%02d.png" % [clip, clip, index]
			if clip == "idle":
				file = ART + "idle_v1/frames/idle_%02d.png" % index
			elif clip == "move":
				file = ART + "move_front_v2/frames/move_%02d.png" % index
			frames.append(_load_png(file))
		textures[clip] = frames
	for skill in SKILLS:
		var frames: Array[Texture2D] = []
		for index in 8:
			frames.append(_load_png(ART + "attack_vfx_v1/%s/frames/%s_%02d.png" % [skill, skill, index]))
		textures["fx_" + skill] = frames
	actor = Node2D.new()
	actor.name = "ChannelGoddess"
	actor.position = Vector2(480, 315)
	actor.z_index = 12
	add_child(actor)
	body = Sprite2D.new()
	body.centered = false
	body.position = Vector2(-192, -462) * 0.4
	body.scale = Vector2.ONE * 0.4
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.texture = textures.idle[0]
	actor.add_child(body)
	_build_ui()


func _load_png(path: String) -> Texture2D:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	assert(image != null and not image.is_empty(), "Missing preview image: " + path)
	return ImageTexture.create_from_image(image)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0.025, 0.045, 0.08, 0.91)
	panel.position = Vector2(8, 8)
	panel.size = Vector2(624, 44)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	caption = Label.new()
	caption.theme = CyberUITheme.create_theme()
	caption.position = Vector2(18, 10)
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", Color("e8d8b2"))
	caption.text = "频道归还 · 女神动作与攻击特效预览"
	layer.add_child(caption)
	controls = Label.new()
	controls.theme = CyberUITheme.create_theme()
	controls.position = Vector2(18, 32)
	controls.add_theme_font_size_override("font_size", 10)
	controls.text = "WASD 移动  |  1 回声  2 光柱  3 震波  |  空格 自动  |  P 暂停  |  预览不扣血"
	layer.add_child(controls)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key in [KEY_1, KEY_2, KEY_3]:
		get_tree().paused = false
		automatic = false
		play_skill(int(key - KEY_1))
	elif key == KEY_SPACE:
		automatic = not automatic
		cycle_clock = 4.0
		caption.text = "频道归还 · " + ("自动轮播" if automatic else "手动预览：按 1 / 2 / 3")
	elif key == KEY_P:
		get_tree().paused = not get_tree().paused
	elif key == KEY_ESCAPE:
		get_tree().quit()
	else:
		return
	get_viewport().set_input_as_handled()


func play_skill(index: int) -> void:
	clear_effects()
	cast = SKILLS[index]
	cast_clock = 0.0
	skills_shown[index] += 1
	caption.text = TITLES[index] + "  /  " + ("自动轮播" if automatic else "手动预览")
	next_echo = 0.25 if index == 0 else -1.0
	echo_count = 0
	pulse_pending = index == 2
	if index == 1:
		# Ground footprint stays at the selected target, rather than following the player.
		var target := Vector2(clampf(player.position.x, 310, 650), clampf(player.position.y, 370, 460))
		_spawn_effect("halo", target, Vector2.ONE * 0.7, Vector2(222, 354))
	body.texture = textures[cast][0]
	sequence = (index + 1) % 3
	cycle_clock = 0.0


func clear_effects() -> void:
	for effect in effects:
		(effect.sprite as Sprite2D).queue_free()
	effects.clear()
	next_echo = -1.0
	pulse_pending = false


func _spawn_effect(skill: String, target: Vector2, size: Vector2, anchor: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = target - anchor * size
	sprite.scale = size
	sprite.z_index = 20 if skill == "halo" else 9
	sprite.texture = textures["fx_" + skill][0]
	add_child(sprite)
	effects.append({"sprite": sprite, "skill": skill, "clock": 0.0})


func _frame_at(clock: float, durations: Array) -> int:
	var boundary := 0.0
	for index in durations.size():
		boundary += float(durations[index])
		if clock < boundary:
			return index
	return -1


func _process(delta: float) -> void:
	if not is_instance_valid(body) or get_tree().paused:
		return
	total_clock += delta
	cycle_clock += delta
	if automatic and cycle_clock >= 4.6:
		play_skill(sequence)
	if not cast.is_empty():
		cast_clock += delta
		var frame := _frame_at(cast_clock, CAST_DURATIONS)
		if frame < 0:
			cast = ""
		else:
			body.texture = textures[cast][frame]
		if next_echo >= 0.0 and cast_clock >= next_echo:
			var target := player.position.clamp(Vector2(200, 220), Vector2(760, 475))
			_spawn_effect("echo", target, Vector2.ONE * 0.28, Vector2(222, 244))
			echo_count += 1
			next_echo = next_echo + 0.48 if echo_count < 3 else -1.0
		if pulse_pending and cast_clock >= 0.70:
			_spawn_effect("protect", actor.position - Vector2(0, 8), Vector2.ONE * 1.25, Vector2(222, 228))
			pulse_pending = false
	else:
		actor.position.x = move_toward(actor.position.x, 480 + sin(total_clock * 0.32) * 45, delta * 15)
		body.texture = textures.move[int(total_clock / 0.18) % 8]
	for index in range(effects.size() - 1, -1, -1):
		var effect := effects[index]
		effect.clock += delta
		var frame := _frame_at(effect.clock, FX_DURATIONS[effect.skill])
		if frame < 0:
			(effect.sprite as Sprite2D).queue_free()
			effects.remove_at(index)
		else:
			(effect.sprite as Sprite2D).texture = textures["fx_" + effect.skill][frame]
