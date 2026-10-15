class_name ComponentInventory
extends Node

# Project-facing adapter: GLoot owns item storage; gameplay owns equipment rules.
signal changed
signal feedback(text: String, cue: StringName)
const CAPACITY := 6
const PROTOTYPES: JSON = preload("res://resources/items/components.json")
const PANEL_SCENE := preload("res://scenes/ui/inventory/inventory_panel.tscn")
var backpack: Inventory
# Equipped items live in independent GLoot slots, outside the six-cell bag.
var weapon_slot: ItemSlot
var secondary_weapon_slot: ItemSlot
var mobility_slot: ItemSlot
var blackbox_slot: ItemSlot
var panel: CanvasLayer
var is_open := false
var _owns_pause := false
static var _active_users := 0
var _serial := 0
var _has_picked_up_weapon := false
@onready var player: PlayerController = get_parent()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_active_users += 1
	# The player scene also supports F6 without Bootstrap.
	for action in {&"interact": KEY_E, &"inventory_toggle": KEY_TAB, &"pause": KEY_ESCAPE, &"weapon_switch": KEY_Q}:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			var key := InputEventKey.new()
			key.physical_keycode = {&"interact": KEY_E, &"inventory_toggle": KEY_TAB, &"pause": KEY_ESCAPE, &"weapon_switch": KEY_Q}[action]
			InputMap.action_add_event(action, key)
	backpack = Inventory.new()
	backpack.name = "Backpack"
	backpack.protoset = PROTOTYPES
	# GLoot caches prototype trees; restore it after the previous battle released it.
	if backpack.get_prototree().is_empty():
		backpack.get_prototree().deserialize(PROTOTYPES)
	var limit := ItemCountConstraint.new()
	limit.name = "Capacity"
	limit.capacity = CAPACITY
	backpack.add_child(limit)
	add_child(backpack)
	weapon_slot = _create_slot("WeaponSlot")
	secondary_weapon_slot = _create_slot("SecondaryWeaponSlot")
	mobility_slot = _create_slot("MobilitySlot")
	blackbox_slot = _create_slot("BlackboxSlot")
	panel = PANEL_SCENE.instantiate()
	panel.inventory = self
	add_child(panel)
	var initial := InventoryItem.new(PROTOTYPES, "initial_baton")
	_assign_instance_id(initial)
	weapon_slot.equip(initial)
	var insurance := InventoryItem.new(PROTOTYPES, "circuit_breaker")
	_assign_instance_id(insurance)
	blackbox_slot.equip(insurance)
	player.get_node("CircuitBreakerComponent").circuit_breaker_triggered.connect(_on_insurance_triggered)
	_apply_equipment()
	backpack.item_removed.connect(_on_backpack_item_removed)
	changed.emit()
	player.get_node("HealthComponent").died.connect(_on_player_died)

func _create_slot(slot_name: String) -> ItemSlot:
	var slot := ItemSlot.new()
	slot.name = slot_name
	slot.protoset = PROTOTYPES
	add_child(slot)
	return slot

func _input(event: InputEvent) -> void:
	if event.is_echo() or (get_tree().paused and not is_open):
		return
	if event.is_action_pressed("inventory_toggle"):
		set_open(not is_open)
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("pause"):
		set_open(false)
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("restart_room"):
		# Resume first, then let Bootstrap (or the standalone room) handle R.
		set_open(false)
	elif event.is_action_pressed("interact") and not is_open and player.is_input_enabled():
		if player.interactor.get_best_target(player) == null:
			try_pick_nearest()
			get_viewport().set_input_as_handled()

func set_open(value: bool) -> void:
	value = value and not player.health.is_dead()
	if value == is_open:
		return
	is_open = value
	if is_open:
		_owns_pause = not get_tree().paused
		get_tree().paused = true
	else:
		_release_pause()
	panel.set_open(is_open)

