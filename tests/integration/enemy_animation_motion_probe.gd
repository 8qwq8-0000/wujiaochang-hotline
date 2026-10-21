extends EnemyController

## Deterministic real physics movement for playback regression/capture.
var motion := Vector2.ZERO


func _physics_process(_delta: float) -> void:
	velocity = motion
	move_and_slide()
