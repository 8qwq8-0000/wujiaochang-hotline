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
var defense_slot: ItemSlot
var blackbox_slot: ItemSlot
var panel: CanvasLayer
var allow_trial_equipment_changes := false
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
	defense_slot = _create_slot("DefenseSlot")
	blackbox_slot = _create_slot("BlackboxSlot")
	panel = PANEL_SCENE.instantiate()
	panel.inventory = self
	add_child(panel)
	var initial := ComponentRolls.create("baton", 1, RandomNumberGenerator.new())
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
	if allow_trial_equipment_changes:
		return true
	var area := EnvironmentArea.for_actor(player)
	if area is CombatRoom and area.sequence_managed:
		return area.cleared
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

func pickup(component_id: String, rolled_item: InventoryItem = null) -> bool:
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
	var item := rolled_item if rolled_item != null else InventoryItem.new(PROTOTYPES, component_id)
	if item.get_inventory() != null or item_location(item) != "":
		return false
	if item.get_prototype().get_prototype_id() != component_id:
		return false
	ComponentRolls.ensure(item)
	# The first weapon can go straight into a free reserve even if the bag is full.
	var stored := secondary_weapon_slot.equip(item) if auto_secondary else backpack.add_item(item)
	if not stored:
		_notify("背包已满（6/6），组件留在地上", &"full")
		return false
	if not item.has_property("instance_id"):
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
		"defense":
			return defense_slot
		"blackbox":
			return blackbox_slot
	return null


func item_at(location: String, index: int = -1) -> InventoryItem:
	if location == "backpack":
		var items := backpack.get_items()
		return items[index] if index >= 0 and index < items.size() else null
	var slot := _slot_for(location)
	return slot.get_item() if slot != null else null


func item_location(item: InventoryItem) -> String:
	if item == null:
		return ""
	if backpack.has_item(item):
		return "backpack"
	for location in ["weapon", "weapon_secondary", "mobility", "defense", "blackbox"]:
		if item_at(location) == item:
			return location
	return ""


func _fits_location(item: InventoryItem, location: String) -> bool:
	if item == null or location == "backpack":
		return true
	if location == "blackbox":
		return not bool(item.get_property("bound", false))
	var kind := str(item.get_property("slot", ""))
	return kind == ("weapon" if location in ["weapon", "weapon_secondary"] else location)


func can_drop_item(item: InventoryItem, destination: String, index: int = -1) -> bool:
	if not is_open or player.health.is_dead() or player.health.resolving_damage:
		return false
	var source := item_location(item)
	if source.is_empty() or (destination != "backpack" and _slot_for(destination) == null):
		return false
	if destination == "backpack" and (index < 0 or index >= CAPACITY):
		return false
	var other := item_at(destination, index)
	if other == item or (source == destination and source != "backpack"):
		return false
	if source in ["weapon", "weapon_secondary", "mobility", "defense"] or destination in ["weapon", "weapon_secondary", "mobility", "defense"]:
		if not can_change_equipment():
			return false
	elif "blackbox" in [source, destination] and not can_change_blackbox():
		return false
	if destination == "backpack" and source != "backpack" and other == null and backpack.get_item_count() >= CAPACITY:
		return false
	return _fits_location(item, destination) and _fits_location(other, source)


func drop_item(item: InventoryItem, destination: String, index: int = -1) -> bool:
	if not can_drop_item(item, destination, index):
		return false
	var source := item_location(item)
	var source_index := backpack.get_item_index(item) if source == "backpack" else -1
	var active_weapon := player.weapons.current_index
	var ability_cooldown := player.mobility.ability_cooldown_remaining
	var ability_active: float = player.mobility.get("_ability_active_remaining")
	var ram_direction: Vector2 = player.mobility.get("_ram_direction")
	var ram_hits: Dictionary = player.mobility.get("_ram_hits").duplicate()
	var other := item_at(destination, index)
	var moved := false
	if source == "backpack" and destination == "backpack" and other != null:
		var original_index := backpack.get_item_index(item)
		backpack.move_item(original_index, backpack.get_item_index(other))
		backpack.move_item(backpack.get_item_index(other), original_index)
		moved = true
	elif other != null:
		moved = InventoryItem.swap(item, other)
	elif destination == "backpack":
		if source == "backpack":
			backpack.move_item(backpack.get_item_index(item), backpack.get_item_count() - 1)
			moved = true
		else:
			moved = backpack.add_item(item)
	else:
		moved = _slot_for(destination).equip(item)
	if not moved:
		return false
	# Reordering bag items never changes weapon heat, cooldown or active weapon.
	if source in ["weapon", "weapon_secondary", "mobility", "defense"] or destination in ["weapon", "weapon_secondary", "mobility", "defense"]:
		_apply_equipment()
	elif "blackbox" in [source, destination]:
		sync_insurance()
	if destination in ["weapon", "weapon_secondary"]:
		player.weapons.select_weapon(1 if destination == "weapon_secondary" else 0)
	if "blackbox" in [source, destination] and not _persist_protection():
		# Undo with the same instances, preserving both ordering and live combat state.
		if other != null:
			InventoryItem.swap(item, other)
		elif source == "backpack":
			backpack.add_item(item)
			backpack.move_item(backpack.get_item_index(item), source_index)
		else:
			_slot_for(source).equip(item)
		player.weapons.current_index = active_weapon
		_apply_equipment()
		player.mobility.ability_cooldown_remaining = ability_cooldown
		player.mobility.set("_ability_active_remaining", ability_active)
		player.mobility.set("_ram_direction", ram_direction)
		player.mobility.set("_ram_hits", ram_hits)
		changed.emit()
		return false
	changed.emit()
	_notify("已移动：%s" % item.get_title(), &"equip")
	return true

