class_name ComponentRolls
extends RefCounted

const QUALITIES := ["无品质", "制式", "改良", "原型"]
const WHEEL_RAM_DAMAGE := [2, 3, 4]
const WHEEL_RAM_COOLDOWNS := [1.2, 1.0, 0.8]
const ARMOR_RECOVERY_SECONDS := [12.0, 10.0, 10.0]
const ARMOR_CAPACITY := [1, 1, 2]
const QUALITY_COLORS := [Color("a8b1bd"), Color("e7edf3"), Color("70b7ff"), Color("cf99ff")]
const COMPOUND_CYBERWARE_ICON := "res://assets/art/items/equipment_v1/compound_cyberware.png"
const FLOOR_DROP_WEIGHTS := {"pistol": 8, "scattergun": 6, "rail_cannon": 6, "gravity_wave": 4, "armor": 8}
const CYBERWARE_GRADE_WEIGHTS := [8, 10, 5, 2]
const EVENT_STARTER_DROPS := ["combat_synapse_sensor", "combat_synapse_sensor_dash", "combat_synapse_sensor_guard", "combat_synapse_sensor_hit", "combat_synapse_sensor_kill"]
const LEGACY_CYBERWARE_IDS := {"kill_heat_sink": "kill_energy_sink", "heat_threshold_pulser": "shock_pulser"}
static var _cyberware_grade_cache: Dictionary = {}
static var _cyberware_resource_paths_cache: Dictionary = {}

static func quality_color(item: InventoryItem) -> Color:
	return QUALITY_COLORS[quality(item)] if ordinary(item) else Color.WHITE

static func apply_quality_color(control: Control, item: InventoryItem) -> void:
	var color := quality_color(item)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		control.add_theme_color_override(state, color)