func _release_pause() -> void:
	if _owns_pause:
		get_tree().paused = false
		_owns_pause = false

func _on_player_died(_packet: DamagePacket) -> void:
	set_open(false)

func can_change_equipment() -> bool:
	if player.health.is_dead():
		return false
	var run := get_node_or_null("/root/RunManager")
	if run != null and run.mandatory_enemies_remaining > 0:
		return false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is EnemyController and enemy.state != EnemyController.State.DEAD:
			return false
	return true

func _assign_instance_id(item: InventoryItem) -> void:
	_serial += 1
	item.set_property("instance_id", "%d-%d-%d" % [get_instance_id(), Time.get_ticks_usec(), _serial])

func pickup(component_id: String) -> bool:
	if player.health.is_dead() or not PROTOTYPES.data.has(component_id):
		return false
	if component_id == "circuit_breaker" and get_insurance_item() != null:
		return false
	if component_id == "circuit_breaker":
		var store := get_node_or_null("/root/WarehouseStore")
		if store != null:
			for stored_item in store.get_profile().chest:
				if stored_item.get("prototype_id") == "circuit_breaker":
					return false
	var is_weapon := str(PROTOTYPES.data[component_id].get("slot", "")) == "weapon"
	var auto_secondary := is_weapon and not _has_picked_up_weapon and secondary_weapon_slot.get_item() == null
	var item := InventoryItem.new(PROTOTYPES, component_id)
	# The first weapon can go straight into a free reserve even if the bag is full.
	var stored := secondary_weapon_slot.equip(item) if auto_secondary else backpack.add_item(item)
	if not stored:
		_notify("背包已满（6/6），组件留在地上", &"full")
		return false
	_assign_instance_id(item)
	if is_weapon:
		_has_picked_up_weapon = true
	if auto_secondary:
		_apply_equipment()
	changed.emit()
	if auto_secondary:
		_notify("首次武器已装入副槽：%s · Q/滚轮切换" % item.get_title(), &"pickup")
	else:
		_notify("已拾取：%s" % item.get_title(), &"pickup")
	return true

func try_pick_nearest() -> bool:
	var nearest: ComponentPickup
	var distance := 45.0
	for node in get_tree().get_nodes_in_group("component_pickups"):
		var pickup_node := node as ComponentPickup
		if pickup_node == null or not pickup_node.can_reach(player):
			continue
		var candidate := player.global_position.distance_to(pickup_node.global_position)
		if candidate < distance:
			distance = candidate
			nearest = pickup_node
	if nearest == null:
		_notify("靠近组件后按 E 拾取", &"full")
		return false
	return nearest.try_pickup(self)

func equip(index: int, weapon_position: int = 0) -> bool:
	if not can_change_equipment():
		_notify("战斗中不能换装，请先清场", &"full")
		return false
	var items := backpack.get_items()
	if index < 0 or index >= items.size():
		return false
	var item := items[index]
	var slot_name := str(item.get_property("slot", ""))
	if slot_name == "weapon" and weapon_position not in [0, 1]:
		return false
	var slot := _slot_for("weapon_secondary" if slot_name == "weapon" and weapon_position == 1 else slot_name)
	if slot == null:
		return false
	var old: InventoryItem = slot.get_item()
	# Exchange preserves both instances, including when the bag is full.
	var success: bool = InventoryItem.swap(item, old) if old != null else slot.equip(item)
	if not success:
		return false
	_apply_equipment()
	if slot_name == "weapon":
		player.weapons.select_weapon(weapon_position)
	changed.emit()
	_notify("已装备：%s" % item.get_title(), &"equip")
	return true

func unequip(slot_name: String) -> bool:
	if not can_change_equipment():
		_notify("战斗中不能换装，请先清场", &"full")
		return false
	var slot := _slot_for(slot_name)
	if slot == null or slot.get_item() == null:
		return false
	var item: InventoryItem = slot.get_item()
	if not backpack.add_item(item):
		_notify("背包已满，无法卸下", &"full")
		return false
	_apply_equipment()
	changed.emit()
	_notify("已卸下：%s" % item.get_title(), &"equip")
	return true

