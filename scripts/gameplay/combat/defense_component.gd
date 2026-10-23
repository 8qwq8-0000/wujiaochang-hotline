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

func capacity() -> int:
	var item := equipped_item()
	return ComponentRolls.ARMOR_CAPACITY[ComponentRolls.quality(item) - 1] if item != null else 0

func charges() -> int:
	if remaining_seconds() <= 0.0:
		return capacity()
	return capacity() - clampi(int(equipped_item().get_property("armor_missing_charges", capacity())), 0, capacity())

func _physics_process(delta: float) -> void:
	var item := equipped_item()
	if item == null or get_parent().get_node("HealthComponent").is_dead():
		return
	var remaining := remaining_seconds()
	if remaining > 0.0:
		var missing := capacity() - charges()
		remaining -= delta
		while remaining <= 0.0 and missing > 0:
			missing -= 1
			if missing > 0:
				remaining += cooldown_seconds(item)
		item.set_property("armor_missing_charges", missing)
		item.set_property("armor_cooldown_remaining", maxf(remaining, 0.0) if missing > 0 else 0.0)

func absorb(damage: int) -> int:
	var item := equipped_item()
	if damage <= 0 or item == null or charges() <= 0:
		return 0
	var absorbed := mini(damage, charges())
	item.set_property("armor_missing_charges", capacity() - charges() + absorbed)
	if remaining_seconds() <= 0.0:
		item.set_property("armor_cooldown_remaining", cooldown_seconds(item))
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_notice(&"armor_absorbed", "缓冲装甲吸收 %d 点伤害" % absorbed, Color("70b7ff"), CombatNotice.Priority.NORMAL, 0.0, 1.2)
	return absorbed

func display_state() -> String:
	if equipped_item() == null:
		return "防御  未装备"
	return "蓝血 %d/%d" % [charges(), capacity()] + (" · 恢复中 %.1fs" % remaining_seconds() if remaining_seconds() > 0.0 else " · 就绪")
