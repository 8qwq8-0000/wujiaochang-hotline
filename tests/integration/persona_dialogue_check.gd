extends SceneTree

var checks := 0
var failures := 0
var emitted: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func run() -> void:
	var room := Node2D.new()
	root.add_child(room)
	current_scene = room
	var player := load("res://scenes/actors/player/player.tscn").instantiate() as PlayerController
	room.add_child(player)
	var dialogue := PersonaDialogueController.new()
	room.add_child(dialogue)
	dialogue.set_process(false)
	dialogue.line_requested.connect(func(text: String, priority: int, persona_id: StringName, policy: int) -> void:
		emitted.append({"text": text, "priority": priority, "persona_id": persona_id, "policy": policy})
	)
	dialogue.bind_player(player)
	await process_frame
	check(dialogue.get("_lines").size() == 48, "runtime loads all 48 authored dialogue rows")
	dialogue.get("_lines").clear()
	dialogue._load_imported_table()
	check(dialogue.get("_lines").size() == 48, "export-safe imported resources retain all dialogue rows")
	var events := {}
	for entry in dialogue.get("_lines"):
		events[String(entry.event)] = true
	check(events.size() == 12 and events.has("weapon_overheated") and not events.has("low_ammo"), "dialogue table exposes all confirmed events and replaces unreachable ammo event")

	player.talent_core.set_persona_level(TalentCoreController.LEGENDARY_MASTER, 1)
	var testing := dialogue._select_line(&"low_health", TalentCoreController.LEGENDARY_MASTER)
	check(String(testing.text) == "先脱离。活着才能验证下一步。", "testing relationship uses its baseline low-health line")
	player.talent_core.advance_relationship(TalentCoreController.LEGENDARY_MASTER)
	var synced := dialogue._select_line(&"low_health", TalentCoreController.LEGENDARY_MASTER)
	check(String(synced.text) == "照之前的路径退，我替你看右侧。", "synced relationship picks the higher eligible line")
	player.talent_core.advance_relationship(TalentCoreController.LEGENDARY_MASTER)
	var accomplice := dialogue._select_line(&"low_health", TalentCoreController.LEGENDARY_MASTER)
	check(String(accomplice.text) == "先活下来。理由之后再讲。", "accomplice relationship picks its dedicated line")
	var fallback := dialogue._select_line(&"enemy_spotted", TalentCoreController.LEGENDARY_MASTER)
	check(String(fallback.text) == "注意它的左侧。装甲重量改变了起手。", "missing high-bond variant falls back to the best eligible baseline")

	emitted.clear()
	check(dialogue._try_event(&"damaged"), "first reaction event is emitted")
	check(not dialogue._try_event(&"perfect_block"), "reaction cooldown suppresses a second reaction")
	check(emitted.size() == 1 and emitted[0].priority == CombatCommsController.Priority.HIGH, "reaction dialogue uses high presentation priority")
	dialogue.set("_cooldowns", {})
	check(dialogue._try_event(&"low_health") and dialogue._try_event(&"boss"), "critical state events bypass shared cooldown")
	check(emitted[-1].priority == CombatCommsController.Priority.CRITICAL, "critical dialogue can interrupt lower-priority chatter")

	player.talent_core.set_persona_level(TalentCoreController.DEEP_NINJA, 1)
	dialogue.set("_active_persona", TalentCoreController.LEGENDARY_MASTER)
	dialogue.set("_persona_before_switch", TalentCoreController.LEGENDARY_MASTER)
	dialogue.set("_known_levels", {String(TalentCoreController.DEEP_NINJA): 0})
	dialogue._on_persona_changed(TalentCoreController.DEEP_NINJA)
	dialogue._on_persona_consumed(TalentCoreController.DEEP_NINJA, 1)
	var scripted: Array = dialogue.get("_deferred_scripted")
	check(scripted.size() == 2 and scripted[0].persona_id == TalentCoreController.LEGENDARY_MASTER and scripted[1].persona_id == TalentCoreController.DEEP_NINJA, "persona switch queues outgoing speaker before incoming speaker")

	room.queue_free()
	await process_frame
	print("Persona dialogue checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