func _slot_for(slot_name: String) -> Object:
	match slot_name:
		"weapon":
			return weapon_slot
		"weapon_secondary":
			return secondary_weapon_slot
		"mobility":
			return mobility_slot
		"blackbox":
			return blackbox_slot
	return null


func _on_backpack_item_removed(_item: InventoryItem) -> void:
	changed.emit()

func _apply_equipment() -> void:
	var weapon := weapon_slot.get_item()
	var secondary := secondary_weapon_slot.get_item()
	player.get_node("WeaponController").set_carried_weapons(
		load(str(weapon.get_property("effect"))) if weapon != null else null,
		load(str(secondary.get_property("effect"))) if secondary != null else null)
	var mode := mobility_slot.get_item()
	player.get_node("MobilityController").set_equipped_mode(load(str(mode.get_property("effect"))) if mode != null else null)
	sync_insurance()


func get_insurance_item() -> InventoryItem:
	var protected := blackbox_slot.get_item()
	if protected != null and protected.get_property("slot", "") == "insurance":
		return protected
	for item in backpack.get_items():
		if item.get_property("slot", "") == "insurance":
			return item
	return null


func sync_insurance() -> void:
	var breaker: CircuitBreakerComponent = player.get_node("CircuitBreakerComponent")
	var item := blackbox_slot.get_item()
	var insured: bool = item != null and item.get_property("slot", "") == "insurance"
	breaker.circuit_breaker_used = bool(item.get_property("circuit_breaker_used", false)) if insured else false
	breaker.set_equipped(insured)


func _on_insurance_triggered() -> void:
	var item := get_insurance_item()
	if item != null:
		item.set_property("circuit_breaker_used", true)
	_persist_protection()
	changed.emit()


func can_change_blackbox() -> bool:
	return not player.health.is_dead() and not player.health.resolving_damage and (can_change_equipment() or (is_open and get_tree().paused))


func put_in_blackbox(index: int) -> bool:
	var items := backpack.get_items()
	if not can_change_blackbox() or index < 0 or index >= items.size():
		return false
	var item := items[index]
	if bool(item.get_property("bound", false)):
		_notify("绑定初始装备无需黑匣保护", &"full")
		return false
	var old := blackbox_slot.get_item()
	var before := player.export_run_state()
	var moved := InventoryItem.swap(item, old) if old != null else blackbox_slot.equip(item)
	if not moved:
		return false
	sync_insurance()
	if not _persist_protection():
		player.import_run_state(before)
		return false
	changed.emit()
	_notify("黑匣保护：%s" % item.get_title(), &"equip")
	return true


func take_from_blackbox() -> bool:
	if not can_change_blackbox() or blackbox_slot.get_item() == null:
		return false
	var before := player.export_run_state()
	if not backpack.add_item(blackbox_slot.get_item()):
		_notify("背包已满，无法取出；可选一件背包物品与黑匣交换", &"full")
		return false
	sync_insurance()
	if not _persist_protection():
		player.import_run_state(before)
		return false
	changed.emit()
	return true


func _persist_protection() -> bool:
	var run := get_node_or_null("/root/RunManager")
	var warehouse := not get_tree().get_nodes_in_group("warehouse").is_empty()
	if run == null or (not run.persistent_run and not warehouse):
		return true
	var store := get_node("/root/WarehouseStore")
	var profile: Dictionary = store.get_profile()
	var saved: bool = store.commit(profile.chest, player.export_run_state() if warehouse else player.export_recovery_state())
	if not saved:
		_notify(store.error_message, &"full")
	return saved


