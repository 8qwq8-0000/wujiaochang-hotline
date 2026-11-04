extends Node2D

const GLASS_BACKDROP := preload("res://scripts/presentation/combat_glass_backdrop.gd")


func _enter_tree() -> void:
	var run := get_node("/root/RunManager")
	if run.floor_index != 2:
		return
	$FloorAssembler.room_count = 1
	$FloorAssembler.codex_ambush = run.channel_route_active and run.codex_is_alive() and not bool(run.codex_companion.get("ambush_failed", false))
	# Merge former two-area checkpoints into the single third-floor area.
	if not run.channel_resume.is_empty():
		var saved: Array = run.channel_resume.get("cleared", [])
		if saved.size() > 1:
			run.channel_resume.cleared = [saved.all(func(value: bool) -> bool: return value)]
		if $FloorAssembler.codex_ambush:
			run.channel_resume.cleared = [bool(run.codex_companion.get("ambush_complete", false))]
		run.channel_resume.x = clampf(float(run.channel_resume.get("x", 111)), 60, 900)


func _ready() -> void:
	var run_manager := get_node_or_null("/root/RunManager")
	if run_manager != null and run_manager.run_seed == 0:
		run_manager.begin_run()
	var player := get_node_or_null("Player") as PlayerController
	if run_manager != null and is_instance_valid(player):
		player.import_run_state(run_manager.get_player_state())
	y_sort_enabled = true
	var backdrop := Node2D.new()
	backdrop.name = "CombatBackdrop"
	backdrop.z_index = -10
	add_child(backdrop)
	backdrop.draw.connect(_draw_background.bind(backdrop))
	backdrop.queue_redraw()
	var assembler := get_node_or_null("FloorAssembler") as FloorAssembler
	var glass_backdrop := GLASS_BACKDROP.new() as CombatGlassBackdrop
	glass_backdrop.name = "GlassCurtainBackdrop"
	var seed_value: int = run_manager.run_seed if run_manager != null else 1
	var room_count: int = assembler.room_count if assembler != null else 1
	var spacing: float = assembler.room_spacing.x if assembler != null else CombatRoom.ROOM_SIZE.x
	glass_backdrop.configure(room_count, spacing, CombatRoom.ROOM_SIZE.x, seed_value)
	add_child(glass_backdrop)
	var store := get_node_or_null("/root/WarehouseStore")
	if run_manager != null and run_manager.persistent_run and store != null and store.is_channel_route_unlocked() and run_manager.floor_index < 3 and (run_manager.floor_index == 0 or run_manager.channel_route_active):
		var mission: ChannelMission = preload("res://scripts/gameplay/channel/channel_hidden_mission.gd").new() if run_manager.floor_index == 0 else preload("res://scripts/gameplay/channel/channel_mission.gd").new()
		mission.name = "ChannelMission"
		add_child(mission)
	call_deferred("_spawn_codex")


func receive_scene_payload(payload: Dictionary) -> void:
	var player := get_node_or_null("Player") as PlayerController
	if not is_instance_valid(player):
		return
	if payload.has("player_state") and payload["player_state"] is Dictionary:
		player.import_run_state(payload["player_state"])
	if payload.has("transit_heat"):
		player.heat.set_heat(float(payload.transit_heat.get("current", 0.0)))
		player.heat.is_overheated = bool(payload.transit_heat.get("overheated", false))


func _draw_background(canvas: Node2D) -> void:
	var assembler := get_node_or_null("FloorAssembler") as FloorAssembler
	var count := assembler.room_count if assembler != null else 1
	var spacing := assembler.room_spacing.x if assembler != null else CombatRoom.ROOM_SIZE.x
	var floor_size := Vector2(CombatRoom.ROOM_SIZE.x + spacing * maxi(count - 1, 0), CombatRoom.ROOM_SIZE.y)
	canvas.draw_rect(Rect2(Vector2.ZERO, floor_size), Color("101722"), true)
	for x in range(0, int(floor_size.x) + 1, 32):
		canvas.draw_line(Vector2(x, 0), Vector2(x, floor_size.y), Color(0.14, 0.2, 0.28, 0.35), 1.0)
	for y in range(0, int(floor_size.y) + 1, 32):
		canvas.draw_line(Vector2(0, y), Vector2(floor_size.x, y), Color(0.14, 0.2, 0.28, 0.35), 1.0)


func _spawn_codex() -> void:
	var run := get_node("/root/RunManager")
	if run.floor_index == 2 and run.channel_route_active and run.codex_is_alive():
		var player: PlayerController = $Player
		var companion := CodexCompanion.spawn(self, player, Vector2(111, 310))
		if not bool(run.codex_companion.get("ambush_complete", false)) and not bool(run.codex_companion.get("ambush_failed", false)):
			var ambush := preload("res://scripts/gameplay/channel/codex_ambush.gd").new()
			ambush.name = "CodexAmbush"
			ambush.companion = companion
			add_child(ambush)
		else:
			companion.escort_complete = true
