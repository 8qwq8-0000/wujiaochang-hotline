extends SceneTree

## Exercise the shipped reactions-off configuration, including real projectiles.
class ReactionsOff extends GameSettingsController:
	func _ready() -> void:
		pass
	func are_elemental_reactions_enabled() -> bool:
		return false

var checks := 0
var failures := 0
var room: Node2D

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func target_at(point: Vector2, faction: CombatFaction.Id) -> Node2D:
	var actor := Node2D.new()
	actor.position = point
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.max_health = 10
	actor.add_child(health)
	var hurt := HurtBox2DComponent.new()
	hurt.name = "HurtBox"
	hurt.health_path = NodePath("../HealthComponent")
	hurt.faction = faction
	hurt.collision_layer = 16 if faction == CombatFaction.Id.ENEMY else 8
	hurt.monitoring = false
	actor.add_child(hurt)
	var statuses := StatusComponent.new()
	statuses.name = "StatusComponent"
	actor.add_child(statuses)
	room.add_child(actor)
	return actor

func capture(filename: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/art/validation/bomb_runtime_fix")
	root.get_texture().get_image().save_png("res://docs/art/validation/bomb_runtime_fix/" + filename)

func run() -> void:
	# Let the normal windowed settings loader finish before test setup.
	await process_frame
	await process_frame
	var original := root.get_node("GameSettings")
	# Headless normally forces reactions on; override that test-only shortcut.
	# Windowed runs use the unmodified shipped GameSettings instance.
	var settings: GameSettingsController = original
	if DisplayServer.get_name() == "headless":
		root.remove_child(original)
		settings = ReactionsOff.new()
		settings.name = "GameSettings"
		root.add_child(settings)
	check(not settings.are_elemental_reactions_enabled(), "exercise reactions-off path in both display modes")
	room = Node2D.new()
	room.add_to_group("combat_rooms")
	root.add_child(room)
	current_scene = room
	var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	player.position = Vector2(160, 240)
	room.add_child(player)
	player.set_physics_process(false)
	var enemy := target_at(Vector2(310, 240), CombatFaction.Id.ENEMY)
	var friendly := target_at(Vector2(280, 280), CombatFaction.Id.PLAYER)
	var barrel: FuelBarrel = load("res://scenes/environment/fuel_barrel.tscn").instantiate()
	barrel.position = Vector2(280, 240)
	room.add_child(barrel)
	await physics_frame
	await physics_frame
	player.weapons.set_equipped_weapon(load("res://resources/weapons/service_pistol.tres"))
	player.weapons.try_attack(Vector2(180, 240), Vector2.RIGHT, player)
	await create_timer(0.35).timeout
	check(barrel.broken, "real pistol shot reaches bomb")
	check(is_instance_valid(barrel.patch), "shot bomb produces its explosion instead of only disappearing")
	if is_instance_valid(barrel.patch):
		check(barrel.patch.burning and barrel.patch.explosion_count == 1, "bomb ignites and explodes once with reactions off")
		check(enemy.get_node("HealthComponent").current_health == 9, "blast damages nearby enemy with reactions off")
		check(friendly.get_node("HealthComponent").current_health == 9, "blast damages nearby player faction with reactions off")
		check(barrel.patch.has_node("ExplosionAnimation/AuthoredExplosion"), "authored explosion animation is visible")
		check(barrel.has_node("BombDebris"), "bomb produces material fragments")
		await capture("bomb_explosion.png")
		barrel.receive_hit(DamagePacket.new())
		await process_frame
		check(barrel.patch.explosion_count == 1, "repeated hits do not duplicate blast")
		await create_timer(0.9).timeout
		check(not barrel.patch.has_node("ExplosionAnimation"), "short explosion cleans up")
		check(barrel.get_node("BombDebris").settled_count == 8, "eight fragments settle after explosion")
		check(enemy.get_node("HealthComponent").current_health == 8, "lingering bomb fire continues damaging after the blast")
		await capture("bomb_debris.png")
	# Fixing bombs must not turn deferred oil reactions back on globally.
	var oil := FuelPatch.new()
	oil.position = Vector2(500, 300)
	room.add_child(oil)
	var fire := DamagePacket.new()
	fire.damage_type = &"fire"
	oil.receive_hit(fire)
	await process_frame
	check(not oil.burning and oil.explosion_count == 0, "ordinary oil ignition still respects disabled reactions")
	room.queue_free()
	await process_frame
	if settings != original:
		root.remove_child(settings)
		settings.free()
		root.add_child(original)
	print("Bomb runtime checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
