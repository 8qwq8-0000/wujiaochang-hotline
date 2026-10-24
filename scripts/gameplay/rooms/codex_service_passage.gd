extends Node2D

const FLOOR_PATH := "res://scenes/levels/floors/combat_prototype.tscn"
var dialogue_completed := false
var departing := false
var chest: Inventory
var panel: CanvasLayer
var upgrade_panel: CanvasLayer
var last_synthesis_result: InventoryItem
var _mutating := false
var _art: Node2D = preload("res://scripts/presentation/warehouse_art.gd").new()
@onready var player: PlayerController = $Player
@onready var run: Node = get_node("/root/RunManager")

func _ready() -> void:
	add_to_group("intermission")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var floor_art := Node2D.new()
	floor_art.name = "FloorArt"
	floor_art.z_index = -10
	add_child(floor_art)
	floor_art.draw.connect(_draw_floor.bind(floor_art))
	floor_art.queue_redraw()
	chest = Inventory.new()
	chest.protoset = ComponentInventory.PROTOTYPES
	add_child(chest)
	panel = preload("res://scripts/ui/codex_dialogue_panel.gd").new()
	panel.player = player
	panel.completed.connect(_on_dialogue_completed)
	add_child(panel)
	upgrade_panel = preload("res://scripts/ui/synthesis_panel.gd").new()
	upgrade_panel.room = self
	upgrade_panel.heading_text = "Codex 的通道合成台"
	upgrade_panel.empty_text = "没有可合成组件\n可继续前往第三层"
	add_child(upgrade_panel)
	player.camera.enabled = false
	var camera := Camera2D.new()
	camera.position = Vector2(320, 180)
	add_child(camera)
	camera.make_current()
	player.import_run_state(run.get_player_state())
	run.set_mandatory_enemy_count(0)
	for label in find_children("*", "Label", true, false):
		label.add_theme_font_override("font", CyberUITheme.FONT)
	queue_redraw()

func receive_scene_payload(payload: Dictionary) -> void:
	if payload.has("player_state"):
		player.import_run_state(payload.player_state)
	if payload.has("transit_heat"):
		player.heat.set_heat(float(payload.transit_heat.get("current", 0.0)))
		player.heat.is_overheated = bool(payload.transit_heat.get("overheated", false))

func talk_to_codex() -> void:
	if departing or player.inventory.is_open or upgrade_panel.is_open or player.health.is_dead():
		return
	if dialogue_completed:
		upgrade_panel.open()
	else:
		panel.open()

func _on_dialogue_completed() -> void:
	dialogue_completed = true
	$Status.text = "整备已开放 / 装备升级 · 义体复合     准备好后向右前往第三层"
	upgrade_panel.call_deferred("open")

func owns_synthesis_item(item: InventoryItem) -> bool:
	return item != null and player.inventory.item_location(item) != ""

func synthesize(subject: InventoryItem, material: InventoryItem) -> bool:
	if not dialogue_completed or departing or _mutating or player.health.is_dead():
		return false
	if not owns_synthesis_item(subject) or not owns_synthesis_item(material) or not ComponentRolls.compatible(subject, material):
		var overlap_error := ComponentRolls.cyberware_overlap_error(subject, material)
		upgrade_panel.show_message(overlap_error if not overlap_error.is_empty() else "请选择两件兼容组件；复合义体最多四种不同模块")
		return false
	var inv: ComponentInventory = player.inventory
	var location := inv.item_location(subject)
	var index := inv.backpack.get_item_index(subject) if location == "backpack" else -1
	var result := ComponentRolls.fuse(subject, material, RandomNumberGenerator.new())
	if result == null:
		return false
	var before := player.export_run_state()
	_mutating = true
	subject.get_inventory().remove_item(subject)
	material.get_inventory().remove_item(material)
	var placed: bool = inv.backpack.add_item(result) if location == "backpack" else inv._slot_for(location).equip(result)
	if not placed:
		player.import_run_state(before)
		_mutating = false
		upgrade_panel.show_message("合成未完成，材料已恢复")
		return false
	if location == "backpack":
		inv.backpack.move_item(inv.backpack.get_item_index(result), mini(index, inv.backpack.get_item_count() - 1))
	inv._apply_equipment()
	inv.changed.emit()
	last_synthesis_result = result
	run.set_player_state(player.export_run_state())
	_mutating = false
	upgrade_panel.show_message("合成完成 · 已放回主体位置；可继续合成，或关闭后前往第三层")
	upgrade_panel.refresh()
	return true

