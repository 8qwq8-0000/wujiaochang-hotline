class_name ComponentInventory
extends Node

# Project-facing adapter: GLoot owns item storage; gameplay owns equipment rules.
signal changed
signal feedback(text: String, cue: StringName)
const CAPACITY := 6
const PROTOTYPES: JSON = preload("res://resources/items/components.json")
const PANEL_SCENE := preload("res://scenes/ui/inventory/inventory_panel.tscn")
var backpack: Inventory
# Weapon slots select items in the backpack; they never own separate storage.
class WeaponSlotRef extends RefCounted:
	var item: InventoryItem
	func get_item() -> InventoryItem:
		return item
	func equip(value: InventoryItem) -> bool:
		item = value
		return value != null
	func clear() -> bool:
		var existed := item != null
		item = null
		return existed

var weapon_slot: WeaponSlotRef
var secondary_weapon_slot: WeaponSlotRef
var mobility_slot: ItemSlot
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
	limit.capacity = CAPACITY
	backpack.add_child(limit)
	add_child(backpack)
	weapon_slot = WeaponSlotRef.new()
	secondary_weapon_slot = WeaponSlotRef.new()
	mobility_slot = _create_slot("MobilitySlot")
	panel = PANEL_SCENE.instantiate()
	panel.inventory = self
	add_child(panel)
	var initial := backpack.create_and_add_item("initial_baton")
	_assign_instance_id(initial)
	weapon_slot.equip(initial)
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
	elif event.is_action_pressed("interact") and not is_open and not player.health.is_dead():
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
	# All acquired weapons occupy backpack space, including equipped weapons.
	var item := backpack.create_and_add_item(component_id)
	if item == null:
		_notify("背包已满（6/6），组件留在地上", &"full")
		return false
	_assign_instance_id(item)
	var is_weapon := str(item.get_property("slot", "")) == "weapon"
	var auto_secondary := is_weapon and not _has_picked_up_weapon and secondary_weapon_slot.get_item() == null
	if is_weapon:
		_has_picked_up_weapon = true
	if auto_secondary:
		secondary_weapon_slot.equip(item)
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
	if slot_name == "weapon":
		var target := weapon_slot if weapon_position == 0 else secondary_weapon_slot
		var other := secondary_weapon_slot if weapon_position == 0 else weapon_slot
		if target.get_item() == item:
			return false
		# One physical item cannot be selected into both positions.
		if other.get_item() == item:
			other.equip(target.get_item())
		target.equip(item)
	else:
		var slot := _slot_for(slot_name)
		if slot == null:
			return false
		var old: InventoryItem = slot.get_item()
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
	if slot_name in ["weapon", "weapon_secondary"]:
		slot.clear()
	elif not backpack.add_item(item):
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
	return null

func _on_backpack_item_removed(item: InventoryItem) -> void:
	var was_equipped := false
	for slot in [weapon_slot, secondary_weapon_slot]:
		if slot.get_item() == item:
			slot.clear()
			was_equipped = true
	if was_equipped:
		_apply_equipment()
	changed.emit()

func _apply_equipment() -> void:
	var weapon := weapon_slot.get_item()
	var secondary := secondary_weapon_slot.get_item()
	player.get_node("WeaponController").set_carried_weapons(
		load(str(weapon.get_property("effect"))) if weapon != null else null,
		load(str(secondary.get_property("effect"))) if secondary != null else null)
	var mode := mobility_slot.get_item()
	player.get_node("MobilityController").set_equipped_mode(load(str(mode.get_property("effect"))) if mode != null else null)

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
