class_name DefenseComponent
extends Node

# Cooldown belongs to the item, so swapping, storage and scene changes cannot
# turn a depleted armor into a fresh charge. Unequipped armor pauses recovery.
func equipped_item() -> InventoryItem:
	var inv := get_parent().get_node_or_null("ComponentInventory") as ComponentInventory
	return inv.defense_slot.get_item() if inv != null and inv.defense_slot != null else null

func cooldown_seconds(item: InventoryItem) -> float:
	return ComponentRolls.ARMOR_RECOVERY_SECONDS[ComponentRolls.quality(item) - 1]

func remaining_seconds() -> float:
	var item := equipped_item()
	return maxf(float(item.get_property("armor_cooldown_remaining", 0.0)), 0.0) if item != null else 0.0

func _physics_process(delta: float) -> void:
	var item := equipped_item()
	if item == null or get_parent().get_node("HealthComponent").is_dead():
		return
	var remaining := remaining_seconds()
	if remaining > 0.0:
		item.set_property("armor_cooldown_remaining", maxf(remaining - delta, 0.0))

func absorb(damage: int) -> int:
	var item := equipped_item()
	if damage <= 0 or item == null or remaining_seconds() > 0.0:
		return 0
	item.set_property("armor_cooldown_remaining", cooldown_seconds(item))
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_notice(&"armor_absorbed", "缓冲装甲吸收 1 点伤害", Color("70b7ff"), CombatNotice.Priority.NORMAL, 0.0, 1.2)
	return 1

func display_state() -> String:
	if equipped_item() == null:
		return "防御  未装备"
	return "护甲  就绪 · 吸收1点" if remaining_seconds() <= 0.0 else "护甲  恢复中 %.1fs" % remaining_seconds()
