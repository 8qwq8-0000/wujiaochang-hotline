class_name ChannelShrineRoom
extends ChannelTaskRoom

const ALTAR_ART := preload("res://assets/art/environment/hidden_shrine_v1/altar.tres")
const CORE_ART := preload("res://assets/art/environment/hidden_shrine_v1/core.tres")
var exit_elevator: ExitElevator
var entrance_barrier: CollisionShape2D
var _altar: Sprite2D
var _core: Sprite2D
var _altar_prompt: Label


func _ready() -> void:
	add_to_group("environment_areas")
	y_sort_enabled = true
	# Use the ordinary floors' real modular renderer and source textures.
	var ordinary_layout := CombatLayoutData.new()
	ordinary_layout.id = &"loading_workshop"
	ordinary_layout.room_size = SIZE
	ordinary_layout.covers.assign([
		# Staggered partitions leave upper, middle and lower flanking routes.
		Rect2(184, 16, 12, 112), Rect2(352, 232, 12, 112),
		Rect2(80, 58, 60, 36),
		Rect2(344, 86, 52, 32), Rect2(148, 272, 52, 34),
	])
	ordinary_layout.zones.assign([Rect2(24, 132, 140, 96), Rect2(212, 96, 194, 136), Rect2(492, 100, 116, 138)])
	var floor_art := WorkshopArt.new()
	floor_art.name = "OrdinaryShrineFloor"
	floor_art.layout = ordinary_layout
	floor_art.floor_pass = true
	floor_art.z_index = -5
	add_child(floor_art)
	var foreground := WorkshopArt.new()
	foreground.name = "OrdinaryShrineArchitecture"
	foreground.layout = ordinary_layout
	foreground.left_open = true
	add_child(foreground)
	var solids: Array[Rect2] = [Rect2(0, 0, 640, 16), Rect2(0, 344, 640, 16), Rect2(624, 0, 16, 360), Rect2(0, 0, 16, 132), Rect2(0, 228, 16, 132), Rect2(520, 160, 60, 44)]
	solids.append_array(ordinary_layout.covers)
	for rect in solids:
		_add_solid(rect)
	var barrier := StaticBody2D.new()
	barrier.position = Vector2(16, 180)
	barrier.collision_layer = 1
	barrier.collision_mask = 0
	entrance_barrier = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 96)
	entrance_barrier.shape = shape
	entrance_barrier.disabled = true
	barrier.add_child(entrance_barrier)
	add_child(barrier)
	for child in get_children():
		if child is StaticBody2D:
			for visual in child.get_children():
				if visual is Polygon2D:
					visual.hide()
	var data := CombatLayoutData.new()
	data.room_size = SIZE
	data.covers.assign(solids)
	var navigation := NavigationRegion2D.new()
	navigation.navigation_polygon = data.navigation_polygon()
	add_child(navigation)
	_build_ascent_door()
	terminal = ChannelTerminal.new()
	terminal.position = Vector2(550, 180)
	terminal.title = "祭坛 / 清理守卫"
	terminal.enabled = false
	terminal.action = terminal_action
	terminal.modulate.a = 0.0
	add_child(terminal)
	_altar = Sprite2D.new()
	_altar.name = "AltarArt"
	_altar.texture = ALTAR_ART
	_altar.centered = false
	_altar.position = Vector2(505, 196)
	_altar.offset.y = -ALTAR_ART.get_height()
	_altar.scale = Vector2(90, 75) / Vector2(ALTAR_ART.get_size())
	_altar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_altar)
	_core = Sprite2D.new()
	_core.name = "CoreArt"
	_core.texture = CORE_ART
	_core.position = Vector2(550, 121)
	_core.scale = Vector2(28, 34) / Vector2(CORE_ART.get_size())
	_core.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_core.z_index = 1
	_core.hide()
	add_child(_core)
	for is_floor: bool in [true, false]:
		var signal_fx := preload("res://scripts/presentation/shrine_signal_effect.gd").new()
		signal_fx.name = "AltarFloorBeacon" if is_floor else "AltarSignalParticles"
		signal_fx.position = Vector2(550, 180)
		signal_fx.floor_pass = is_floor
		signal_fx.z_index = -2 if is_floor else 2
		add_child(signal_fx)

	_altar_prompt = Label.new()
	_altar_prompt.theme = CyberUITheme.create_theme()
	_altar_prompt.position = Vector2(425, 70)
	_altar_prompt.size = Vector2(200, 20)
	_altar_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_altar_prompt.add_theme_font_size_override("font_size", 11)
	_altar_prompt.add_theme_color_override("font_color", Color("a6dce5"))
	_altar_prompt.add_theme_color_override("font_outline_color", Color("09101a"))
	_altar_prompt.add_theme_constant_override("outline_size", 2)
	_altar_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_altar_prompt.z_index = 30
	_altar_prompt.hide()
	add_child(_altar_prompt)


func _build_ascent_door() -> void:
	exit_elevator = ExitElevator.new()
	exit_elevator.name = "ShrineAscentDoor"
	exit_elevator.position = Vector2(588, 288)
	exit_elevator.collision_layer = 64
	exit_elevator.collision_mask = 2
	exit_elevator.ascent_only = true
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(38, 56)
	collider.shape = shape
	exit_elevator.add_child(collider)
	add_child(exit_elevator)
	exit_elevator.set_enabled(false)


func start() -> void:
	if started:
		return
	entrance_barrier.set_deferred("disabled", false)
	super.start()
	queue_redraw()


func _spawn_wave() -> void:
	var profiles := ["heavy_anchor", "heavy_anchor", "ranged_sightline", "ranged_sightline", "ranged_sightline"]
	var positions := [Vector2(246, 120), Vector2(380, 268), Vector2(436, 100), Vector2(534, 294), Vector2(586, 104)]
	for index in profiles.size():
		var enemy: EnemyController = load(EnemySpawner.ENEMY_SCENE_PATH).instantiate()
		enemy.profile = load("res://resources/enemies/" + profiles[index] + ".tres").duplicate()
		enemy.profile.full_room_awareness = true
		enemy.position = positions[index]
		enemy.mandatory = false
		add_child(enemy)
		enemies.append(enemy)
		enemy.defeated.connect(_on_defeated)


func _on_defeated(_enemy: EnemyController, _mandatory: bool) -> void:
	if not living_enemies().is_empty() or cleared:
		return
	restore_cleared()
	room_cleared.emit()


func restore_cleared() -> void:
	started = true
	cleared = true
	entrance_barrier.set_deferred("disabled", true)
	terminal.enabled = true
	exit_elevator.set_enabled(true)
	terminal.title = "祭坛 / 残损频道核心"
	queue_redraw()


func _process(_delta: float) -> void:
	_core.visible = cleared and terminal.enabled
	_core.position.y = 121 + sin(Time.get_ticks_msec() * 0.003) * 2
	_altar.modulate = Color.WHITE if terminal.enabled or not cleared else Color(0.68, 0.7, 0.78)
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	_altar_prompt.visible = cleared and player != null and player.global_position.distance_to(terminal.global_position) < 110
	_altar_prompt.text = "残损频道核心 / [E] 查看" if terminal.enabled else "核心已取走"


func _draw() -> void:
	if started and not cleared:
		draw_line(Vector2(16, 132), Vector2(16, 228), Color("e37662"), 3)
