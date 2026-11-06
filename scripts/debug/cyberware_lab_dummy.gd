extends Node2D

@onready var health: HealthComponent = $HealthComponent


func _ready() -> void:
	add_to_group("enemies")
	health.health_changed.connect(_on_health_changed)
	queue_redraw()


func _on_health_changed(_current: int, _maximum: int, delta: int) -> void:
	if delta < 0:
		health.set_current_health(health.max_health)
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 16.0, Color(0.05, 0.13, 0.12, 0.9))
	draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 24, CyberUITheme.PHOSPHOR, 2.0)
	draw_line(Vector2(-11, 0), Vector2(11, 0), CyberUITheme.DIM_GREEN, 1.0)
	draw_line(Vector2(0, -11), Vector2(0, 11), CyberUITheme.DIM_GREEN, 1.0)
	draw_string(CyberUITheme.FONT, Vector2(-24, -22), "无限靶", HORIZONTAL_ALIGNMENT_CENTER, 48, 10, CyberUITheme.HIGHLIGHT)
