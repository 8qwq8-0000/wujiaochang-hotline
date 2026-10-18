extends Node

# Ordinary deaths only mark lifecycle completion. FloorAssembler owns the single
# floor guarantee; future boss rewards must use their own one-shot reward source.
func _ready() -> void:
	get_node("/root/CombatEvents").entity_defeated.connect(_on_defeated)

func _on_defeated(entity: Node) -> void:
	if not entity is EnemyController or entity.has_meta("component_loot_emitted"):
		return
	entity.set_meta("component_loot_emitted", true)
