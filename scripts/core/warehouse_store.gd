extends Node

## All changes commit the chest and the safe loadout together.
const SAVE_VERSION := 1
var save_path := "user://warehouse.json"
var error_message := ""
var _loaded := false
var _writable := true
var _profile: Dictionary = {
	"version": SAVE_VERSION,
	"chest": [],
	"loadout": {},
	"codex": {"personas": [], "semantic_leaks": []},
	"legacy_drinks": [],
}


func load_profile() -> bool:
	if _loaded:
		return _writable
	_loaded = true
	if not FileAccess.file_exists(save_path):
		return true
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return _reject("无法读取仓库存档，原文件已保留")
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return _reject("仓库存档格式异常或版本不兼容，原文件已保留")
	var migrated: Variant = ComponentRolls.migrate_snapshot(json.data)
	if not _valid_profile(migrated):
		return _reject("仓库存档格式异常或版本不兼容，原文件已保留")
	_profile = _normalize_profile(migrated)
	return true


func get_profile() -> Dictionary:
	load_profile()
	return _profile.duplicate(true)


func commit(
	chest: Array,
	loadout: Dictionary,
	difficulty: String = "",
	legacy_record: Dictionary = {}
) -> bool:
	if not load_profile():
		return false
	var sanitized_loadout := loadout.duplicate(true)
	var archive: Variant = sanitized_loadout.get("persona_archive", {})
	sanitized_loadout.erase("persona_archive")
	var codex: Dictionary = _profile.get("codex", {"personas": [], "semantic_leaks": []}).duplicate(true)
	_merge_persona_archive(codex, archive)
	var legacy_drinks: Array = _profile.get("legacy_drinks", []).duplicate(true)
	if not legacy_record.is_empty():
		legacy_drinks.append(legacy_record.duplicate(true))
		_merge_legacy_record(codex, legacy_record)
	var next := {
		"version": SAVE_VERSION,
		"chest": chest.duplicate(true),
		"loadout": sanitized_loadout,
		"difficulty": difficulty if not difficulty.is_empty() else _profile.get("difficulty", ["low_pressure", "standard", "high_pressure"][int(get_node("/root/GameSettings").difficulty)]),
		"codex": codex,
		"legacy_drinks": legacy_drinks,
	}
	next = ComponentRolls.migrate_snapshot(next)
	if not _valid_profile(next):
		error_message = "装备没有保存，请重试"
		return false
	var temp_path := save_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		error_message = "操作没有保存，请检查可用空间后重试"
		return false
	file.store_string(JSON.stringify(next))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or DirAccess.rename_absolute(temp_path, save_path) != OK:
		error_message = "操作没有保存，请检查可用空间后重试"
		return false
	_profile = next
	error_message = ""
	return true


func _reject(message: String) -> bool:
	_writable = false
	error_message = message
	return false


