class_name MovementFeedbackStyle
extends RefCounted

enum VisualStyle {
	NEUTRAL,
	DEEP_NINJA,
	LEGENDARY_MASTER,
	ROCK_VIGILANTE,
}

const DEEP_NINJA := &"deep_ninja"
const LEGENDARY_MASTER := &"legendary_master"
const ROCK_VIGILANTE := &"rock_vigilante"


static func persona_id_for(source: Node) -> StringName:
	if not source is PlayerController:
		return &""
	var player := source as PlayerController
	if not is_instance_valid(player.talent_core):
		return &""
	var persona_id := player.talent_core.current_persona_id
	return persona_id if player.talent_core.get_persona_level(persona_id) > 0 else &""


static func visual_style(persona_id: StringName) -> VisualStyle:
	match persona_id:
		DEEP_NINJA:
			return VisualStyle.DEEP_NINJA
		LEGENDARY_MASTER:
			return VisualStyle.LEGENDARY_MASTER
		ROCK_VIGILANTE:
			return VisualStyle.ROCK_VIGILANTE
		_:
			return VisualStyle.NEUTRAL


static func primary_color(persona_id: StringName) -> Color:
	match persona_id:
		DEEP_NINJA:
			return Color("b51f3f")
		LEGENDARY_MASTER:
			return Color("35cdea")
		ROCK_VIGILANTE:
			return Color("d7e83f")
		_:
			return Color("dceaf2")


static func accent_color(persona_id: StringName) -> Color:
	match persona_id:
		DEEP_NINJA:
			return Color("ff3f83")
		LEGENDARY_MASTER:
			return Color("e8fbff")
		ROCK_VIGILANTE:
			return Color("ff9d32")
		_:
			return Color("ffffff")


static func shadow_color(persona_id: StringName) -> Color:
	match persona_id:
		DEEP_NINJA:
			return Color("260711")
		LEGENDARY_MASTER:
			return Color("083e53")
		ROCK_VIGILANTE:
			return Color("332a08")
		_:
			return Color("26333c")


static func afterimage_color(persona_id: StringName, reduced_flashes: bool) -> Color:
	var color := primary_color(persona_id).lerp(shadow_color(persona_id), 0.28)
	color.a = 0.28 if reduced_flashes else 0.43
	return color


static func effect_strength(effect_kind: StringName) -> float:
	match effect_kind:
		&"ninja_chase":
			return 1.32
		&"ninja_borrowed_step":
			return 1.48
		&"ninja_takeover":
			return 2.0
		_:
			return 1.0


static func display_name(persona_id: StringName) -> String:
	match persona_id:
		DEEP_NINJA:
			return "深渊忍者：裂光"
		LEGENDARY_MASTER:
			return "传奇宗师：校准光"
		ROCK_VIGILANTE:
			return "摇滚奇侠：波形光"
		_:
			return "未选择人格：冷白光"
