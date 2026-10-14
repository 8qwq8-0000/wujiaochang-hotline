class_name StatusComponent
extends Node

signal status_added(id: StringName, duration: float, tags: PackedStringArray)
signal status_refreshed(id: StringName, duration: float)
signal status_removed(id: StringName)
signal statuses_cleared

var _statuses: Dictionary = {}
var _immunity_tags: Dictionary = {}


func _ready() -> void:
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	var expired: Array[StringName] = []
	for id: StringName in _statuses:
		var entry: Dictionary = _statuses[id]
		entry["remaining"] = maxf(float(entry.get("remaining", 0.0)) - delta, 0.0)
		_statuses[id] = entry
		if float(entry["remaining"]) <= 0.0:
			expired.append(id)
	for id in expired:
		remove_status(id)
	set_physics_process(not _statuses.is_empty())


func add_status(id: StringName, duration: float, tags: PackedStringArray = []) -> bool:
	if id.is_empty() or duration <= 0.0 or _is_immune(tags):
		return false
	if _statuses.has(id):
		var entry: Dictionary = _statuses[id]
		entry["remaining"] = maxf(float(entry.get("remaining", 0.0)), duration)
		entry["tags"] = tags.duplicate()
		_statuses[id] = entry
		status_refreshed.emit(id, float(entry["remaining"]))
	else:
		_statuses[id] = {"remaining": duration, "tags": tags.duplicate()}
		status_added.emit(id, duration, tags)
	set_physics_process(true)
	return true


func remove_status(id: StringName) -> bool:
	if not _statuses.erase(id):
		return false
	status_removed.emit(id)
	return true


func clear_all() -> void:
	if _statuses.is_empty():
		return
	_statuses.clear()
	set_physics_process(false)
	statuses_cleared.emit()


func set_immunity(tag: StringName, enabled: bool) -> void:
	if enabled:
		_immunity_tags[tag] = true
	else:
		_immunity_tags.erase(tag)


func get_active_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in _statuses:
		result.append(id)
	return result


func _is_immune(tags: PackedStringArray) -> bool:
	for tag in tags:
		if _immunity_tags.has(StringName(tag)):
			return true
	return false
