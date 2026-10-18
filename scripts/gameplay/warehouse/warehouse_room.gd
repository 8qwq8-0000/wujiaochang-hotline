extends Node2D

const COMBAT_PATH := "res://scenes/levels/floors/combat_prototype.tscn"
const PANEL := preload("res://scripts/ui/warehouse_panel.gd")
var chest: Inventory
var panel: CanvasLayer
var _mutating := false
var _departing := false
var _save_queued := false
@onready var player: PlayerController = $Player
@onready var store: Node = get_node("/root/WarehouseStore")


func _ready() -> void:
	add_to_group("warehouse")
	chest = Inventory.new()
	chest.name = "WarehouseItems"
	chest.protoset = ComponentInventory.PROTOTYPES
	add_child(chest)
	panel = CanvasLayer.new()
	panel.set_script(PANEL)
	panel.room = self
	add_child(panel)
	var profile: Dictionary = store.get_profile()
	_mutating = true
	for entry in profile.chest:
		var item := InventoryItem.new()
		if item.deserialize(entry):
			ComponentRolls.ensure(item)
			chest.add_item(item)
	player.import_run_state(profile.loadout)
	player.health.set_current_health(player.config.max_health)
	player.inventory.changed.connect(_queue_save)
	_mutating = false
	get_node("/root/RunManager").set_mandatory_enemy_count(0)
	var camera := player.get_node("Camera2D") as Camera2D
	camera.enabled = false
	# World origin matches the project's 640×360 internal canvas.
	var fixed_camera := Camera2D.new()
	fixed_camera.position = Vector2(320, 180)
	add_child(fixed_camera)
	fixed_camera.make_current()
	if not store.error_message.is_empty():
		$Instructions.text = store.error_message
	elif not save_loadout():
		$Instructions.text = store.error_message
	queue_redraw()


func _queue_save() -> void:
	if _mutating or _departing or _save_queued:
		return
	_save_queued = true
	call_deferred("_save_changed_loadout")


func _save_changed_loadout() -> void:
	_save_queued = false
	if _mutating or _departing:
		return
	if not save_loadout():
		$Instructions.text = store.error_message


func chest_data() -> Array:
	var result := []
	for item in chest.get_items():
		result.append(item.serialize())
	return result


func save_loadout() -> bool:
	return store.commit(chest_data(), player.export_run_state())


func transfer(item: InventoryItem, deposit: bool) -> bool:
	if _departing or item == null:
		return false
	var before := player.export_run_state()
	var chest_before := chest.serialize()
	_mutating = true
	var moved := player.inventory.move_to_storage(item, chest) if deposit else player.inventory.take_from_storage(item, chest)
	if moved and not save_loadout():
		player.import_run_state(before)
		chest.deserialize(chest_before)
		moved = false
	_mutating = false
	if moved:
		panel.show_message("已存入箱子 · 已保存" if deposit else "已取出到背包 · 已保存")
	elif not store.error_message.is_empty():
		panel.show_message(store.error_message)
	elif deposit:
		panel.show_message("绑定初始装备不能存入箱子")
	else:
		panel.show_message("背包已满，请先存入装备或关闭箱子后换装")
	panel.refresh()
	return moved


func depart() -> bool:
	if _departing or get_tree().paused:
		return false
	var flow := get_parent().get_parent().get_node_or_null("SceneFlow") as SceneContainerManager
	if flow == null:
		$Instructions.text = "请从项目主入口运行，再从此处出击"
		return false
	var before := player.export_run_state()
	player.inventory.prepare_for_departure()
	var snapshot := player.export_run_state()
	# New actions refresh per-run resources; moving items inside the warehouse does not.
	snapshot.circuit_breaker.circuit_breaker_used = false
	snapshot.talent_core.takeover_armed = false
	snapshot.talent_core.takeover_charges = player.talent_core.takeover_charge_max
	snapshot.inventory.has_picked_up_weapon = false
	# The deployed items now belong only to this run, never a second safe copy.
	if not store.commit(chest_data(), player.export_recovery_state()):
		player.import_run_state(before)
		$Instructions.text = store.error_message
		return false
	if not flow.request_scene(COMBAT_PATH, {"player_state": snapshot}):
		store.commit(chest_data(), snapshot)
		$Instructions.text = "出击加载失败，装备仍在仓库"
		return false
	_departing = true
	flow.load_failed.connect(func(_path: String, _error: String) -> void:
		_departing = false
		if not save_loadout():
			$Instructions.text = store.error_message
		else:
			$Instructions.text = "出击加载失败，装备已恢复，请重试"
	, CONNECT_ONE_SHOT)
	var run: Node = get_node("/root/RunManager")
	run.begin_run()
	run.persistent_run = true
	run.set_player_state(snapshot)
	return true


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color("0d151e"))
	draw_rect(Rect2(24, 62, 592, 266), Color("172634"))
	for x in range(24, 617, 24):
		draw_line(Vector2(x, 62), Vector2(x, 328), Color("203342"))
	for y in range(64, 329, 24):
		draw_line(Vector2(24, y), Vector2(616, y), Color("203342"))
	draw_rect(Rect2(24, 62, 592, 266), Color("476271"), false, 3)
	# Left wall shelving and loading bay markings.
	for y in [105, 155, 205]:
		draw_rect(Rect2(42, y, 62, 32), Color("293e4b"))
		draw_line(Vector2(42, y + 28), Vector2(104, y + 28), Color("71848b"), 2)
	draw_rect(Rect2(490, 134, 100, 120), Color("253c42"))
	draw_rect(Rect2(490, 134, 100, 120), Color("c2b275"), false, 2)

func enter_trial() -> bool:
	if _departing or get_tree().paused:
		return false
	if not save_loadout():
		$Instructions.text = store.error_message
		return false
	_departing = true
	player.set_input_enabled(false)
	call_deferred("_open_trial")
	return true

func _open_trial() -> void:
	var error := get_tree().change_scene_to_file("res://scenes/debug/fuel_reaction_sandbox.tscn")
	if error != OK:
		_departing = false
		player.set_input_enabled(true)
		$Instructions.text = "试验场加载失败，请重试"
		return


func synthesize(subject: InventoryItem, material: InventoryItem) -> bool:
	if _mutating or _departing or not chest.has_item(subject) or not chest.has_item(material) or not ComponentRolls.compatible(subject, material):
		panel.show_message("需要两件同槽位、同品质的普通仓库组件")
		return false
	var result := ComponentRolls.fuse(subject, material, RandomNumberGenerator.new())
	var next := []
	for item in chest.get_items():
		if item != subject and item != material:
			next.append(item.serialize())
	next.append(result.serialize())
	# Persist the entire proposed transaction before touching either live material.
	_mutating = true
	var saved: bool = store.commit(next, player.export_run_state())
	if saved:
		chest.remove_item(subject)
		chest.remove_item(material)
		chest.add_item(result)
	_mutating = false
	panel.show_message("合成完成 · " + ComponentRolls.describe(result) if saved else store.error_message)
	panel.refresh()
	return saved
