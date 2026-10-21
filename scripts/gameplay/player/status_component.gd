class_name StatusComponent
extends Node

signal status_added(id: StringName, duration: float, tags: PackedStringArray)
signal status_refreshed(id: StringName, duration: float)
signal status_removed(id: StringName)
signal statuses_cleared
signal reaction_triggered(id: StringName, secondary_targets: int)

const CONDUCTIVE := &"conductive"
const CONDUCTIVE_SECONDS := 6.0

var equipment_negative_duration_reduction := 0.0
var _statuses: Dictionary = {}
var _immunity_tags: Dictionary = {}


func _ready() -> void:
	set_physics_process(false)
	if get_parent() is Node2D:
		get_parent().add_to_group("status_actors")


func _physics_process(delta: float) -> void:
	var expired: Array[StringName] = []
	for id: StringName in _statuses.keys():
		if not _statuses.has(id):
			continue
		var entry: Dictionary = _statuses[id]
		if id == &"burning" and entry.has("packet"):
			entry["tick_elapsed"] = float(entry.get("tick_elapsed", 0.0)) + minf(delta, float(entry.remaining))
			_statuses[id] = entry
			while float(entry.tick_elapsed) >= 1.0 - 0.000001 and _statuses.has(id):
				entry.tick_elapsed = maxf(0,float(entry.tick_elapsed)-1.0)
				_statuses[id] = entry
				var packet: DamagePacket = entry.packet.duplicate_packet()
				get_parent().get_node("HurtBox").receive_hit(packet)
			# Insurance can clear all negative statuses from inside damage resolution.
			if not _statuses.has(id):
				continue
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
	if tags.has("negative"):
		duration *= 1.0 - clampf(equipment_negative_duration_reduction, 0.0, 0.75)
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
	var settings := get_node_or_null("/root/GameSettings")
	if settings != null and not settings.are_elemental_reactions_enabled():
		return
	# Consume existing conductivity before applying this hit's new status tags.
	var consumed_conductive := false
	if packet.allow_status_reactions and packet.damage_type == &"electric" and has_status(CONDUCTIVE) and packet.electric_event.get("conductive_ids", {}).has(actor.get_instance_id()):
		consumed_conductive = true
		remove_status(CONDUCTIVE)
		var count := ElectricReaction.discharge(actor, packet)
		reaction_triggered.emit(&"electric_arc", count)
	var health := actor.get_node_or_null("HealthComponent") as HealthComponent
	if health == null or health.is_dead():
		return
	if packet.allow_status_reactions and packet.damage_type in [&"fire", &"thermal"] and has_status(&"oiled"):
		ignite(packet)
	if packet.status_tags.has("oiled"):
		add_status(&"oiled", 6.0, ["negative", "oil"])
	if health != null and not health.is_dead() and packet.status_tags.has("conductive") and not consumed_conductive:
		add_status(CONDUCTIVE, CONDUCTIVE_SECONDS, ["negative", "electric"])


func _is_immune(tags: PackedStringArray) -> bool:
	for tag in tags:
		if _immunity_tags.has(StringName(tag)):
			return true
	return false

func ignite(incoming: DamagePacket) -> bool:
	if not has_status(&"oiled") or not add_status(&"burning", 3.0, ["negative", "fire"]):
		return false
	remove_status(&"oiled")
	var tick := incoming.duplicate_packet()
	tick.base_damage = 1
	tick.damage_type = &"fire"
	tick.status_tags = []
	tick.allow_status_reactions = false
	tick.is_area_damage = true
	tick.is_projectile = false
	tick.is_melee = false
	tick.blockable = false
	tick.reflectable = false
	tick.knockback = Vector2.ZERO
	tick.stagger_seconds = 0
	var entry: Dictionary = _statuses[&"burning"]
	entry["packet"] = tick
	entry["tick_elapsed"] = float(entry.get("tick_elapsed", 0.0))
	_statuses[&"burning"] = entry
	reaction_triggered.emit(&"oil_ignite", 0)
	return true
