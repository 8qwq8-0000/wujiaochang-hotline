class_name CombatNotice
extends RefCounted

enum Priority { LOW, NORMAL, HIGH }

var id: StringName
var text: String
var color: Color
var priority: Priority
var merge_window: float
var display_seconds: float


func _init(
	notice_id: StringName,
	notice_text: String,
	notice_color: Color = Color.WHITE,
	notice_priority: Priority = Priority.NORMAL,
	notice_merge_window: float = 0.0,
	notice_display_seconds: float = 1.5
) -> void:
	id = notice_id
	text = notice_text
	color = notice_color
	priority = notice_priority
	merge_window = maxf(notice_merge_window, 0.0)
	display_seconds = maxf(notice_display_seconds, 0.1)
