@tool
extends Sprite2D

## A complete, mirrored PNG. Actual wall and doorway artwork occludes its back.
var _phase := 0.0
var _proximity := 0.0

func _ready() -> void:
	z_as_relative = false
	z_index = -2
	_update_brightness()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_phase = fmod(_phase + delta, TAU * 10.0)
	var doorway := get_parent()
	var actor := doorway.get_parent().get_node_or_null("Player") as Node2D
	if not is_instance_valid(actor):
		actor = get_tree().get_first_node_in_group("player") as Node2D
	var near: bool = is_instance_valid(actor) and doorway.can_interact(actor)
	_proximity = move_toward(_proximity, 1.0 if near else 0.0, delta * 3.5)
	_update_brightness()

func _update_brightness() -> void:
	var breathing := 0.88 + 0.12 * sin(_phase * 1.8)
	self_modulate = Color(1, 1, 1, lerpf(0.45, 1.0, _proximity) * breathing)