func depart() -> bool:
	if departing or get_tree().paused or player.health.is_dead():
		return false
	if not dialogue_completed:
		$Status.text = "第三层线路尚未接通 / 请先靠近 Codex，按 E 与她对话"
		return false
	var flow := get_parent().get_parent().get_node_or_null("SceneFlow") as SceneContainerManager
	if flow == null:
		return false
	var snapshot := player.export_run_state()
	var payload := {"player_state": snapshot, "transit_heat": {"current": player.heat.current_heat, "overheated": player.heat.is_overheated}}
	if not flow.request_scene(FLOOR_PATH, payload):
		$Status.text = "第三层加载失败，请重试出口"
		return false
	departing = true
	player.set_input_enabled(false)
	run.set_player_state(snapshot)
	var previous_floor: int = run.floor_index
	run.floor_index = 2
	flow.load_failed.connect(func(_path: String, _error: String) -> void:
		departing = false
		run.floor_index = previous_floor
		player.set_input_enabled(true)
		$Status.text = "第三层加载失败，装备保留，请重试"
	, CONNECT_ONE_SHOT)
	return true

func _draw_floor(canvas: Node2D) -> void:
	canvas.draw_rect(Rect2(0, 0, 640, 360), Color("080e14"))
	for y in range(144, 288, 32):
		for x in range(44, 596, 32):
			canvas.draw_texture_rect(_art.asset("floor"), Rect2(x, y, mini(32, 596 - x), mini(32, 288 - y)), false, Color("b7c4c8"))

func _draw() -> void:
	# Architecture occludes the rear half of the complete doorway light ring.
	for bounds in [Rect2(0, 0, 640, 104), Rect2(0, 312, 640, 48), Rect2(0, 104, 24, 208), Rect2(618, 104, 22, 208)]:
		draw_rect(bounds, Color("080e14"))
	for x in range(44, 596, 128):
		draw_texture_rect(_art.asset("wall_north_v2"), Rect2(x, 104, mini(128, 596 - x), 44), false)
		draw_texture_rect(_art.asset("wall_south_v2"), Rect2(x, 288, mini(128, 596 - x), 24), false)
	draw_texture_rect(_art.asset("wall_west_v2"), Rect2(24, 108, 22, 202), false)
	draw_texture_rect(_art.asset("wall_east_v2"), Rect2(596, 108, 22, 202), false)
	for x in [88, 248, 408, 520]:
		draw_texture_rect(_art.asset("lamp"), Rect2(x, 116, 44, 10), false, Color("9be9ce"))
	draw_texture_rect(_art.asset("terminal"), Rect2(148, 119, 40, 42), false)
	draw_texture_rect(_art.asset("crates"), Rect2(418, 135, 68, 29), false)
	# Both floor numbers and the guide line share the doorway ring's centerline.
	var lane_y: float = $ContinueExit.position.y + $ContinueExit/DoorSigil.position.y
	var destination_x: float = $ContinueExit.position.x - 72.0
	var baseline := lane_y + (CyberUITheme.FONT.get_ascent(12) - CyberUITheme.FONT.get_descent(12)) * 0.5
	for x in range(136, int(destination_x) - 12, 32):
		draw_line(Vector2(x, lane_y), Vector2(x + 15, lane_y), Color("4f7366"), 2)
	draw_string(CyberUITheme.FONT, Vector2(72, baseline), "02 >", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("82bba2"))
	draw_string(CyberUITheme.FONT, Vector2(destination_x, baseline), "03 >", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("82bba2"))

func _exit_tree() -> void:
	_art.free()
