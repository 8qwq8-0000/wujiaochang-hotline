class_name BillboardPlaylist
extends RefCounted

const DISPLAY_SECONDS := 12.0
const TRANSITION_SECONDS := 0.5
const ITEM_SECONDS := DISPLAY_SECONDS + TRANSITION_SECONDS

var _source: Array[StringName] = []
var _order: Array[StringName] = []
var _cursor := 0
var _elapsed := 0.0
var _seed := 1
var _cycle := 0


func configure(entries: Array[StringName], seed_value: int) -> void:
	_source.clear()
	for entry in entries:
		if not entry.is_empty() and entry not in _source:
			_source.append(entry)
	_seed = seed_value if seed_value != 0 else 1
	_cycle = 0
	_cursor = 0
	_elapsed = 0.0
	_rebuild_order(StringName())


func advance(delta: float) -> bool:
	if _order.is_empty() or delta <= 0.0:
		return false
	var changed := false
	_elapsed += delta
	while _elapsed >= ITEM_SECONDS:
		_elapsed -= ITEM_SECONDS
		_step_to_next()
		changed = true
	return changed


func current_id() -> StringName:
	return _order[_cursor] if not _order.is_empty() else StringName()


func is_transitioning() -> bool:
	return not _order.is_empty() and _elapsed >= DISPLAY_SECONDS


func transition_progress() -> float:
	if not is_transitioning():
		return 0.0
	return clampf((_elapsed - DISPLAY_SECONDS) / TRANSITION_SECONDS, 0.0, 1.0)


func elapsed() -> float:
	return _elapsed


func entry_count() -> int:
	return _source.size()


func _step_to_next() -> void:
	_cursor += 1
	if _cursor < _order.size():
		return
	var previous: StringName = _order.back()
	_cycle += 1
	_cursor = 0
	_rebuild_order(previous)


func _rebuild_order(previous: StringName) -> void:
	_order.assign(_source)
	var random := RandomNumberGenerator.new()
	random.seed = _seed + _cycle * 104729
	for index in range(_order.size() - 1, 0, -1):
		var swap_index := random.randi_range(0, index)
		var value: StringName = _order[index]
		_order[index] = _order[swap_index]
		_order[swap_index] = value
	if _order.size() > 1 and not previous.is_empty() and _order[0] == previous:
		var value: StringName = _order[0]
		_order[0] = _order[1]
		_order[1] = value
