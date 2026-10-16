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
	root.get_node("CombatEvents").electric_arc_requested.connect(func(a: Vector2, b: Vector2, _room: Node) -> void: arcs.append([a,b]))
	var actors: Array[Node2D] = []
	for index in 5:
		actors.append(actor_at(Vector2(100 + index * 60, 100)))
	await physics_frame
	hit(actors[0], &"electric", ["conductive"])
	check(arcs.is_empty() and actors[0].get_node("StatusComponent").has_status(&"conductive"), "same hit applies conductivity without self-triggering a reaction")
	for index in range(1, 5):
		hit(actors[index], &"kinetic", ["conductive"])
	hit(actors[0], &"electric")
	check(arcs.size() == 3, "conductive electric hit has at most three secondary hops")
	for index in range(4):
		check(not actors[index].get_node("StatusComponent").has_status(&"conductive"), "each hit consumes conductivity once")
	check(actors[4].get_node("StatusComponent").has_status(&"conductive"), "hop limit leaves further conductive actors untouched")
	check(actors[0].get_node("HealthComponent").current_health == 8 and actors[3].get_node("HealthComponent").current_health == 8, "real reaction damage uses hurtbox and health")
	var count := arcs.size()
	hit(actors[0], &"electric")
	check(arcs.size() == count, "repeated electric hit does not reuse consumed conductivity")
	var statuses: StatusComponent = actors[4].get_node("StatusComponent")
	statuses._physics_process(7)
	check(not statuses.has_status(&"conductive"), "conductivity expires")
	statuses.set_immunity(&"electric", true)
	hit(actors[4], &"kinetic", ["conductive"])
	check(not statuses.has_status(&"conductive"), "electric immunity rejects conductive status")
	statuses.set_immunity(&"electric", false)
	actors[4].get_node("HurtBox").set_invulnerable(1)
	hit(actors[4], &"kinetic", ["conductive"])
	check(not statuses.has_status(&"conductive"), "invulnerable hit applies no status")
	actors[4].get_node("HurtBox").clear_invulnerability()
	var guard := GuardComponent.new()
	actors[4].add_child(guard)
	guard.set_physics_process(false)
	guard.state = GuardComponent.State.PERFECT
	guard.guard_direction = Vector2.LEFT
	actors[4].get_node("HurtBox").guard = guard
	hit(actors[4], &"kinetic", ["conductive"])
	check(not statuses.has_status(&"conductive"), "blocked hit applies no status")
	guard.state = GuardComponent.State.IDLE
	# Wall and scope isolation are checked using real physics queries.
	for actor in actors:
		actor.get_node("StatusComponent").clear_all()
	actors[0].position = Vector2(100,100)
	actors[1].position = Vector2(160,100)
	var wall := StaticBody2D.new()
	wall.position = Vector2(130,100)
	var wall_collider := CollisionShape2D.new()
	var wall_shape := RectangleShape2D.new()
	wall_shape.size = Vector2(10,80)
	wall_collider.shape = wall_shape
	wall.add_child(wall_collider)
	room.add_child(wall)
	await physics_frame
	await physics_frame
	hit(actors[0], &"kinetic", ["conductive"])
	hit(actors[1], &"kinetic", ["conductive"])
	count = arcs.size()
	hit(actors[0], &"electric")
	check(arcs.size() == count and actors[1].get_node("StatusComponent").has_status(&"conductive"), "walls block arc propagation without consuming target status")
	wall.queue_free()
	actors[1].get_node("StatusComponent").clear_all()
	var other_room := Node2D.new()
	other_room.add_to_group("combat_rooms")
	root.add_child(other_room)
	var isolated := actor_at(Vector2(120,100),other_room)
	isolated.get_node("StatusComponent").add_status(&"conductive",6,["negative","electric"])
	await physics_frame
	await physics_frame
	hit(actors[0], &"kinetic", ["conductive"])
	hit(actors[0], &"electric")
	check(arcs.size() == count and isolated.get_node("HealthComponent").current_health == 10, "arcs cannot cross combat-room containers")
	var friendly := actor_at(Vector2(120,100),room,CombatFaction.Id.PLAYER)
	friendly.get_node("StatusComponent").add_status(&"conductive",6,["negative","electric"])
	hit(actors[0], &"kinetic", ["conductive"])
	hit(actors[0], &"electric")
	check(arcs.size() == count and friendly.get_node("HealthComponent").current_health == 10, "player-sourced arcs preserve player friendly-fire immunity")
	# A real weapon must carry its resource tags through the projectile collision.
	var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	player.position = Vector2(40,240)
	room.add_child(player)
	player.set_physics_process(false)
	var target := actor_at(Vector2(300,240))
	var weapon: WeaponComponentData = load("res://resources/weapons/service_pistol.tres").duplicate()
	weapon.status_tags = ["conductive"]
	weapon.damage_type = &"electric"
	player.weapons.set_equipped_weapon(weapon)
	await physics_frame
	check(player.weapons.try_attack(Vector2(260,240),Vector2.RIGHT,player), "tagged resource fires using actual weapon controller")
	for frame in 20:
		await physics_frame
		if target.get_node("StatusComponent").has_status(&"conductive"):
			break
	check(target.get_node("StatusComponent").has_status(&"conductive"), "projectile collision transmits damage type and status tags")
	paused = true
	var before: float = target.get_node("StatusComponent").remaining_seconds(&"conductive")
	await create_timer(0.05,true).timeout
	check(is_equal_approx(before,target.get_node("StatusComponent").remaining_seconds(&"conductive")), "pause stops status expiry")
	paused = false
	room.queue_free()
	other_room.queue_free()
	await process_frame
	print("Status reaction checks: ",checks,"; failures: ",failures)
	quit(0 if failures == 0 else 1)