# Five broad, additive bonuses. Values are percentages except guard window (ms).
const AFFIXES := {
	"energy_recovery": ["能量恢复", 10, 30], "attack_speed": ["攻击速度", 10, 30],
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
	for field in ["prototype_id", "module_id"]:
		if data.has(field):
			data[field] = LEGACY_CYBERWARE_IDS.get(str(data[field]), data[field])
	if data.has("modules") and data["modules"] is Array:
		var mapped_modules := []
		for module_id in data["modules"]:
			mapped_modules.append(LEGACY_CYBERWARE_IDS.get(str(module_id), module_id))
		data["modules"] = mapped_modules
	elif data.has("modules") and data["modules"] is PackedStringArray:
		var mapped_modules := PackedStringArray()
		for module_id in data["modules"]:
			mapped_modules.append(str(LEGACY_CYBERWARE_IDS.get(module_id, module_id)))
		data["modules"] = mapped_modules
	if data.has("effect"):
		for old_id in LEGACY_CYBERWARE_IDS:
			data["effect"] = str(data["effect"]).replace("/%s.tres" % old_id, "/%s.tres" % LEGACY_CYBERWARE_IDS[old_id])
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
	for old_key in ["attack", "capacity"]:
		if migrated.has(old_key):
			migrated["attack_speed"] = maxf(float(migrated.get("attack_speed", 0.0)), minf(float(migrated[old_key]), 30.0))
			migrated.erase(old_key)
	if migrated.has("cooling"):
		migrated["energy_recovery"] = maxf(float(migrated.get("energy_recovery", 0.0)), minf(float(migrated["cooling"]), 30.0))
		migrated.erase("cooling")
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
		if cyberware_modules(item).size() > 1:
			item.set_property("image", COMPOUND_CYBERWARE_ICON)
		return
	if not ordinary(item):
		return
	if not item.has_property("quality"):
		item.set_property("quality", 1)
	if not item.has_property("affixes"):
		# Deterministic old-save migration, never reroll on loading.
		item.set_property("affixes", {"attack_speed" if item.get_property("slot") == "weapon" else "mobility": 20})
	else:
		item.set_property("affixes", _migrated_affixes(affixes(item)))

static func make_item(id: String) -> InventoryItem:
	var prototype_id: String = "pistol" if id in ["baton", "initial_baton"] else str(LEGACY_CYBERWARE_IDS.get(id, id))
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
	id = LEGACY_CYBERWARE_IDS.get(id, id)
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
	return "%s %s" % [QUALITIES[quality(item)], item.get_title()] if ordinary(item) else item.get_title()

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
		lines.append("护甲 %d 格，每格恢复 %.0f 秒" % [ARMOR_CAPACITY[quality(item) - 1], ARMOR_RECOVERY_SECONDS[quality(item) - 1]])
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
		return false
	return synthesis_quality(a) == synthesis_quality(b)

static func cyberware_overlap_error(a: InventoryItem, b: InventoryItem) -> String:
	if not _is_cyberware(a) or not _is_cyberware(b):
		return ""
	var existing := cyberware_modules(a)
	var names := PackedStringArray()
	for module_id in cyberware_modules(b):
		if module_id in existing:
			var data := load(cyberware_resource_path(StringName(module_id))) as CyberwareData
			names.append(data.display_name if data != null else module_id)
	if names.is_empty():
		return ""
	return "无法合成：主体已包含%s，不能重复加入。材料未消耗。" % "、".join(names)


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
		result.set_property("image", COMPOUND_CYBERWARE_ICON)
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

static func floor_drop(floor_number: int, rng: RandomNumberGenerator, owned_counts: Dictionary = {}) -> InventoryItem:
	var weights := floor_weights(floor_number)
	var roll := rng.randi_range(1, 100)
	var tier := 1 if roll <= weights[0] else (2 if roll <= weights[0] + weights[1] else 3)
	# Keep the former baton's pistol weight without routing a formal drop through
	# create_issued_pistol(), which intentionally creates a bound, affixless item.
	var candidates := {}
	for id in FLOOR_DROP_WEIGHTS:
		candidates[id] = int(FLOOR_DROP_WEIGHTS[id]) * 5
	candidates.merge(_cyberware_drop_candidates(owned_counts))
	var total_weight := 0
	for weight in candidates.values():
		total_weight += int(weight)
	var item_roll := rng.randi_range(1, total_weight)
	for id in candidates:
		item_roll -= int(candidates[id])
		if item_roll <= 0:
			return create(id, tier, rng)
	return create("pistol", tier, rng)


static func floor_equipment_drop(floor_number: int, rng: RandomNumberGenerator) -> InventoryItem:
	var weights := floor_weights(floor_number)
	var roll := rng.randi_range(1, 100)
	var tier := 1 if roll <= weights[0] else (2 if roll <= weights[0] + weights[1] else 3)
	var total_weight := 0
	for weight in FLOOR_DROP_WEIGHTS.values():
		total_weight += int(weight)
	var item_roll := rng.randi_range(1, total_weight)
	for id in FLOOR_DROP_WEIGHTS:
		item_roll -= int(FLOOR_DROP_WEIGHTS[id])
		if item_roll <= 0:
			return create(id, tier, rng)
	return create("pistol", tier, rng)


static func guaranteed_cyberware_drop(
	_floor_number: int, rng: RandomNumberGenerator, owned_counts: Dictionary = {},
	minimum_grade: CyberwareData.Grade = CyberwareData.Grade.STARTER,
) -> InventoryItem:
	var candidates := _cyberware_drop_candidates(owned_counts, minimum_grade)
	if candidates.is_empty():
		return null
	var total_weight := 0
	for weight in candidates.values():
		total_weight += int(weight)
	var item_roll := rng.randi_range(1, total_weight)
	for id in candidates:
		item_roll -= int(candidates[id])
		if item_roll <= 0:
			return create(id, 1, rng)
	return create("smart_fire", 1, rng)


static func _cyberware_drop_candidates(
	owned_counts: Dictionary, minimum_grade: CyberwareData.Grade = CyberwareData.Grade.STARTER,
) -> Dictionary:
	var candidates := {}
	for id in _cyberware_grades():
		if id in EVENT_STARTER_DROPS:
			continue
		var grade := int(_cyberware_grade_cache[id])
		if grade < minimum_grade:
			continue
		var owned := maxi(int(owned_counts.get(StringName(id), owned_counts.get(id, 0))), 0)
		candidates[id] = maxi(1, int(CYBERWARE_GRADE_WEIGHTS[grade]) * 5 / (owned * 3 + 1))
	if minimum_grade > CyberwareData.Grade.STARTER:
		return candidates
	var missing := []
	var owned_mask := 0
	for raw_id in owned_counts:
		if int(owned_counts[raw_id]) <= 0:
			continue
		var id := String(raw_id)
		if id.begins_with("combat_synapse_sensor_combo_"):
			owned_mask |= id.trim_prefix("combat_synapse_sensor_combo_").to_int()
		else:
			var event_index := EVENT_STARTER_DROPS.find(id)
			if event_index >= 0:
				owned_mask |= 1 << event_index
	for index in EVENT_STARTER_DROPS.size():
		if owned_mask & (1 << index) == 0:
			var id: String = EVENT_STARTER_DROPS[index]
			missing.append(id)
	for index in missing.size():
		candidates[missing[index]] = 80 / missing.size() + (1 if index < 80 % missing.size() else 0)
	return candidates


static func _cyberware_grades() -> Dictionary:
	if _cyberware_grade_cache.is_empty():
		for id in cyberware_resource_paths():
			var resource := load(cyberware_resource_path(StringName(id))) as CyberwareData
			if resource != null:
				_cyberware_grade_cache[id] = clampi(resource.grade, 0, 3)
	return _cyberware_grade_cache


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
	return cyberware_resource_paths().get(StringName(LEGACY_CYBERWARE_IDS.get(String(module_id), String(module_id))), "")


static func cyberware_resource_paths() -> Dictionary:
	if _cyberware_resource_paths_cache.is_empty():
		for filename in DirAccess.get_files_at("res://resources/cyberware"):
			if not filename.ends_with(".tres"):
				continue
			var path := "res://resources/cyberware/%s" % filename
			var data := load(path) as CyberwareData
			if data != null and not data.module_id.is_empty():
				_cyberware_resource_paths_cache[data.module_id] = path
	return _cyberware_resource_paths_cache.duplicate()


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
		["蓄", "kill_energy_sink"],
		["震", "shock_pulser"],
		["腱", "momentum_recovery_tendon"],
		["折", "trajectory_echo_processor"],
		["劫", "ballistic_takeover_protocol"],
		["弧", "arc_ballistic_cortex"],
		["逆", "inertial_inversion_vertebra"],
		["轴", "axon_recycler"],
		["转", "micro_rotor_reflex_bundle"],
		["猎", "predatory_vestibular_ring"],
		["域", "omnidirectional_reflection_matrix"],
		["炎", "calamity_flame"],
	]:
		entries.append("[%s%s]" % [entry[0], "●" if entry[1] in modules else "○"])
	return " ".join(entries)


static func _is_cyberware(item: InventoryItem) -> bool:
	return item != null and str(item.get_property("slot", "")) == "cyberware"