func _on_backpack_item_removed(_item: InventoryItem) -> void:
	changed.emit()

func _apply_equipment() -> void:
	var weapon := weapon_slot.get_item()
	var secondary := secondary_weapon_slot.get_item()
	player.get_node("WeaponController").set_carried_weapons(
		ComponentRolls.weapon(weapon), ComponentRolls.weapon(secondary))
	var mode := mobility_slot.get_item()
	var mode_data: MobilityMode = (load(str(mode.get_property("effect"))) if mode != null else MobilityController.WALK_MODE).duplicate(true)
	var equipped := [weapon, secondary, mode, defense_slot.get_item()]
	if mode_data != null:
		mode_data.max_speed *= 1.0 + ComponentRolls.bonus(equipped, "mobility") / 100.0
	player.get_node("MobilityController").set_equipped_mode(mode_data)
	player.get_node("HeatComponent").equipment_capacity_bonus = ComponentRolls.bonus(equipped, "capacity") / 100.0
	player.get_node("HeatComponent").equipment_cooling_bonus = ComponentRolls.bonus(equipped, "cooling") / 100.0
	player.get_node("GuardComponent").equipment_window_bonus = ComponentRolls.bonus(equipped, "guard") / 1000.0
	player.get_node("StatusComponent").equipment_negative_duration_reduction = ComponentRolls.bonus(equipped, "status") / 100.0
	var heat: HeatComponent = player.get_node("HeatComponent")
	heat.set_heat(heat.current_heat)
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
		_notify("绑定物品不能放入黑匣", &"full")
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
	for slot in [weapon_slot, secondary_weapon_slot, mobility_slot, defense_slot, blackbox_slot]:
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
		var priority := CombatNotice.Priority.LOW if cue == &"pickup" else CombatNotice.Priority.NORMAL
		var merge_window := 0.75 if cue in [&"pickup", &"full"] else 0.0
		events.publish_notice(cue, text, Color.WHITE, priority, merge_window)


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
		"defense": defense_slot.serialize(),
		"blackbox": blackbox_slot.serialize(),
		"active_weapon": player.weapons.current_index,
		"has_picked_up_weapon": _has_picked_up_weapon,
	}


func get_extraction_items() -> Array[Dictionary]:
	# Copy each instance, including properties/quality added by future item systems.
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	var locations := {"主武器": weapon_slot, "副武器": secondary_weapon_slot, "机动装备": mobility_slot, "防御装备": defense_slot, "黑匣": blackbox_slot}
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
	state = ComponentRolls.migrate_snapshot(state)
	# RunManager may still hold snapshots from an older build.
	backpack.deserialize(state["backpack"])
	weapon_slot.deserialize(state["primary"])
	secondary_weapon_slot.deserialize(state["secondary"])
	mobility_slot.deserialize(state["mobility"])
	defense_slot.deserialize(state.get("defense", {}))
	if state.has("blackbox"):
		blackbox_slot.deserialize(state["blackbox"])
	_has_picked_up_weapon = bool(state.get("has_picked_up_weapon", false))
	player.weapons.current_index = clampi(int(state.get("active_weapon", 0)), 0, 1)
	for item in backpack.get_items() + [weapon_slot.get_item(), secondary_weapon_slot.get_item(), mobility_slot.get_item(), defense_slot.get_item(), blackbox_slot.get_item()]:
		if item != null:
			ComponentRolls.ensure(item)
	_apply_equipment()
	changed.emit()


func export_recovery_inventory() -> Dictionary:
	var snapshot := export_run_state()
	snapshot.backpack.erase("items")
	snapshot.primary = {}
	snapshot.secondary = {}
	snapshot.mobility = {}
	snapshot.defense = {}
	snapshot.active_weapon = 0
	snapshot.has_picked_up_weapon = false
	return snapshot
