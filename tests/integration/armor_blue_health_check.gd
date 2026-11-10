extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func hit(player: PlayerController, damage: int = 1) -> DamageResult:
	player.hurt_box.clear_invulnerability()
	var packet := DamagePacket.new()
	packet.base_damage = damage
	packet.source_faction = CombatFaction.Id.ENEMY
	return player.hurt_box.receive_hit(packet)

func run_checks() -> void:
	for tier in [1, 2, 3]:
		var room := Node2D.new()
		root.add_child(room)
		current_scene = room
		var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
		room.add_child(player)
		player.set_physics_process(false)
		player.circuit_breaker.set_equipped(false)
		var defense := player.get_node("DefenseComponent") as DefenseComponent
		defense.set_physics_process(false)
		var hud = load("res://scenes/ui/combat_hud.tscn").instantiate()
		room.add_child(hud)
		hud.set_process(false)
		hud._process(0)
		check(not hud._armor_meter.visible, "no armor means no blue health")
		var energy_rail: TextureRect = hud._circuit_energy_rail
		check(not hud._top_left.has_node("DurabilityLine"), "no separate rail under the gems")
		var base_line_width := energy_rail.size.x
		var armor := ComponentRolls.create("armor", tier, RandomNumberGenerator.new())
		check(player.inventory.pickup("armor", armor) and player.inventory.equip(0), "equip armor tier %d" % tier)
		var capacity := 2 if tier == 3 else 1
		var cooldown := 12.0 if tier == 1 else 10.0
		hud._process(0)
		check(defense.capacity() == capacity and defense.charges() == capacity and defense.cooldown_seconds(armor) == cooldown, "tier controls actual capacity and recovery")
		check(hud._armor_meter.visible and hud._armor_meter.segments == capacity and hud._armor_meter.value == capacity, "HUD shows one blue block per shield point")
		var health_meter: SegmentMeter = hud._health_meter
		var armor_meter: SegmentMeter = hud._armor_meter
		var gem_stride := health_meter.texture_cell_size.x + health_meter.cell_gap
		check(armor_meter.position == health_meter.position + Vector2(gem_stride * health_meter.segments, 0.0), "armor gems line up directly after health gems")
		var armor_right := armor_meter.position.x + gem_stride * capacity - armor_meter.cell_gap
		var line_end: float = hud._circuit_energy_bar.position.x + energy_rail.size.x
		check(is_equal_approx(line_end, armor_right), "overload bar reaches the last armor gem")
		check(armor_meter.texture_cell_size == health_meter.texture_cell_size and armor_meter.filled_texture == health_meter.filled_texture and armor_meter.empty_texture == health_meter.empty_texture and armor_meter.material is ShaderMaterial, "armor uses matching gem art with its own tint")
		var health := player.health.current_health
		for index in capacity:
			check(hit(player).absorbed_damage == 1 and player.health.current_health == health, "blue health absorbs before green health")
		hud._process(0)
		check(defense.charges() == 0 and hud._armor_meter.value == 0, "depleted armor dims all blue blocks")
		check(hud._circuit_energy_bar.position.x + energy_rail.size.x == line_end, "depleted armor keeps the full overload bar")
		check(hit(player).final_damage == 1 and player.health.current_health == health - 1, "green health is damaged after blue health is depleted")
		var snapshot := player.export_run_state()
		player.import_run_state(snapshot)
		check(defense.charges() == 0 and defense.remaining_seconds() == cooldown, "scene snapshot preserves depleted charges and cooldown")
		defense._physics_process(cooldown - 0.1)
		check(defense.charges() == 0, "blue health does not recover early")
		defense._physics_process(0.2)
		check(defense.charges() == 1, "one cooldown restores one blue health")
		hud._process(0)
		check(armor_meter.value == 1, "restoring armor relights one HUD gem")
		if tier == 3:
			check(is_equal_approx(defense.remaining_seconds(), cooldown - 0.1), "second charge retains its own recovery progress")
			var remaining := defense.remaining_seconds()
			check(hit(player).absorbed_damage == 1 and is_equal_approx(defense.remaining_seconds(), remaining), "using a recovered charge does not reset the running recovery")
			defense._physics_process(cooldown * 2)
			check(defense.charges() == 2 and defense.remaining_seconds() == 0, "both prototype armor charges recover")
			player.health.set_current_health(3)
			var heavy := hit(player, 3)
			check(heavy.absorbed_damage == 2 and heavy.final_damage == 1, "two blue health absorb two points of a heavy hit")
		check(player.inventory.unequip("defense"), "armor can be removed")
		hud._process(0)
		check(not armor_meter.visible and energy_rail.size.x == base_line_width, "removing armor restores the original overload bar width")
		room.queue_free()
		await process_frame
	print("Armor blue-health checks: ", checks, "; failures: ", failures)
	quit(0 if failures == 0 else 1)
