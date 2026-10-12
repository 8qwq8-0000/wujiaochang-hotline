class_name ExitElevator
extends Area2D

signal entered

var enabled: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()


func set_enabled(value: bool) -> void:
	enabled = value
	monitoring = value
	queue_redraw()
	var label := get_node_or_null("Label") as Label
	if label != null:
		label.text = "出口可用" if value else "清除必杀目标"


func _on_body_entered(body: Node) -> void:
	if enabled and body.is_in_group("player"):
		entered.emit()
		var events := get_node_or_null("/root/CombatEvents")
		if events != null:
			events.publish_message("已抵达出口；完整流程将在 FloorController 接续", Color(0.35, 0.85, 1.0))


func _draw() -> void:
	var color := Color(0.2, 0.9, 0.45, 0.55) if enabled else Color(0.45, 0.12, 0.12, 0.55)
	draw_rect(Rect2(-26.0, -34.0, 52.0, 68.0), color, true)
	draw_rect(Rect2(-26.0, -34.0, 52.0, 68.0), color.lightened(0.35), false, 2.0)
