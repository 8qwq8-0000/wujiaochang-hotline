extends Node

## All changes commit the chest and the safe loadout together.
const SAVE_VERSION := 1
var save_path := "user://warehouse.json"
var error_message := ""
var _loaded := false
var _writable := true
var _profile: Dictionary = {"version": SAVE_VERSION, "chest": [], "loadout": {}}


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
	_profile = migrated.duplicate(true)
	return true


func get_profile() -> Dictionary:
	load_profile()
	return _profile.duplicate(true)


func commit(chest: Array, loadout: Dictionary, difficulty: String = "") -> bool:
	if not load_profile():
		return false
	var next := {"version": SAVE_VERSION, "chest": chest.duplicate(true), "loadout": loadout.duplicate(true), "difficulty": difficulty if not difficulty.is_empty() else _profile.get("difficulty", ["low_pressure", "standard", "high_pressure"][int(get_node("/root/GameSettings").difficulty)])}
	next = ComponentRolls.migrate_snapshot(next)
	if not _valid_profile(next):
		error_message = "装备数据异常，未保存"
		return false
	var temp_path := save_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		error_message = "无法写入仓库存档，本次操作已取消"
		return false
	file.store_string(JSON.stringify(next))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or DirAccess.rename_absolute(temp_path, save_path) != OK:
		error_message = "仓库存档写入失败，本次操作已取消"
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
		for key in ["primary", "secondary", "mobility"]:
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
		error_message = "无效的难度选项"
		return false
	# Back up the raw file, including an unreadable/legacy profile, before replacing
	# anything. Merely entering character selection never writes to the save.
	if has_saved_profile():
		var backup := "%s.backup-%d-%d" % [save_path, int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
		if DirAccess.copy_absolute(save_path, backup) != OK:
			error_message = "旧存档备份失败，未创建新存档"
			return false
	var previous := _profile.duplicate(true)
	var was_loaded := _loaded
	var was_writable := _writable
	_loaded = true
	_writable = true
	if not commit([], {}, difficulty):
		_profile = previous
		_loaded = was_loaded
		_writable = was_writable
		return false
	return true
