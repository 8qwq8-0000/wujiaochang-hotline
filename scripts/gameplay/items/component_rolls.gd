class_name ComponentRolls
extends RefCounted

const QUALITIES := ["无品质", "制式", "改良", "原型"]
const ARMOR_RECOVERY_SECONDS := [12.0, 10.0, 8.0]
const QUALITY_COLORS := [Color("a8b1bd"), Color("e7edf3"), Color("70b7ff"), Color("cf99ff")]

static func quality_color(item: InventoryItem) -> Color:
	return QUALITY_COLORS[quality(item)] if ordinary(item) else Color.WHITE

static func apply_quality_color(control: Control, item: InventoryItem) -> void:
	var color := quality_color(item)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		control.add_theme_color_override(state, color)

# Six broad, additive bonuses. Values are percentages except guard window (ms).
const AFFIXES := {
	"attack": ["攻击", 20, 50], "cooling": ["散热", 10, 30],
	"capacity": ["热量上限", 10, 30], "guard": ["完美格挡窗口", 20, 60],
	"mobility": ["机动速度", 10, 25], "status": ["负面状态时长减免", 10, 25],
}

static func ordinary(item: InventoryItem) -> bool:
	return item != null and not bool(item.get_property("bound", false)) and not bool(item.get_property("debug_only", false)) and str(item.get_property("slot", "")) in ["weapon", "mobility", "defense"]

static func synthesizable(item: InventoryItem) -> bool:
	return ordinary(item)

static func synthesis_quality(item: InventoryItem) -> int:
	return quality(item)

# Migrate serialized items before GLoot resolves their prototype. Preserve ID,
# quality, affixes and cooldowns, while discarding the old bound-only overrides.
static func migrate_snapshot(value: Variant) -> Variant:
	if value is Array:
		var items := []
		for item in value:
			items.append(migrate_snapshot(item))
		return items
	if not value is Dictionary:
		return value
	var data := {}
	for key in value:
		data[key] = migrate_snapshot(value[key])
	if data.get("prototype_id", "") == "initial_baton" and data.get("protoset", "") == "res://resources/items/components.json":
		data.prototype_id = "baton"
		var properties: Variant = data.get("properties", {})
		if properties is Dictionary:
			properties.erase("bound")
			properties.erase("name")
			properties.erase("effect")
			data.properties = properties
	return data

static func quality(item: InventoryItem) -> int:
	return clampi(int(item.get_property("quality", 1)), 1, 3) if ordinary(item) else 0

static func affixes(item: InventoryItem) -> Dictionary:
	var value: Variant = item.get_property("affixes", {})
	return value if value is Dictionary else {}

static func ensure(item: InventoryItem) -> void:
	if not ordinary(item):
		return
	if not item.has_property("quality"):
		item.set_property("quality", 1)
	if not item.has_property("affixes"):
		# Deterministic old-save migration, never reroll on loading.
		item.set_property("affixes", {"attack" if item.get_property("slot") == "weapon" else "mobility": 20})

static func create(id: String, tier: int, rng: RandomNumberGenerator) -> InventoryItem:
	var item := InventoryItem.new(ComponentInventory.PROTOTYPES, "baton" if id == "initial_baton" else id)
	item.set_property("instance_id", "%d-%d-%d" % [Time.get_ticks_usec(), item.get_instance_id(), rng.randi()])
	if ordinary(item):
		item.set_property("quality", clampi(tier, 1, 3))
		var pool: Array = AFFIXES.keys()
		if item.get_property("slot") != "weapon":
			pool.erase("attack")
		var rolled := {}
		for index in rng.randi_range(1, clampi(tier, 1, 3)):
			var key: String = pool.pop_at(rng.randi_range(0, pool.size() - 1))
			rolled[key] = rng.randi_range(AFFIXES[key][1], AFFIXES[key][2])
		item.set_property("affixes", rolled)
	return item

static func title(item: InventoryItem) -> String:
	return "%s · %s" % [QUALITIES[quality(item)], item.get_title()] if ordinary(item) else item.get_title()

static func describe(item: InventoryItem) -> String:
	var lines: Array[String] = [title(item)]
	if item.get_property("slot", "") == "defense":
		lines.append("就绪时吸收1点伤害 · 恢复 %.0f 秒" % ARMOR_RECOVERY_SECONDS[quality(item) - 1])
	for key in affixes(item):
		if AFFIXES.has(key):
			lines.append("%s +%s%s" % [AFFIXES[key][0], affixes(item)[key], "毫秒" if key == "guard" else "%"])
	return "\n".join(lines)

static func bonus(items: Array, key: String) -> float:
	var total := 0.0
	for item in items:
		if item != null:
			total += float(affixes(item).get(key, 0))
	return total

static func weapon(item: InventoryItem) -> WeaponComponentData:
	if item == null:
		return null
	var data: WeaponComponentData = load(str(item.get_property("effect"))).duplicate(true)
	data.damage = maxi(1, ceili(data.damage * (1.0 + bonus([item], "attack") / 100.0)))
	return data

static func compatible(a: InventoryItem, b: InventoryItem) -> bool:
	return synthesizable(a) and synthesizable(b) and a != b and a.get_property("instance_id", "") != b.get_property("instance_id", "") and a.get_property("slot") == b.get_property("slot") and synthesis_quality(a) == synthesis_quality(b)

static func fuse(a: InventoryItem, b: InventoryItem, rng: RandomNumberGenerator) -> InventoryItem:
	if not compatible(a, b):
		return null
	var tier := mini(synthesis_quality(a) + 1, 3)
	var result := create(a.get_prototype().get_prototype_id(), tier, rng)
	var merged := affixes(a).duplicate(true)
	for key in affixes(b):
		merged[key] = maxf(float(merged.get(key, 0)), float(affixes(b)[key]))
	var selected := {}
	# Shared affixes always survive; choose the remaining distinct entries randomly.
	for key in affixes(a):
		if affixes(b).has(key):
			selected[key] = merged[key]
	var pool: Array = merged.keys()
	for key in selected:
		pool.erase(key)
	while not pool.is_empty() and selected.size() < tier:
		var key: String = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		selected[key] = merged[key]
	if not selected.is_empty():
		result.set_property("affixes", selected)
	return result

static func floor_weights(floor_number: int) -> Array:
	return [[85, 14, 1], [65, 30, 5], [40, 45, 15], [20, 45, 35]][clampi(floor_number - 1, 0, 3)]

static func floor_drop(floor_number: int, rng: RandomNumberGenerator) -> InventoryItem:
	var weights := floor_weights(floor_number)
	var roll := rng.randi_range(1, 100)
	var tier := 1 if roll <= weights[0] else (2 if roll <= weights[0] + weights[1] else 3)
	var pool := ["baton", "pistol", "scattergun", "wheel", "armor"]
	return create(pool[rng.randi_range(0, pool.size() - 1)], tier, rng)
