class_name StatusComponent
extends Node

signal status_added(id: StringName, duration: float, tags: PackedStringArray)
signal status_refreshed(id: StringName, duration: float)
signal status_removed(id: StringName)
signal statuses_cleared
signal reaction_triggered(id: StringName, secondary_targets: int)

const CONDUCTIVE := &"conductive"
const CONDUCTIVE_SECONDS := 6.0

var _statuses: Dictionary = {}
var _immunity_tags: Dictionary = {}


func _ready() -> void:
	set_physics_process(false)
	if get_parent() is Node2D:
		get_parent().add_to_group("status_actors")


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


func has_status(id: StringName) -> bool:
	return _statuses.has(id) and float(_statuses[id].remaining) > 0.0


func remaining_seconds(id: StringName) -> float:
	return float(_statuses[id].remaining) if _statuses.has(id) else 0.0


func handle_hit(packet: DamagePacket) -> void:
	var actor := get_parent() as Node2D
	if actor == null:
		return
	# Consume existing conductivity before applying this hit's new status tags.
	if packet.allow_status_reactions and packet.damage_type == &"electric" and has_status(CONDUCTIVE):
		remove_status(CONDUCTIVE)
		var count := ElectricReaction.discharge(actor, packet)
		reaction_triggered.emit(&"electric_arc", count)
	var health := actor.get_node_or_null("HealthComponent") as HealthComponent
	if health != null and not health.is_dead() and packet.status_tags.has("conductive"):
		add_status(CONDUCTIVE, CONDUCTIVE_SECONDS, ["negative", "electric"])


func _is_immune(tags: PackedStringArray) -> bool:
	for tag in tags:
		if _immunity_tags.has(StringName(tag)):
			return true
	return false
