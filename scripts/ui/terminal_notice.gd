@tool
class_name TerminalNotice
extends TerminalPanel

@export_multiline var message := "系统就绪" :
	set(value):
		message = value
		_refresh_message()

var _message_label: Label


func _ready() -> void:
	super._ready()
	custom_minimum_size = Vector2(200.0, 30.0)
	if _message_label == null:
		_message_label = Label.new()
		_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_message_label)
	_refresh_message()


func set_notice(next_title: String, next_message: String, color: Color = CyberUITheme.PHOSPHOR) -> void:
	title = next_title
	accent_color = color
	message = next_message
	_refresh_message()


func _refresh_message() -> void:
	if is_instance_valid(_message_label):
		_message_label.text = message
		_message_label.add_theme_color_override("font_color", accent_color)
