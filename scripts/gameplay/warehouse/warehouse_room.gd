extends Node2D

const COMBAT_PATH := "res://scenes/levels/floors/combat_prototype.tscn"
const BOSS_TEST_PATH := "res://scenes/levels/bosses/rooftop_boss_arena.tscn"
const PANEL := preload("res://scripts/ui/warehouse_panel.gd")
var chest: Inventory
var panel: CanvasLayer
var upgrade_panel: CanvasLayer
var last_synthesis_result: InventoryItem
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
	upgrade_panel = CanvasLayer.new()
	upgrade_panel.set_script(preload("res://scripts/ui/synthesis_panel.gd"))
	upgrade_panel.room = self
	add_child(upgrade_panel)
	var profile: Dictionary = store.get_profile()
	_mutating = true
	for entry in profile.chest:
		var item := InventoryItem.new()
		if item.deserialize(entry):
			ComponentRolls.ensure(item)
			chest.add_item(item)
	player.import_run_state(profile.loadout)
	_ensure_fallback_weapon()
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
		panel.show_message("该物品无法存入箱子")
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
	var chest_before := chest.serialize()
	_ensure_fallback_weapon()
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
		chest.deserialize(chest_before)
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
	# Loading bay markings.
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


func enter_boss_test() -> bool:
	if _departing or get_tree().paused:
		return false
	var flow := get_parent().get_parent().get_node_or_null("SceneFlow") as SceneContainerManager
	if flow == null:
		$Instructions.text = "请从项目主入口运行，再进入 BOSS 测试"
		return false
	if not save_loadout():
		$Instructions.text = store.error_message
		return false
	var snapshot := player.export_run_state()
	var run := get_node_or_null("/root/RunManager")
	if run != null:
		run.begin_run()
	if not flow.request_scene(BOSS_TEST_PATH, {
		"player_state": snapshot,
		"boss_test": true,
	}):
		$Instructions.text = "BOSS 测试场景加载失败，请重试"
		return false
	_departing = true
	player.set_input_enabled(false)
	flow.load_failed.connect(func(_path: String, _error: String) -> void:
		_departing = false
		player.set_input_enabled(true)
		$Instructions.text = "BOSS 测试场景加载失败，请重试"
	, CONNECT_ONE_SHOT)
	return true


func owns_synthesis_item(item: InventoryItem) -> bool:
	return item != null and (chest.has_item(item) or player.inventory.item_location(item) != "")


func _synthesis_feedback(message: String) -> void:
	panel.show_message(message)
	upgrade_panel.show_message(message)


func synthesize(subject: InventoryItem, material: InventoryItem) -> bool:
	if _mutating or _departing or not owns_synthesis_item(subject) or not owns_synthesis_item(material) or not ComponentRolls.compatible(subject, material):
		_synthesis_feedback("请选择两件同槽位、同品质的组件")
		return false
	var result := ComponentRolls.fuse(subject, material, RandomNumberGenerator.new())
	var inv: ComponentInventory = player.inventory
	var location := "chest" if chest.has_item(subject) else inv.item_location(subject)
	var subject_index := inv.backpack.get_item_index(subject) if location == "backpack" else -1
	var next_chest := []
	for item in chest.get_items():
		if item != subject and item != material:
			next_chest.append(item.serialize())
	var next_state := player.export_run_state().duplicate(true)
	var state: Dictionary = next_state.inventory
	var ids := [subject.get_property("instance_id"), material.get_property("instance_id")]
	var bag := []
	for item in inv.backpack.get_items():
		if item != subject and item != material:
			bag.append(item.serialize())
	state.backpack["items"] = bag
	var slots := {"weapon": "primary", "weapon_secondary": "secondary", "mobility": "mobility", "defense": "defense", "blackbox": "blackbox"}
	for slot_key in slots.values():
		var entry: Dictionary = state[slot_key]
		if entry.has("item") and entry.item.get("properties", {}).get("instance_id", {}).get("value", "") in ids:
			state[slot_key] = {}
	if location == "chest":
		next_chest.append(result.serialize())
	elif location == "backpack":
		bag.insert(mini(subject_index, bag.size()), result.serialize())
	else:
		state[slots[location]] = {"item": result.serialize()}
	var active: int = int(state.active_weapon)
	if state["primary" if active == 0 else "secondary"].is_empty():
		state.active_weapon = 0 if not state.primary.is_empty() else (1 if not state.secondary.is_empty() else 0)
	# Commit the proposed ownership graph before consuming any live item.
	_mutating = true
	var saved: bool = store.commit(next_chest, next_state)
	if saved:
		subject.get_inventory().remove_item(subject)
		material.get_inventory().remove_item(material)
		if location == "chest":
			chest.add_item(result)
		elif location == "backpack":
			inv.backpack.add_item(result)
			inv.backpack.move_item(inv.backpack.get_item_index(result), mini(subject_index, inv.backpack.get_item_count() - 1))
		else:
			inv._slot_for(location).equip(result)
		inv._apply_equipment()
		inv.changed.emit()
		last_synthesis_result = result
	_mutating = false
	_synthesis_feedback("升级完成 · " + ComponentRolls.title(result) if saved else store.error_message)
	panel.refresh()
	upgrade_panel.refresh()
	return saved


func _ensure_fallback_weapon() -> void:
	# A save always offers an equipped weapon on entry/departure, preferring an
	# existing instance over minting another pistol. Blackbox choices stay protected.
	var inv: ComponentInventory = player.inventory
	if inv.weapon_slot.get_item() != null or inv.secondary_weapon_slot.get_item() != null:
		return
	for item in inv.backpack.get_items() + chest.get_items():
		if item.get_property("slot", "") == "weapon":
			inv.weapon_slot.equip(item)
			inv._apply_equipment()
			return
	var fallback := ComponentRolls.create_issued_pistol()
	inv.weapon_slot.equip(fallback)
	inv._apply_equipment()
