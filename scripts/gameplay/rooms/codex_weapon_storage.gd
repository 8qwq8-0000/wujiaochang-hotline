extends Node2D

var player: PlayerController
var upgrade_panel: CanvasLayer
var chest: Inventory
var panel: CanvasLayer
var _mutating := false
@onready var store: Node = get_node("/root/WarehouseStore")


func _ready() -> void:
	chest = Inventory.new()
	chest.protoset = ComponentInventory.PROTOTYPES
	add_child(chest)
	panel = preload("res://scripts/ui/warehouse_panel.gd").new()
	panel.room = self
	panel.heading_text = "Codex 通道 / 安全寄存箱"
	panel.open_message = "选择武器存入 · 立即保存 · 死亡后仍可在仓库取出"
	panel.deposit_only = true
	panel.weapons_only = true
	add_child(panel)


func open() -> void:
	if get_tree().paused or get_parent().departing or player.health.is_dead():
		return
	if not store.load_profile():
		get_parent().get_node("Status").text = store.error_message
		return
	_reload_chest()
	panel.open()


func _reload_chest() -> void:
	chest.clear()
	for entry: Dictionary in store.get_profile().chest:
		var item := InventoryItem.new()
		if item.deserialize(entry):
			chest.add_item(item)


func transfer(item: InventoryItem, deposit: bool) -> bool:
	if _mutating or not panel.is_open or get_parent().departing or player.health.is_dead():
		return false
	var inv := player.inventory
	if not deposit or item == null or item.get_property("slot", "") != "weapon" or inv.item_location(item).is_empty():
		panel.show_message("这里只能寄存随身武器；已寄存装备请回仓库取用。")
		return false
	if bool(item.get_property("bound", false)):
		panel.show_message("绑定武器不能寄存。")
		return false
	var profile: Dictionary = store.get_profile()
	var before := player.export_run_state()
	var heat_before := player.heat.current_heat
	var overheated_before := player.heat.is_overheated
	var chest_before := chest.serialize()
	var id := String(item.get_property("instance_id", ""))
	var safe_loadout: Dictionary = profile.loadout.duplicate(true)
	_remove_stored_weapon(safe_loadout, id)
	_mutating = true
	var moved := inv.move_to_storage(item, chest)
	if moved:
		var saved_items: Array = []
		for stored in chest.get_items():
			saved_items.append(stored.serialize())
		# Save only the chest and the existing safe loadout. Never persist the
		# rest of the current run's inventory, cyberware, health or persona.
		if not store.commit(saved_items, safe_loadout):
			player.import_run_state(before)
			player.heat.set_heat(heat_before)
			player.heat.is_overheated = overheated_before
			chest.deserialize(chest_before)
			moved = false
	if moved:
		get_node("/root/RunManager").set_player_state(player.export_run_state())
		panel.show_message("武器已安全寄存 · 死亡后仍保留 · 回仓库可取出")
	else:
		panel.show_message(store.error_message if not store.error_message.is_empty() else "寄存未完成，武器已保留。")
	_mutating = false
	panel.refresh()
	return moved


static func _remove_stored_weapon(loadout: Dictionary, id: String) -> void:
	if id.is_empty() or not loadout.get("inventory") is Dictionary:
		return
	var inv: Dictionary = loadout.inventory
	for slot in ["primary", "secondary", "blackbox"]:
		var entry: Dictionary = inv.get(slot, {})
		if _serialized_id(entry.get("item", {})) == id:
			inv[slot] = {}
	if inv.get("backpack") is Dictionary:
		var kept: Array = []
		for item: Dictionary in inv.backpack.get("items", []):
			if _serialized_id(item) != id:
				kept.append(item)
		inv.backpack["items"] = kept


static func _serialized_id(item: Dictionary) -> String:
	var encoded := str(item.get("properties", {}).get("instance_id", {}).get("value", ""))
	return str(str_to_var(encoded)) if encoded.begins_with("\"") else encoded
