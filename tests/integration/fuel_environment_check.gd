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
	var barrel: FuelBarrel = load("res://scenes/environment/fuel_barrel.tscn").instantiate()
	barrel.position = Vector2(300,180)
	room.add_child(barrel)
	var target := actor_at(Vector2(330,180))
	var player_target := actor_at(Vector2(280,180),null,CombatFaction.Id.PLAYER)
	var covered := actor_at(Vector2(300,230))
	var far := actor_at(Vector2(500,180))
	var other_room := Node2D.new()
	other_room.add_to_group("combat_rooms")
	root.add_child(other_room)
	var isolated := actor_at(Vector2(330,180),other_room)
	var wall := StaticBody2D.new()
	wall.position = Vector2(300,210)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(50,8)
	collider.shape = shape
	wall.add_child(collider)
	room.add_child(wall)
	await physics_frame
	await physics_frame
	barrel.receive_hit(DamagePacket.new())
	barrel.receive_hit(DamagePacket.new())
	await process_frame
	check(barrel.broken and is_instance_valid(barrel.patch),"melee hit triggers one bomb explosion")
	check(get_nodes_in_group("fuel_patches").size() == 1,"repeated hits cannot duplicate oil")
	check(barrel.patch.burning and barrel.patch.explosion_count == 1,"any valid attack immediately explodes bomb")
	check(target.get_node("HealthComponent").current_health == 9 and player_target.get_node("HealthComponent").current_health == 9,"bomb blast damages both factions once")
	barrel.patch.queue_free()
	await process_frame
	for actor in [target,player_target,covered,far,isolated]:
		actor.get_node("HealthComponent").set_current_health(10)
		actor.get_node("StatusComponent").clear_all()
	# Oil status remains independently testable without requiring a weapon or a two-step bomb.
	var patch := FuelPatch.new()
	patch.position = Vector2(300,180)
	room.add_child(patch)
	await create_timer(0.25).timeout
	check(target.get_node("StatusComponent").has_status(&"oiled") and player_target.get_node("StatusComponent").has_status(&"oiled"),"oil affects player and enemy")
	check(target.get_node("HealthComponent").current_health == 10,"oil alone does no damage")
	check(not covered.get_node("StatusComponent").has_status(&"oiled") and not far.get_node("StatusComponent").has_status(&"oiled") and not isolated.get_node("StatusComponent").has_status(&"oiled"),"oil respects wall radius and room")
	var fire := DamagePacket.new()
	fire.damage_type = &"fire"
	paused = true
	patch.receive_hit(fire)
	check(not patch.burning,"paused oil cannot ignite")
	var time_left := patch.remaining
	await create_timer(0.25,true).timeout
	check(is_equal_approx(time_left,patch.remaining),"patch expiry pauses")
	paused = false
	patch.receive_hit(fire)
	patch.receive_hit(fire)
	await process_frame
	check(patch.burning and patch.explosion_count == 1,"one ignition creates one explosion")
	check(target.get_node("HealthComponent").current_health == 9 and player_target.get_node("HealthComponent").current_health == 9,"explosion damages player and enemy")
	check(target.get_node("StatusComponent").has_status(&"burning"),"explosion ignites existing oil")
	check(covered.get_node("HealthComponent").current_health == 10 and far.get_node("HealthComponent").current_health == 10 and isolated.get_node("HealthComponent").current_health == 10,"explosion respects cover radius scope")
	await create_timer(1.1).timeout
	check(target.get_node("HealthComponent").current_health == 7,"fire ground and actor burn each tick once")
	await create_timer(3.1).timeout
	check(not is_instance_valid(patch),"fire patch expires and frees collider")
	var direct: FuelBarrel = load("res://scenes/environment/fuel_barrel.tscn").instantiate()
	direct.position = Vector2(900,900)
	room.add_child(direct)
	direct.receive_hit(fire)
	await process_frame
	await process_frame
	check(direct.patch.burning and direct.patch.explosion_count == 1,"fire directly hitting barrel explodes once")
	var dry := FuelPatch.new()
	dry.position = Vector2(1000,1000)
	dry.remaining = 0.1
	room.add_child(dry)
	await create_timer(0.2).timeout
	check(not is_instance_valid(dry),"unused oil expires with its collider")
	# Real weapon -> projectile -> barrel and oil ignition paths.
	var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	player.position = Vector2(80,300)
	room.add_child(player)
	player.set_physics_process(false)
	var second: FuelBarrel = load("res://scenes/environment/fuel_barrel.tscn").instantiate()
	second.position = Vector2(200,300)
	room.add_child(second)
	await physics_frame
	await physics_frame
	player.weapons.set_equipped_weapon(load("res://resources/weapons/service_pistol.tres"))
	player.weapons.try_attack(Vector2(100,300),Vector2.RIGHT,player)
	await create_timer(0.35).timeout
	check(second.broken and is_instance_valid(second.patch) and second.patch.burning,"real kinetic shot directly explodes bomb")
	var explosion := second.patch.get_node_or_null("ExplosionAnimation") as FuelExplosionEffect
	check(explosion != null, "real box explosion starts its multi-stage animation")
	var authored := explosion.get_node("AuthoredExplosion") as AnimatedSprite2D
	check(authored.sprite_frames.get_frame_count("explode") == 8, "explosion plays all eight authored art frames")
	var debris := second.get_node("BombDebris") as BombDebrisEffect
	check(debris.get_child_count() == 8, "crate releases eight distinct textured material fragments")
	var effect_time := explosion.elapsed
	paused = true
	await create_timer(0.08, true).timeout
	check(explosion.elapsed == effect_time, "pause freezes explosion animation")
	paused = false
	var fire_weapon: WeaponComponentData = load("res://resources/weapons/service_pistol.tres").duplicate()
	fire_weapon.damage_type = &"fire"
	player.weapons.set_equipped_weapon(fire_weapon)
	player.weapons.try_attack(Vector2(100,300),Vector2.RIGHT,player)
	await create_timer(0.3).timeout
	check(second.patch.burning and second.patch.explosion_count == 1,"further fire shot cannot explode spent bomb twice")
	check(second.patch.find_children("ExplosionAnimation*", "", true, false).size() == 1, "repeated hits do not duplicate explosion animation")
	await create_timer(0.9).timeout
	check(not is_instance_valid(explosion), "short explosion animation cleans up while burning patch persists")
	check(debris.settled_count == 8 and debris.get_children().all(func(piece: Node2D) -> bool: return piece.z_index == -1), "all textured fragments settle on the ground and persist below actors")
	room.queue_free()
	other_room.queue_free()
	await process_frame
	print("Fuel checks: ",checks,"; failures: ",failures)
	quit(0 if failures == 0 else 1)
