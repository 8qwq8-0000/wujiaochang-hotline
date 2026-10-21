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
	return item != null and not bool(item.get_property("bound", false)) and not bool(item.get_property("debug_only", false)) and str(item.get_property("slot", "")) in ["weapon", "defense"]

static func synthesizable(item: InventoryItem) -> bool:
	return ordinary(item) or _is_cyberware(item)

static func synthesis_quality(item: InventoryItem) -> int:
	return 0 if _is_cyberware(item) else quality(item)

# Retired melee weapons become plain issued pistols wherever they were stored.
# Keep instance identity so slot references and duplicate checks remain valid.
static func migrate_snapshot(value: Variant) -> Variant:
	if value is Array:
		var items := []
		for item in value:
			if item is Dictionary and item.get("prototype_id", "") == "wheel":
				continue
			items.append(migrate_snapshot(item))
		return items
	if not value is Dictionary:
		return value
	var data := {}
	for key in value:
		data[key] = migrate_snapshot(value[key])
	if data.has("mobility") and data.has("primary") and data.has("secondary"):
		data["cyberware"] = data.get("cyberware", {})
		data.erase("mobility")
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
	if _is_cyberware(item):
		if not item.has_property("modules"):
			item.set_property("modules", cyberware_modules(item))
		return
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
	if _is_cyberware(item):
		return cyberware_title(cyberware_modules(item))
	return "%s · %s" % [QUALITIES[quality(item)], item.get_title()] if ordinary(item) else item.get_title()

static func describe(item: InventoryItem) -> String:
	var lines: Array[String] = [title(item)]
	if _is_cyberware(item):
		lines.append(cyberware_indicator(cyberware_modules(item)))
		for module_id in cyberware_modules(item):
			var data := load(cyberware_resource_path(module_id)) as CyberwareData
			if data != null:
				lines.append("• %s：%s" % [data.display_name, data.description])
		return "\n".join(lines)
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
	return data

static func compatible(a: InventoryItem, b: InventoryItem) -> bool:
	if not synthesizable(a) or not synthesizable(b) or a == b or a.get_property("instance_id", "") == b.get_property("instance_id", "") or a.get_property("slot") != b.get_property("slot"):
		return false
	if _is_cyberware(a):
		var a_modules := cyberware_modules(a)
		var b_modules := cyberware_modules(b)
		var union := a_modules.duplicate()
		for module_id in b_modules:
			if module_id not in union:
				union.append(module_id)
		if union.size() > 4:
			return false
		for module_id in b_modules:
			if module_id not in a_modules:
				return true
		for module_id in a_modules:
			if module_id not in b_modules:
				return true
		return false
	return synthesis_quality(a) == synthesis_quality(b)

static func fuse(a: InventoryItem, b: InventoryItem, rng: RandomNumberGenerator) -> InventoryItem:
	if not compatible(a, b):
		return null
	if _is_cyberware(a):
		var result := create_without_affixes(a.get_prototype().get_prototype_id(), 1, rng)
		var merged := cyberware_modules(a)
		for module_id in cyberware_modules(b):
			if module_id not in merged:
				merged.append(module_id)
		merged.sort()
		result.set_property("modules", merged)
		return result
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
	# Keep the former baton's pistol weight without routing a formal drop through
	# create_issued_pistol(), which intentionally creates a bound, affixless item.
	var pool := ["pistol", "pistol", "scattergun", "rail_cannon", "smart_fire", "explosive_magazine", "tactical_coprocessor", "optical_intruder", "kill_heat_sink", "heat_threshold_pulser", "armor"]
	return create(pool[rng.randi_range(0, pool.size() - 1)], tier, rng)


static func cyberware_modules(item: InventoryItem) -> PackedStringArray:
	var result := PackedStringArray()
	if not _is_cyberware(item):
		return result
	var stored: Variant = item.get_property("modules", PackedStringArray())
	if stored is PackedStringArray:
		result = stored.duplicate()
	elif stored is Array:
		for module_id in stored:
			result.append(str(module_id))
	if result.is_empty():
		var data := load(str(item.get_property("effect", ""))) as CyberwareData
		if data != null and not data.module_id.is_empty():
			result.append(data.module_id)
	result.sort()
	return result


static func cyberware_resource_path(module_id: StringName) -> String:
	return {
		&"smart_fire": "res://resources/cyberware/smart_fire.tres",
		&"explosive_magazine": "res://resources/cyberware/explosive_magazine.tres",
		&"tactical_coprocessor": "res://resources/cyberware/tactical_coprocessor.tres",
		&"optical_intruder": "res://resources/cyberware/optical_intruder.tres",
		&"kill_heat_sink": "res://resources/cyberware/kill_heat_sink.tres",
		&"heat_threshold_pulser": "res://resources/cyberware/heat_threshold_pulser.tres",
	}.get(module_id, "")


static func cyberware_title(modules: PackedStringArray) -> String:
	if modules.is_empty():
		return "无义体"
	if modules.size() > 1:
		return "复合义体 [%d/4]" % modules.size()
	var data := load(cyberware_resource_path(StringName(modules[0]))) as CyberwareData
	return data.display_name if data != null else "义体"


static func cyberware_indicator(modules: PackedStringArray) -> String:
	var entries: Array[String] = []
	for entry in [
		["智", "smart_fire"],
		["爆", "explosive_magazine"],
		["协", "tactical_coprocessor"],
		["侵", "optical_intruder"],
		["散", "kill_heat_sink"],
		["震", "heat_threshold_pulser"],
	]:
		entries.append("[%s%s]" % [entry[0], "●" if entry[1] in modules else "○"])
	return " ".join(entries)


static func _is_cyberware(item: InventoryItem) -> bool:
	return item != null and str(item.get_property("slot", "")) == "cyberware"
