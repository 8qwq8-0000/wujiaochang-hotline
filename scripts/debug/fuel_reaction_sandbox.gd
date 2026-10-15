extends "res://scripts/debug/electric_reaction_sandbox.gd"

const CHEST_PANEL := preload("res://scripts/ui/warehouse_panel.gd")
var chest: Inventory
var panel: CanvasLayer

func _ready() -> void:
	super._ready()
	player.inventory.allow_trial_equipment_changes = true
	$UI/Ignite.pressed.connect(_shock_targets)
	chest = Inventory.new()
	chest.name = "TestItems"
	chest.protoset = ComponentInventory.PROTOTYPES
	add_child(chest)
	_restock()
	panel = CanvasLayer.new()
	panel.set_script(CHEST_PANEL)
	panel.room = self
	panel.fixed_chest_catalog = true
	panel.heading_text = "试验场 / 测试储物箱"
	panel.open_message = "点击取用正式道具 · 自动补货 · 关闭后 Tab 拖动配装 · 不写入正式存档"
	add_child(panel)

func _shock_targets() -> void:
	if get_tree().paused or player.health.is_dead():
		return
	var event := ElectricReaction.begin_event(self)
	for target in $Targets.get_children():
		if not target is EnemyController or target.health.is_dead():
			continue
		var packet := DamagePacket.new()
		packet.damage_type = &"electric"
		packet.source_faction = CombatFaction.Id.ENVIRONMENT
		packet.status_tags = ["conductive"]
		packet.electric_event = event
		packet.blockable = false
		target.hurt_box.receive_hit(packet)

func _restock() -> void:
	for id: String in ComponentInventory.PROTOTYPES.data:
		var prototype: Dictionary = ComponentInventory.PROTOTYPES.data[id]
		if prototype.get("debug_only", false) or prototype.get("bound", false):
			continue
		var stocked := false
		for item in chest.get_items():
			if item.get_prototype().get_prototype_id() == id:
				stocked = true
				break
		if not stocked:
			var item := InventoryItem.new(ComponentInventory.PROTOTYPES, id)
			player.inventory._assign_instance_id(item)
			chest.add_item(item)

func transfer(item: InventoryItem, deposit: bool) -> bool:
	if item == null or not panel.is_open or player.health.is_dead():
		return false
	var moved := player.inventory.move_to_storage(item, chest) if deposit else player.inventory.take_from_storage(item, chest)
	if moved:
		_restock()
		panel.show_message("已存入测试箱" if deposit else "已取出到背包 · 箱内已补货，关闭后 Tab 配装")
	elif not deposit and item.get_property("slot", "") == "insurance" and player.inventory.get_insurance_item() != null:
		panel.show_message("保险核心只能持有一个，请先把当前核心存回箱子")
	else:
		panel.show_message("绑定初始装备不能存入" if deposit else "背包已满，请先存回物品或关闭箱子后配装")
	panel.refresh()
	return moved
