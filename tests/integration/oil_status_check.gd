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
func run_checks() -> void:
	room = Node2D.new()
	room.add_to_group("combat_rooms")
	root.add_child(room)
	current_scene = room
	var target := actor_at(Vector2(300,100))
	var health: HealthComponent = target.get_node("HealthComponent")
	var status: StatusComponent = target.get_node("StatusComponent")
	hit(target,&"kinetic",["oiled"])
	status.set_physics_process(false)
	status._physics_process(2)
	hit(target,&"kinetic",["oiled"])
	check(is_equal_approx(status.remaining_seconds(&"oiled"),6),"repeated oil refreshes six seconds without stacking")
	status.clear_all()
	health.set_current_health(10)
	status.set_physics_process(true)
	hit(target,&"fire",["oiled"])
	check(status.has_status(&"oiled") and not status.has_status(&"burning"),"same hit cannot ignite newly applied oil")
	hit(target,&"fire")
	check(not status.has_status(&"oiled") and status.has_status(&"burning"),"fire consumes existing oil and applies burning")
	check(health.current_health == 8,"ignition does not invent immediate extra damage")
	await create_timer(1.1).timeout
	check(health.current_health == 7,"first actual physics burn tick deals one damage")
	var left := status.remaining_seconds(&"burning")
	paused = true
	await create_timer(1.1,true).timeout
	check(health.current_health == 7 and is_equal_approx(status.remaining_seconds(&"burning"),left),"pause stops burn timer and damage")
	paused = false
	await create_timer(2.05).timeout
	check(health.current_health == 5 and not status.has_status(&"burning"),"three total ticks then expiry")
	hit(target,&"kinetic",["oiled"])
	status.set_immunity(&"fire",true)
	hit(target,&"fire")
	check(not status.has_status(&"burning"),"fire status immunity blocks burning")
	status.set_immunity(&"fire",false)
	target.get_node("HurtBox").set_invulnerable(1)
	hit(target,&"fire")
	check(status.has_status(&"oiled") and not status.has_status(&"burning"),"invulnerability prevents reaction")
	target.get_node("HurtBox").clear_invulnerability()
	hit(target,&"fire")
	status.clear_all()
	var hp := health.current_health
	await create_timer(1.1).timeout
	check(health.current_health == hp,"cleared burning never keeps ticking")
	# Refreshing an already burning target must retain one tick stream.
	health.set_current_health(10)
	status.add_status(&"oiled",6,["negative","oil"])
	var fire := DamagePacket.new()
	fire.source_faction = CombatFaction.Id.ENVIRONMENT
	fire.damage_type = &"fire"
	status.ignite(fire)
	status.add_status(&"oiled",6,["negative","oil"])
	status.ignite(fire)
	await create_timer(1.1).timeout
	check(health.current_health == 9,"repeated ignition refreshes rather than stacking burn damage")
	status.clear_all()
	# Actual insurance interception clears an active burn during a lethal tick.
	var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	room.add_child(player)
	player.set_physics_process(false)
	player.health.set_current_health(1)
	player.statuses.add_status(&"oiled",6,["negative","oil"])
	var incoming := DamagePacket.new()
	incoming.source_faction = CombatFaction.Id.ENVIRONMENT
	incoming.damage_type = &"fire"
	player.statuses.ignite(incoming)
	await create_timer(1.15).timeout
	check(player.health.current_health == 1 and not player.health.is_dead() and not player.statuses.has_status(&"burning"),"insurance clears burn inside fatal tick")
	await create_timer(1.1).timeout
	check(player.health.current_health == 1,"insurance leaves no residual burn damage")
	room.queue_free()
	await process_frame
	print("Oil status checks: ",checks,"; failures: ",failures)
	quit(0 if failures == 0 else 1)
