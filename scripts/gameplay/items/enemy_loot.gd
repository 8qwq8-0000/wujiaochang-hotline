extends Node

# Death is finalized before this event, including delayed self-destruct enemies.
func _ready() -> void:
	get_node("/root/CombatEvents").entity_defeated.connect(_on_defeated)

func _on_defeated(entity: Node) -> void:
	if not entity is EnemyController or entity.state != EnemyController.State.DEAD or entity.has_meta("component_loot_emitted"):
		return
	entity.set_meta("component_loot_emitted", true)
	var owner_node := entity.get_parent()
	while owner_node != null and not owner_node is CombatRoom:
		owner_node = owner_node.get_parent()
	var room := owner_node as CombatRoom
	if room == null:
		return
	var assembler := room.get_parent() as FloorAssembler
	if assembler != null:
		assembler.try_enemy_drop(entity, room, entity.global_position)
