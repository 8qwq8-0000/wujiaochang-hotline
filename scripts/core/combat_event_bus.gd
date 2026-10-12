extends Node

## 战斗表现层只监听这里，不直接依赖武器、敌人或玩家实现。
signal damage_resolved(result: DamageResult)
signal perfect_guarded(result: DamageResult)
signal entity_defeated(entity: Node)
signal room_cleared(room: Node)
signal floor_cleared
signal combat_message_requested(text: String, color: Color)


func publish_damage(result: DamageResult) -> void:
	damage_resolved.emit(result)
	if result.outcome == DamageResult.Outcome.PERFECT_BLOCKED or result.outcome == DamageResult.Outcome.REFLECTED:
		perfect_guarded.emit(result)


func publish_defeat(entity: Node) -> void:
	entity_defeated.emit(entity)


func publish_room_cleared(room: Node) -> void:
	room_cleared.emit(room)


func publish_floor_cleared() -> void:
	floor_cleared.emit()


func publish_message(text: String, color: Color = Color.WHITE) -> void:
	combat_message_requested.emit(text, color)
