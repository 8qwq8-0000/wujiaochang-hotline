class_name MovementFeedbackPreview
extends Control

const PERSONAS: Array[StringName] = [
	MovementFeedbackStyle.DEEP_NINJA,
	MovementFeedbackStyle.LEGENDARY_MASTER,
	MovementFeedbackStyle.ROCK_VIGILANTE,
]
const STYLE_SECONDS := 0.95

var _elapsed := -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func preview_cycle() -> void:
	_elapsed = 0.0
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= STYLE_SECONDS * float(PERSONAS.size()):
		_elapsed = -1.0
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if _elapsed < 0.0 or size.x < 40.0:
		return
	var persona_index := mini(int(_elapsed / STYLE_SECONDS), PERSONAS.size() - 1)
	var local_time := fmod(_elapsed, STYLE_SECONDS) / STYLE_SECONDS
	var persona_id := PERSONAS[persona_index]
	var primary := MovementFeedbackStyle.primary_color(persona_id)
	var accent := MovementFeedbackStyle.accent_color(persona_id)
	var reduced := bool(PlayerConfig.get_config(&"UISettings", &"ReducedFlashes", false))
	var low_quality := int(PlayerConfig.get_config(&"UISettings", &"FeedbackQuality", 1)) == 0
	primary.a = 0.5 if reduced else 0.82
	accent.a = 0.58 if reduced else 0.95
	var start := Vector2(42.0, size.y * 0.64)
	var finish := Vector2(size.x - 42.0, size.y * 0.64)
	var eased := 1.0 - pow(1.0 - clampf(local_time * 1.25, 0.0, 1.0), 3.0)
	var head := start.lerp(finish, eased)
	var count := 4 if low_quality else 8
	for index in count:
		var trail_ratio := float(index + 1) / float(count + 1)
		var position := head.lerp(start, trail_ratio * 0.72)
		var fade := 1.0 - trail_ratio
		_draw_style_particle(position, Vector2.RIGHT, persona_id, primary, fade, index)
	_draw_style_particle(head, Vector2.RIGHT, persona_id, accent, 1.0, 0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(12.0, 18.0), MovementFeedbackStyle.display_name(persona_id), HORIZONTAL_ALIGNMENT_LEFT, size.x - 24.0, 12, Color(accent, 0.9))


func _draw_style_particle(position: Vector2, direction: Vector2, persona_id: StringName, color: Color, fade: float, variant: int) -> void:
	color.a *= fade
	var side := direction.orthogonal()
	match MovementFeedbackStyle.visual_style(persona_id):
		MovementFeedbackStyle.VisualStyle.DEEP_NINJA:
			var offset := side * (-3.0 if variant % 2 == 0 else 3.0)
			draw_line(position - direction * 7.0 + offset, position + direction * 3.0 - offset, color, 2.0, true)
		MovementFeedbackStyle.VisualStyle.LEGENDARY_MASTER:
			draw_line(position - side * 4.0, position + side * 4.0, color, 1.5, true)
			if variant % 2 == 0:
				draw_arc(position, 5.0, 0.35, TAU - 0.8, 10, color, 1.0, true)
		MovementFeedbackStyle.VisualStyle.ROCK_VIGILANTE:
			var wave := PackedVector2Array([
				position - direction * 6.0,
				position - direction * 2.0 + side * 3.0,
				position + direction * 2.0 - side * 3.0,
				position + direction * 6.0,
			])
			draw_polyline(wave, color, 1.6, true)
