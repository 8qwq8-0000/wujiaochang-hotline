class_name CombatFaction
extends RefCounted

enum Id {
	NEUTRAL,
	PLAYER,
	ENEMY,
	ENVIRONMENT,
}


static func damage_multiplier(source: Id, target: Id, reflected: bool = false) -> float:
	if target == Id.NEUTRAL:
		return 1.0
	if source == Id.PLAYER and target == Id.PLAYER:
		return 0.0
	if source == Id.ENEMY and target == Id.ENEMY:
		return 1.0 if reflected else 0.6
	return 1.0