func _valid_profile(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != SAVE_VERSION:
		return false
	if not value.get("chest") is Array or not value.get("loadout") is Dictionary:
		return false
	if value.get("difficulty", "standard") not in ["low_pressure", "standard", "high_pressure"]:
		return false
	if not value.get("codex", {"personas": [], "semantic_leaks": []}) is Dictionary:
		return false
	var codex: Dictionary = value.get("codex", {"personas": [], "semantic_leaks": []})
	if not codex.get("personas", []) is Array or not codex.get("semantic_leaks", []) is Array:
		return false
	if not value.get("legacy_drinks", []) is Array:
		return false
	for record: Variant in value.get("legacy_drinks", []):
		if not record is Dictionary or not record.get("personas", []) is Array or not record.get("semantic_leaks", []) is Array:
			return false
	var items: Array = value.chest.duplicate()
	var state: Dictionary = value.loadout
	if not state.is_empty():
		if not state.get("inventory") is Dictionary:
			return false
		var inv: Dictionary = state.inventory
		if not inv.get("backpack") is Dictionary:
			return false
		var bag: Dictionary = inv.backpack
		if bag.get("protoset") != "res://resources/items/components.json" or not bag.get("node_name") is String:
			return false
		if not bag.get("items", []) is Array or bag.get("items", []).size() > 6:
			return false
		items.append_array(bag.get("items", []))
		for key in ["primary", "secondary", "cyberware"]:
			if not inv.get(key) is Dictionary:
				return false
			if inv[key].has("item"):
				items.append(inv[key].item)
		# Optional slots keep old v1 saves compatible and join the same ID validation.
		for optional_slot in ["blackbox", "defense"]:
			if inv.has(optional_slot):
				if not inv[optional_slot] is Dictionary:
					return false
				if inv[optional_slot].has("item"):
					items.append(inv[optional_slot].item)
	var ids := {}
	var insurance_count := 0
	for item in items:
		if not item is Dictionary or item.get("protoset") != "res://resources/items/components.json":
			return false
		if not ComponentInventory.PROTOTYPES.data.has(item.get("prototype_id", "")):
			return false
		if item.get("prototype_id") == "circuit_breaker":
			insurance_count += 1
			if insurance_count > 1:
				return false
		if not item.get("properties", {}) is Dictionary:
			return false
		for property in item.get("properties", {}).values():
			if not property is Dictionary or not property.get("type") is float and not property.get("type") is int or not property.get("value") is String:
				return false
		var id: String = item.get("properties", {}).get("instance_id", {}).get("value", "")
		if id.is_empty() or ids.has(id):
			return false
		ids[id] = true
	return true


func has_saved_profile() -> bool:
	return FileAccess.file_exists(save_path)


func create_new_profile(difficulty: String = "standard") -> bool:
	if difficulty not in ["low_pressure", "standard", "high_pressure"]:
		error_message = "请选择一个可用难度"
		return false
	# Back up the raw file, including an unreadable/legacy profile, before replacing
	# anything. Merely entering character selection never writes to the save.
	if has_saved_profile():
		var backup := "%s.backup-%d-%d" % [save_path, int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
		if DirAccess.copy_absolute(save_path, backup) != OK:
			error_message = "无法安全保留旧记录，因此没有新建存档"
			return false
	var previous := _profile.duplicate(true)
	var was_loaded := _loaded
	var was_writable := _writable
	_loaded = true
	_writable = true
	_profile = {
		"version": SAVE_VERSION,
		"chest": [],
		"loadout": {},
		"difficulty": difficulty,
		"codex": {"personas": [], "semantic_leaks": []},
		"legacy_drinks": [],
	}
	if not commit([], {}, difficulty):
		_profile = previous
		_loaded = was_loaded
		_writable = was_writable
		return false
	return true


func get_codex() -> Dictionary:
	load_profile()
	return _profile.get("codex", {"personas": [], "semantic_leaks": []}).duplicate(true)


func get_legacy_drinks() -> Array:
	load_profile()
	return _profile.get("legacy_drinks", []).duplicate(true)


func _normalize_profile(value: Dictionary) -> Dictionary:
	var normalized := value.duplicate(true)
	if not normalized.has("codex"):
		normalized["codex"] = {"personas": [], "semantic_leaks": []}
	if not normalized.has("legacy_drinks"):
		normalized["legacy_drinks"] = []
	return normalized


func _merge_persona_archive(codex: Dictionary, archive: Variant) -> void:
	if not archive is Dictionary:
		return
	var personas: Array = codex.get("personas", [])
	var levels: Variant = archive.get("persona_levels", {})
	if levels is Dictionary:
		for persona_id: Variant in levels:
			if int(levels[persona_id]) > 0 and not String(persona_id) in personas:
				personas.append(String(persona_id))
	var leaks: Array = codex.get("semantic_leaks", [])
	var saved_leaks: Variant = archive.get("semantic_leaks", {})
	if saved_leaks is Dictionary:
		for persona_id: Variant in saved_leaks:
			var leak_id := String(TalentCoreController.SEMANTIC_LEAK_IDS.get(StringName(persona_id), persona_id))
			if bool(saved_leaks[persona_id]) and not leak_id in leaks:
				leaks.append(leak_id)
	personas.sort()
	leaks.sort()
	codex["personas"] = personas
	codex["semantic_leaks"] = leaks


func _merge_legacy_record(codex: Dictionary, record: Dictionary) -> void:
	var personas: Array = codex.get("personas", [])
	for entry: Variant in record.get("personas", []):
		if entry is Dictionary:
			var persona_id := String(entry.get("id", ""))
			if not persona_id.is_empty() and not persona_id in personas:
				personas.append(persona_id)
	var leaks: Array = codex.get("semantic_leaks", [])
	for leak_id: Variant in record.get("semantic_leaks", []):
		if not String(leak_id) in leaks:
			leaks.append(String(leak_id))
	personas.sort()
	leaks.sort()
	codex["personas"] = personas
	codex["semantic_leaks"] = leaks
