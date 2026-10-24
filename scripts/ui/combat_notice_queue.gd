class_name CombatNoticeQueue
extends VBoxContainer

const TUTORIAL_ID := &"controls_tutorial"

@export_range(1, 6, 1) var max_visible: int = 3
@export_range(0.05, 1.0, 0.05) var fade_seconds: float = 0.35
@export_multiline var tutorial_text := "WASD 移动，鼠标战斗，Space 机动，Tab 背包"

var _entries: Array[Dictionary] = []
var _sequence := 0
var _logical_time := 0.0


func _ready() -> void:
	if not tutorial_text.is_empty():
		_add_entry(CombatNotice.new(TUTORIAL_ID, tutorial_text, CyberUITheme.PHOSPHOR, CombatNotice.Priority.LOW, 0.0, 3600.0), true)
	set_process(true)


func _process(delta: float) -> void:
	# This node follows the SceneTree pause state. Existing notices therefore freeze
	# while inventory is open, while signal callbacks can still append new entries.
	_logical_time += delta
	var expired: Array[Dictionary] = []
	for entry in _entries:
		if bool(entry["persistent"]):
			continue
		entry["remaining"] = float(entry["remaining"]) - delta
		var label := entry["label"] as Label
		if is_instance_valid(label):
			label.modulate.a = clampf(float(entry["remaining"]) / fade_seconds, 0.0, 1.0) if float(entry["remaining"]) < fade_seconds else 1.0
		if float(entry["remaining"]) <= 0.0:
			expired.append(entry)
	for entry in expired:
		_remove_entry(entry)
	if not expired.is_empty():
		_refresh_order()


func push_notice(notice: CombatNotice) -> void:
	if notice == null or notice.text.is_empty():
		return
	if notice.id != TUTORIAL_ID:
		_remove_tutorial()
	if notice.id != &"" and notice.merge_window > 0.0:
		for entry in _entries:
			var current := entry["notice"] as CombatNotice
			if (
				current.id == notice.id
				and str(entry["base_text"]) == notice.text
				and _logical_time - float(entry["last_time"]) <= notice.merge_window
			):
				entry["count"] = int(entry["count"]) + 1
				entry["last_time"] = _logical_time
				entry["remaining"] = notice.display_seconds
				entry["base_text"] = notice.text
				current.color = notice.color
				current.priority = notice.priority
				_update_entry_label(entry)
				_refresh_order()
				return
	_add_entry(notice, false)
	_trim_to_budget()
	_refresh_order()


func push_legacy(text: String, color: Color = Color.WHITE) -> void:
	push_notice(CombatNotice.new(&"", text, color, CombatNotice.Priority.NORMAL))


func clear_all() -> void:
	for entry in _entries.duplicate():
		_remove_entry(entry)
	_entries.clear()


func get_visible_notices() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in _entries:
		var notice := entry["notice"] as CombatNotice
		result.append({
			"id": notice.id,
			"text": _entry_text(entry),
			"priority": notice.priority,
			"count": int(entry["count"]),
		})
	return result


func _add_entry(notice: CombatNotice, persistent: bool) -> void:
	_sequence += 1
	var label := Label.new()
	label.custom_minimum_size.y = 32.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_color_override("font_color", notice.color)
	label.add_theme_color_override("font_outline_color", CyberUITheme.BACKGROUND)
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_stylebox_override("normal", CyberUITheme.create_box(Color(CyberUITheme.PANEL, 0.68), notice.color))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var entry := {
		"notice": notice,
		"base_text": notice.text,
		"count": 1,
		"remaining": notice.display_seconds,
		"last_time": _logical_time,
		"sequence": _sequence,
		"persistent": persistent,
		"label": label,
	}
	_entries.append(entry)
	_update_entry_label(entry)


func _remove_tutorial() -> void:
	for entry in _entries.duplicate():
		var notice := entry["notice"] as CombatNotice
		if notice.id == TUTORIAL_ID:
			_remove_entry(entry)


func _trim_to_budget() -> void:
	while _entries.size() > max_visible:
		var worst := _entries[0]
		for entry in _entries:
			var priority := int((entry["notice"] as CombatNotice).priority)
			var worst_priority := int((worst["notice"] as CombatNotice).priority)
			if priority < worst_priority or (priority == worst_priority and int(entry["sequence"]) < int(worst["sequence"])):
				worst = entry
		_remove_entry(worst)


func _remove_entry(entry: Dictionary) -> void:
	_entries.erase(entry)
	var label := entry.get("label") as Label
	if is_instance_valid(label):
		label.queue_free()


func _refresh_order() -> void:
	_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_priority := int((a["notice"] as CombatNotice).priority)
		var b_priority := int((b["notice"] as CombatNotice).priority)
		return a_priority > b_priority if a_priority != b_priority else int(a["sequence"]) < int(b["sequence"])
	)
	for index in _entries.size():
		var label := _entries[index]["label"] as Label
		if is_instance_valid(label):
			move_child(label, index)
			_update_entry_label(_entries[index])


func _update_entry_label(entry: Dictionary) -> void:
	var notice := entry["notice"] as CombatNotice
	var label := entry["label"] as Label
	if not is_instance_valid(label):
		return
	label.text = _entry_text(entry)
	label.add_theme_color_override("font_color", notice.color)
	label.add_theme_stylebox_override("normal", CyberUITheme.create_box(Color(CyberUITheme.PANEL, 0.68), notice.color))
	label.modulate.a = 1.0


func _entry_text(entry: Dictionary) -> String:
	var count := int(entry["count"])
	return "%s ×%d" % [str(entry["base_text"]), count] if count > 1 else str(entry["base_text"])
