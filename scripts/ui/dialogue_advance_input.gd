class_name DialogueAdvanceInput
extends RefCounted

# Handle native touches directly. Their synthesized mouse events must not
# advance the same line a second time. Extra fingers and releases do nothing.
static func is_tap(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return event.pressed and event.index == 0 and not event.canceled
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION


static func position(event: InputEvent) -> Vector2:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		return event.position
	return Vector2.ZERO
