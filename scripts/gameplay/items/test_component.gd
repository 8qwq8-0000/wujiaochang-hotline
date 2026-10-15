extends Area2D
## Test component for Week 1 integration — Member B's domain
## C created this as a placeholder for integration testing

signal picked_up

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		picked_up.emit()
		queue_free()
