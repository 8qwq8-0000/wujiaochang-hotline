extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var room := Node2D.new()
	room.add_to_group("combat_rooms")
	root.add_child(room)
	current_scene = room
	var player := Node2D.new()
	room.add_child(player)
	var scene := load("res://scenes/combat/gravity_wave_orb.tscn") as PackedScene
	var item := ComponentRolls.create("gravity_wave", 1, RandomNumberGenerator.new())
	assert(item != null)
	var weapon := ComponentRolls.weapon(item)
	assert(weapon != null and weapon.id == &"gravity_wave" and weapon.trigger_mode == WeaponComponentData.TriggerMode.CHARGE)
	for tier in [1, 2, 3]:
		var tier_item := ComponentRolls.create("gravity_wave", tier, RandomNumberGenerator.new())
		assert(ComponentRolls.quality(tier_item) == tier)
		assert(ComponentRolls.weapon(tier_item).id == &"gravity_wave")
	assert((load("res://assets/art/weapons/gravity_wave/weapon.png") as Texture2D).get_width() <= 256)
	for path in ["blue", "red", "purple"]:
		assert((load("res://assets/art/projectiles/gravity_wave/%s.png" % path) as Texture2D).get_width() <= 256)
	var blue := scene.instantiate() as GravityWaveOrb
	room.add_child(blue)
	blue.setup_wave(player, Vector2.RIGHT, 4.9)
	assert(blue.kind == GravityWaveOrb.BLUE)
	assert(blue.radius > 47.0 and blue.radius < 48.0)
	assert(blue.lifetime == 20.0)
	var hostile := (load("res://scenes/combat/projectile.tscn") as PackedScene).instantiate() as CombatProjectile
	room.add_child(hostile)
	hostile.setup(player, CombatFaction.Id.ENEMY, Vector2.LEFT, 1, 100.0)
	hostile.global_position = blue.global_position
	blue._touch_projectiles()
	assert(is_equal_approx(blue.lifetime, 25.0))
	assert(hostile.is_queued_for_deletion())
	var red := scene.instantiate() as GravityWaveOrb
	room.add_child(red)
	red.setup_wave(player, Vector2.RIGHT, 10.0)
	assert(red.kind == GravityWaveOrb.RED)
	assert(red.damage == 3)
	assert(red.lifetime == 10.0)
	red._check_fusion()
	assert(not blue.is_queued_for_deletion() and not red.is_queued_for_deletion())
	assert(not get_nodes_in_group("gravity_fusion_shockwaves").is_empty())
	var purple: GravityWaveOrb
	for orb in get_nodes_in_group("gravity_wave_orbs"):
		if orb is GravityWaveOrb and orb.kind == GravityWaveOrb.PURPLE:
			purple = orb
	assert(purple != null)
	assert(purple.damage == 4)
	assert(purple.blast_radius > 350.0)
	assert(purple.radius == 48.0)
	assert(purple.damage * 2 == 8)
	var fusion_position := purple.global_position
	purple._physics_process(GravityWaveOrb.PURPLE_GLIDE_SECONDS)
	assert(purple.global_position.distance_to(fusion_position + Vector2.DOWN * GravityWaveOrb.PURPLE_GLIDE_DISTANCE) < 0.01)
	var stopped_position := purple.global_position
	purple._physics_process(0.1)
	assert(purple.global_position.distance_to(stopped_position) < 0.01)
	print("gravity_wave_check: passed")
	quit(0)