func prepare_for_departure() -> void:
	var insurance := get_insurance_item()
	if insurance != null:
		insurance.set_property("circuit_breaker_used", false)
		if backpack.has_item(insurance):
			var old := blackbox_slot.get_item()
			if old == null:
				blackbox_slot.equip(insurance)
			else:
				InventoryItem.swap(insurance, old)
	sync_insurance()


func move_to_storage(item: InventoryItem, storage: Inventory) -> bool:
	if item == null or bool(item.get_property("bound", false)):
		return false
	var owned := backpack.has_item(item)
	for slot in [weapon_slot, secondary_weapon_slot, mobility_slot, blackbox_slot]:
		owned = owned or slot.get_item() == item
	if not owned or not storage.add_item(item):
		return false
	_apply_equipment()
	changed.emit()
	return true


func take_from_storage(item: InventoryItem, storage: Inventory) -> bool:
	if item != null and item.get_property("slot", "") == "insurance" and get_insurance_item() != null:
		return false
	if item == null or not storage.has_item(item) or not backpack.add_item(item):
		return false
	changed.emit()
	return true

func _notify(text: String, cue: StringName) -> void:
	feedback.emit(text, cue)
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_message(text)


func _exit_tree() -> void:
	_release_pause()
	_active_users -= 1
	if _active_users == 0 and is_instance_valid(backpack):
		# Break GLoot's prototype parent/child references when this catalog is unused.
		backpack.get_prototree().clear()


func export_run_state() -> Dictionary:
	return {
		"backpack": backpack.serialize(),
		"primary": weapon_slot.serialize(),
		"secondary": secondary_weapon_slot.serialize(),
		"mobility": mobility_slot.serialize(),
		"blackbox": blackbox_slot.serialize(),
		"active_weapon": player.weapons.current_index,
		"has_picked_up_weapon": _has_picked_up_weapon,
	}


func get_extraction_items() -> Array[Dictionary]:
	# Copy each instance, including properties/quality added by future item systems.
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	var locations := {"主武器": weapon_slot, "副武器": secondary_weapon_slot, "机动装备": mobility_slot, "黑匣": blackbox_slot}
	for location in locations:
		var item: InventoryItem = locations[location].get_item()
		if item != null:
			_append_extraction_item(result, seen, item, location)
	for item in backpack.get_items():
		_append_extraction_item(result, seen, item, "背包")
	return result


func _append_extraction_item(result: Array[Dictionary], seen: Dictionary, item: InventoryItem, location: String) -> void:
	var id := str(item.get_property("instance_id", str(item.get_instance_id())))
	if seen.has(id):
		return
	seen[id] = true
	result.append({"name": item.get_title(), "location": location, "item": item.serialize().duplicate(true)})


func import_run_state(state: Dictionary) -> void:
	# RunManager passes an in-memory snapshot from export_run_state, not a save file.
	backpack.deserialize(state["backpack"])
	weapon_slot.deserialize(state["primary"])
	secondary_weapon_slot.deserialize(state["secondary"])
	mobility_slot.deserialize(state["mobility"])
	if state.has("blackbox"):
		blackbox_slot.deserialize(state["blackbox"])
	_has_picked_up_weapon = bool(state.get("has_picked_up_weapon", false))
	player.weapons.current_index = clampi(int(state.get("active_weapon", 0)), 0, 1)
	_apply_equipment()
	changed.emit()


func export_recovery_inventory() -> Dictionary:
	var snapshot := export_run_state()
	var bound: InventoryItem
	for entry in get_extraction_items():
		if entry.item.get("prototype_id") == "initial_baton":
			bound = InventoryItem.new()
			bound.deserialize(entry.item)
			break
	if bound == null:
		bound = InventoryItem.new(PROTOTYPES, "initial_baton")
		_assign_instance_id(bound)
	snapshot.backpack.erase("items")
	snapshot.primary = {"item": bound.serialize()}
	snapshot.secondary = {}
	snapshot.mobility = {}
	snapshot.active_weapon = 0
	snapshot.has_picked_up_weapon = false
	return snapshot
