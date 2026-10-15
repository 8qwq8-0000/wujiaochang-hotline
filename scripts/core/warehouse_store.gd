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
	if json.parse(file.get_as_text()) != OK or not _valid_profile(json.data):
		return _reject("仓库存档格式异常或版本不兼容，原文件已保留")
	_profile = json.data.duplicate(true)
	return true


func get_profile() -> Dictionary:
	load_profile()
	return _profile.duplicate(true)


func commit(chest: Array, loadout: Dictionary) -> bool:
	if not load_profile():
		return false
	var next := {"version": SAVE_VERSION, "chest": chest.duplicate(true), "loadout": loadout.duplicate(true)}
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
	var ids := {}
	for item in items:
		if not item is Dictionary or item.get("protoset") != "res://resources/items/components.json":
			return false
		if not ComponentInventory.PROTOTYPES.data.has(item.get("prototype_id", "")):
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
