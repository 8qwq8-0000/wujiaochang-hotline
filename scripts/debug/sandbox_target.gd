extends Node2D

@onready var health: HealthComponent = $HealthComponent


func _ready() -> void:
	health.health_changed.connect(func(_current: int, _maximum: int, _delta: int) -> void: queue_redraw())
	queue_redraw()


func _draw() -> void:
	var alive := not health.is_dead()
	draw_circle(Vector2.ZERO, 12.0, Color(0.95, 0.28, 0.2) if alive else Color(0.3, 0.3, 0.3))
	draw_string(ThemeDB.fallback_font, Vector2(-12, -18), str(health.current_health), HORIZONTAL_ALIGNMENT_CENTER, 24.0, 12, Color.WHITE)
