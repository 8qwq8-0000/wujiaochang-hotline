class_name CombatCommsController
extends Node

signal message_started(entry: Dictionary, connection_started: bool)
signal collapsed

enum Priority {
	NORMAL,
	HIGH,
	CRITICAL,
}

const MAX_LINE_CHARACTERS := 28
const MAX_HISTORY := 10

var _current: Dictionary = {}
var _pending: Dictionary = {}
var _remaining := 0.0
var _history: Array[Dictionary] = []


func _process(delta: float) -> void:
	if _current.is_empty():
		return
	_remaining = maxf(_remaining - delta, 0.0)
	if _remaining > 0.0:
		return
	if not _pending.is_empty():
		var next := _pending
		_pending = {}
		_start(next, false)
		return
	_current = {}
	collapsed.emit()


func push_message(
	text: String,
	priority: Priority = Priority.NORMAL,
	persona_id: StringName = &"",
	persona_name: String = "",
	display_seconds: float = -1.0
) -> void:
	var chunks := _split_message(text)
	for index in chunks.size():
		var entry := {
			"text": chunks[index],
			"priority": int(priority),
			"persona_id": persona_id,
			"persona_name": persona_name,
			"display_seconds": display_seconds,
		}
		_enqueue(entry, index == 0)


func clear() -> void:
	_current = {}
	_pending = {}
	_remaining = 0.0
	collapsed.emit()


func get_history() -> Array[Dictionary]:
	return _history.duplicate(true)


func is_expanded() -> bool:
	return not _current.is_empty()


func _enqueue(entry: Dictionary, may_interrupt: bool) -> void:
	if _current.is_empty():
		_start(entry, true)
		return
	if String(_current.get("text", "")) == String(entry.text):
		_remaining = maxf(_remaining, _duration_for(entry))
		return
	if may_interrupt and int(entry.priority) >= Priority.CRITICAL:
		_start(entry, false)
		return
	if _pending.is_empty() or int(entry.priority) >= int(_pending.get("priority", Priority.NORMAL)):
		_pending = entry


func _start(entry: Dictionary, connection_started: bool) -> void:
	_current = entry
	_remaining = _duration_for(entry)
	_history.append(entry.duplicate(true))
	while _history.size() > MAX_HISTORY:
		_history.pop_front()
	message_started.emit(_current.duplicate(true), connection_started)


func _duration_for(entry: Dictionary) -> float:
	var requested := float(entry.get("display_seconds", -1.0))
	if requested > 0.0:
		return clampf(requested, 2.5, 4.0)
	return clampf(2.5 + float(String(entry.text).length()) * 0.05, 2.5, 4.0)


func _split_message(text: String) -> PackedStringArray:
	var compact := text.strip_edges().replace("\r", "")
	if compact.is_empty():
		return PackedStringArray()
	var chunks := PackedStringArray()
	for paragraph in compact.split("\n", false):
		var remaining := String(paragraph).strip_edges()
		while remaining.length() > MAX_LINE_CHARACTERS:
			var split_at := _best_split(remaining)
			chunks.append(remaining.left(split_at).strip_edges())
			remaining = remaining.substr(split_at).strip_edges()
		if not remaining.is_empty():
			chunks.append(remaining)
	return chunks


func _best_split(text: String) -> int:
	var limit := mini(MAX_LINE_CHARACTERS, text.length())
	for index in range(limit - 1, maxi(limit / 2, 1), -1):
		if text[index] in "，。！？；、,.!?; ":
			return index + 1
	return limit
