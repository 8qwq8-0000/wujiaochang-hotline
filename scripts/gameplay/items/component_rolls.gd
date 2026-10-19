class_name ComponentRolls
extends RefCounted

const QUALITIES := ["无品质", "制式", "改良", "原型"]
const WHEEL_RAM_DAMAGE := [2, 3, 4]
const WHEEL_RAM_COOLDOWNS := [1.2, 1.0, 0.8]
const ARMOR_RECOVERY_SECONDS := [12.0, 10.0, 8.0]
const QUALITY_COLORS := [Color("a8b1bd"), Color("e7edf3"), Color("70b7ff"), Color("cf99ff")]

static func quality_color(item: InventoryItem) -> Color:
	return QUALITY_COLORS[quality(item)] if ordinary(item) else Color.WHITE

static func apply_quality_color(control: Control, item: InventoryItem) -> void:
	var color := quality_color(item)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		control.add_theme_color_override(state, color)

# Five broad, additive bonuses. Values are percentages except guard window (ms).
const AFFIXES := {
	"cooling": ["散热", 10, 30], "capacity": ["热量上限", 10, 30],
	"guard": ["完美格挡窗口", 20, 60],
	"mobility": ["机动速度", 10, 25], "status": ["负面状态时长减免", 10, 25],
}

static func ordinary(item: InventoryItem) -> bool:
	return item != null and not bool(item.get_property("bound", false)) and not bool(item.get_property("debug_only", false)) and str(item.get_property("slot", "")) in ["weapon", "mobility", "defense"]

static func synthesizable(item: InventoryItem) -> bool:
	return ordinary(item)

static func synthesis_quality(item: InventoryItem) -> int:
	return quality(item)

# Retired melee weapons become plain issued pistols wherever they were stored.
# Keep instance identity so slot references and duplicate checks remain valid.
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
	if data.get("prototype_id", "") in ["baton", "initial_baton"] and data.get("protoset", "") == "res://resources/items/components.json":
		data.prototype_id = "pistol"
		var properties: Dictionary = create_issued_pistol().serialize().get("properties", {})
		var old_properties: Variant = data.get("properties", {})
		if old_properties is Dictionary and old_properties.has("instance_id"):
			properties.instance_id = old_properties.instance_id
		data.properties = properties
	_migrate_serialized_affixes(data)
	return data

static func _migrate_serialized_affixes(data: Dictionary) -> void:
	var properties: Variant = data.get("properties", {})
	if not properties is Dictionary or not properties.has("affixes"):
		return
	var stored: Variant = properties["affixes"]
	if stored is Dictionary and stored.has("value"):
		var encoded: Variant = stored["value"]
		var decoded: Variant = str_to_var(encoded) if encoded is String else encoded
		if decoded is Dictionary:
			stored["value"] = var_to_str(_migrated_affixes(decoded)) if encoded is String else _migrated_affixes(decoded)
			properties["affixes"] = stored
	elif stored is Dictionary:
		properties["affixes"] = _migrated_affixes(stored)
	data["properties"] = properties


static func _migrated_affixes(value: Dictionary) -> Dictionary:
	var migrated := value.duplicate(true)
	if migrated.has("attack"):
		migrated["capacity"] = maxf(float(migrated.get("capacity", 0.0)), minf(float(migrated["attack"]), 30.0))
		migrated.erase("attack")
	return migrated

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
		item.set_property("affixes", {"capacity" if item.get_property("slot") == "weapon" else "mobility": 20})
	else:
		item.set_property("affixes", _migrated_affixes(affixes(item)))

static func make_item(id: String) -> InventoryItem:
	var prototype_id := "pistol" if id in ["baton", "initial_baton"] else id
	var item := InventoryItem.new(ComponentInventory.PROTOTYPES, prototype_id)
	# Older scene transitions cleared GLoot's process-wide cached ProtoTree.
	# Rebuild it before returning an item so already-authored pickups cannot
	# retain a permanently null prototype after a hot reload or legacy swap.
	if item.get_prototype() == null and ComponentInventory.PROTOTYPES.data.has(prototype_id):
		item.get_prototree().deserialize(ComponentInventory.PROTOTYPES)
		item = InventoryItem.new(ComponentInventory.PROTOTYPES, prototype_id)
	return item

