extends SceneTree
var failures := 0
var checks := 0
var room: Node2D
var arcs: Array = []
func _initialize() -> void:
	call_deferred("run_checks")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func actor_at(position: Vector2, parent: Node = null, faction: CombatFaction.Id = CombatFaction.Id.ENEMY) -> Node2D:
	var actor := Node2D.new()
	actor.position = position
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = 10
	actor.add_child(health)
	var hurt := HurtBox2DComponent.new()
	hurt.name = "HurtBox"
	hurt.health_path = NodePath("../HealthComponent")
	hurt.faction = faction
	hurt.collision_layer = 16 if faction == CombatFaction.Id.ENEMY else 8
	hurt.collision_mask = 0
	hurt.monitoring = false
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 10
	collider.shape = shape
	hurt.add_child(collider)
	actor.add_child(hurt)
	var statuses := StatusComponent.new()
	statuses.name = "StatusComponent"
	actor.add_child(statuses)
	(parent if parent != null else room).add_child(actor)
	return actor
func hit(actor: Node2D, kind: StringName, tags: PackedStringArray = []) -> DamageResult:
	var packet := DamagePacket.new()
	packet.base_damage = 1
	packet.source_faction = CombatFaction.Id.PLAYER
	packet.damage_type = kind
	packet.status_tags = tags
	packet.source_position = actor.global_position - Vector2(30, 0)
	return actor.get_node("HurtBox").receive_hit(packet)
class TestArea extends Node2D:
	signal room_cleared
	var cleared := false
	func _enter_tree() -> void:
		add_to_group("environment_areas")
	func contains_world_point(point: Vector2) -> bool:
		return Rect2(0,0,640,360).has_point(to_local(point))
func run_checks() -> void:
	var floor := Node2D.new()
	floor.add_to_group("combat_rooms")
	root.add_child(floor)
	current_scene = floor
	var area := TestArea.new()
	floor.add_child(area)
	room = area
	var other_area := TestArea.new()
	other_area.position = Vector2(680,0)
	floor.add_child(other_area)
	var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	player.position = Vector2(754,180)
	floor.add_child(player)
	player.set_physics_process(false)
	check(EnvironmentArea.for_actor(player) == other_area,"floor-level player belongs to physical combat area")
	player.position = Vector2(100,145)
	check(EnvironmentArea.for_actor(player) == area,"moving player updates environment area")
	var targets: Array[Node2D] = []
	for index in 5:
		var target := actor_at(Vector2(120+index*65,100))
		target.get_node("StatusComponent").add_status(&"conductive",6,["negative","electric"])
		targets.append(target)
	var fresh := actor_at(Vector2(75,100))
	var isolated := actor_at(Vector2(120,100),other_area)
	isolated.get_node("StatusComponent").add_status(&"conductive",6,["negative","electric"])
	var box: PowerBox = load("res://scenes/environment/power_box.tscn").instantiate()
	box.position = Vector2(100,100)
	area.add_child(box)
	root.get_node("CombatEvents").electric_arc_requested.connect(func(_a: Vector2,_b: Vector2,_r: Node) -> void: arcs.append(true))
	await physics_frame
	await physics_frame
	box.receive_hit(DamagePacket.new())
	await process_frame
	await process_frame
	check(arcs.size() == 3,"one box event has a shared three-hop budget")
	for index in 4:
		check(targets[index].get_node("HealthComponent").current_health == 9,"overlapping blast and arcs damage each target once")
	check(targets[4].get_node("HealthComponent").current_health == 10,"global hop budget stops farther chain")
	check(fresh.get_node("HealthComponent").current_health == 9 and fresh.get_node("StatusComponent").has_status(&"conductive"),"newly conductive target cannot trigger in same discharge")
	check(player.health.current_health == 2 and player.statuses.has_status(&"conductive"),"actual floor-level player receives scoped environment shock")
	check(isolated.get_node("HealthComponent").current_health == 10 and isolated.get_node("StatusComponent").has_status(&"conductive"),"same floor different area is isolated despite nearby actor world position")
	check(not targets[0].get_node("StatusComponent").has_status(&"conductive"),"consumed origin status is not re-added by same packet")
	player.hurt_box.clear_invulnerability()
	player.health.set_current_health(3)
	var claim: PowerBox = load("res://scenes/environment/power_box.tscn").instantiate()
	claim.position = Vector2(100,130)
	area.add_child(claim)
	player.get_node("RoomBuffComponent").changed.connect(func(_id: StringName) -> void: claim.receive_hit(DamagePacket.new()),CONNECT_ONE_SHOT)
	claim.interact(player)
	await process_frame
	check(claim.state == PowerBox.State.CLAIMED and claim.discharge_count == 0,"buff callback cannot race claim into discharge")
	other_area.room_cleared.emit()
	check(not player.get_node("RoomBuffComponent").active_buff.is_empty(),"another area's clear does not expire current buff")
	area.cleared = true
	area.room_cleared.emit()
	check(player.get_node("RoomBuffComponent").active_buff.is_empty(),"source-area clear restores modifiers")
	check(not player.get_node("RoomBuffComponent").apply_buff(&"cooling",area),"cleared area rejects late buff")
	floor.queue_free()
	await process_frame
	var actual: Node2D = load("res://scenes/levels/floors/combat_prototype.tscn").instantiate()
	actual.get_node("FloorAssembler").room_count = 2
	root.add_child(actual)
	current_scene = actual
	await process_frame
	var generated: Array = actual.get_node("FloorAssembler").generated_rooms
	check(generated.size() == 2,"actual floor generated two areas")
	for generated_area in generated:
		var boxes := 0
		for child in generated_area.get_children():
			if child is PowerBox:
				boxes += 1
		check(boxes == 1,"actual generation has exactly one power box per area")
	actual.queue_free()
	await process_frame
	print("Environment electric checks: ",checks,"; failures: ",failures)
	quit(0 if failures == 0 else 1)
