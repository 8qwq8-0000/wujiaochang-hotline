class_name BillboardWallPlaylist
extends RefCounted

const SLOT_COUNT := 4
const DISPLAY_SECONDS := 12.0
const TRANSITION_SECONDS := 0.5
const ITEM_SECONDS := DISPLAY_SECONDS + TRANSITION_SECONDS
const STAGGER_SECONDS := ITEM_SECONDS / float(SLOT_COUNT)

var _slots: Array[StringName] = []
var _deck: Array[StringName] = []
var _event_order: Array[int] = []
var _event_cursor := 0
var _next_deck_index := 0
var _wait_remaining := DISPLAY_SECONDS
var _transition_slot := -1
var _transition_elapsed := 0.0
var _pending_id := StringName()
var _seed := 1
var _enabled := false


func configure(entries: Array[StringName], seed_value: int) -> void:
	var pool: Array[StringName] = []
	for entry in entries:
		if not entry.is_empty() and entry not in pool:
			pool.append(entry)
	_seed = seed_value if seed_value != 0 else 1
	_shuffle(pool, 0)
	_deck.assign(pool)
	_slots.clear()
	for index in mini(SLOT_COUNT, pool.size()):
		_slots.append(pool[index])
	_next_deck_index = _slots.size()
	_event_order.clear()
	for slot_index in _slots.size():
		_event_order.append(slot_index)
	_event_cursor = 0
	_wait_remaining = DISPLAY_SECONDS
	_transition_slot = -1
	_transition_elapsed = 0.0
	_pending_id = StringName()
	_enabled = _slots.size() == SLOT_COUNT and _deck.size() > SLOT_COUNT


func advance(delta: float) -> bool:
	if not _enabled or delta <= 0.0:
		return false
	var remaining := delta
	var changed := false
	while remaining > 0.0:
		if _transition_slot >= 0:
			var transition_step := minf(remaining, TRANSITION_SECONDS - _transition_elapsed)
			_transition_elapsed += transition_step
			remaining -= transition_step
			if _transition_elapsed + 0.0001 >= TRANSITION_SECONDS:
				_commit_transition()
				changed = true
				_wait_remaining = maxf(STAGGER_SECONDS - TRANSITION_SECONDS, 0.0)
			continue
		if remaining < _wait_remaining:
			_wait_remaining -= remaining
			break
		remaining -= _wait_remaining
		_wait_remaining = 0.0
		_start_transition()
	return changed


func slot_id(slot_index: int) -> StringName:
	if slot_index < 0 or slot_index >= _slots.size():
		return StringName()
	return _slots[slot_index]


func visible_ids() -> Array[StringName]:
	return _slots.duplicate()


func slot_count() -> int:
	return _slots.size()


func transition_slot() -> int:
	return _transition_slot


func is_transitioning() -> bool:
	return _transition_slot >= 0


func transition_progress() -> float:
	if not is_transitioning():
		return 0.0
	return clampf(_transition_elapsed / TRANSITION_SECONDS, 0.0, 1.0)


func _start_transition() -> void:
	if _event_order.is_empty():
		return
	_transition_slot = _event_order[_event_cursor]
	_transition_elapsed = 0.0
	_pending_id = _next_hidden_id()
	if _pending_id.is_empty():
		_transition_slot = -1
		_wait_remaining = ITEM_SECONDS


func _commit_transition() -> void:
	_slots[_transition_slot] = _pending_id
	_transition_slot = -1
	_transition_elapsed = 0.0
	_pending_id = StringName()
	_event_cursor = (_event_cursor + 1) % _event_order.size()


func _next_hidden_id() -> StringName:
	for attempt in _deck.size():
		var candidate := _deck[_next_deck_index % _deck.size()]
		_next_deck_index = (_next_deck_index + 1) % _deck.size()
		if candidate not in _slots:
			return candidate
	return StringName()


func _shuffle(values: Array[StringName], seed_offset: int) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = _seed + seed_offset
	for index in range(values.size() - 1, 0, -1):
		var swap_index := random.randi_range(0, index)
		var value := values[index]
		values[index] = values[swap_index]
		values[swap_index] = value