static func create(id: String, tier: int, rng: RandomNumberGenerator) -> InventoryItem:
	if id in ["baton", "initial_baton"]:
		return create_issued_pistol()
	var item := create_without_affixes(id, tier, rng)
	if item.get_prototype() == null:
		return item
	if ordinary(item):
		var pool: Array = AFFIXES.keys()
		for index in rng.randi_range(1, clampi(tier, 1, 3)):
			var key: String = pool.pop_at(rng.randi_range(0, pool.size() - 1))
			var rolled := affixes(item).duplicate()
			rolled[key] = rng.randi_range(AFFIXES[key][1], AFFIXES[key][2])
			item.set_property("affixes", rolled)
	return item


static func create_without_affixes(id: String, tier: int, rng: RandomNumberGenerator) -> InventoryItem:
	var item := make_item(id)
	if item.get_prototype() == null:
		return item
	item.set_property("instance_id", "%d-%d-%d" % [Time.get_ticks_usec(), item.get_instance_id(), rng.randi()])
	if ordinary(item):
		item.set_property("quality", clampi(tier, 1, 3))
		item.set_property("affixes", {})
	return item


static func create_issued_pistol() -> InventoryItem:
	return create_without_affixes("pistol", 1, RandomNumberGenerator.new())

static func title(item: InventoryItem) -> String:
	return "%s · %s" % [QUALITIES[quality(item)], item.get_title()] if ordinary(item) else item.get_title()

static func describe(item: InventoryItem) -> String:
	var lines: Array[String] = [title(item)]
	if item.get_property("slot", "") == "defense":
		lines.append("就绪时吸收1点伤害 · 恢复 %.0f 秒" % ARMOR_RECOVERY_SECONDS[quality(item) - 1])
	if item.get_prototype().get_prototype_id() == "wheel":
		lines.append("冲撞 %d 点伤害 · 冷却 %.1f 秒" % [WHEEL_RAM_DAMAGE[quality(item) - 1], WHEEL_RAM_COOLDOWNS[quality(item) - 1]])
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
	return data

static func mobility_mode(item: InventoryItem, equipped: Array) -> MobilityMode:
	var data: MobilityMode = (load(str(item.get_property("effect"))) if item != null else MobilityController.WALK_MODE).duplicate(true)
	data.max_speed *= 1.0 + bonus(equipped, "mobility") / 100.0
	if data is WheelMobilityMode:
		data.ram_damage = WHEEL_RAM_DAMAGE[quality(item) - 1]
		data.ability_cooldown = WHEEL_RAM_COOLDOWNS[quality(item) - 1]
	return data

static func compatible(a: InventoryItem, b: InventoryItem) -> bool:
	return synthesizable(a) and synthesizable(b) and a != b and a.get_property("instance_id", "") != b.get_property("instance_id", "") and a.get_property("slot") == b.get_property("slot") and synthesis_quality(a) == synthesis_quality(b)

static func fuse(a: InventoryItem, b: InventoryItem, rng: RandomNumberGenerator) -> InventoryItem:
	if not compatible(a, b):
		return null
	var tier := mini(synthesis_quality(a) + 1, 3)
	var result := create(a.get_prototype().get_prototype_id(), tier, rng)
	var affixes_a := _migrated_affixes(affixes(a))
	var affixes_b := _migrated_affixes(affixes(b))
	var merged := affixes_a.duplicate(true)
	for key in affixes_b:
		merged[key] = maxf(float(merged.get(key, 0)), float(affixes_b[key]))
	var selected := {}
	# Shared affixes always survive; choose the remaining distinct entries randomly.
	for key in affixes_a:
		if affixes_b.has(key):
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
