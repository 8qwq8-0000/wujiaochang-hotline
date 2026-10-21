extends SceneTree

var failures := 0
var checks := 0

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
	var player: PlayerController = load("res://scenes/actors/player/player.tscn").instantiate()
	room.add_child(player)
	player.set_physics_process(false)
	var hud = load("res://scenes/ui/combat_hud.tscn").instantiate()
	room.add_child(hud)
	hud.set_process(false)
	hud._process(0.0)
	check(hud._health_meter.segments == player.health.max_health, "one segment per health point")
	check(hud._health_meter.segments == 3, "three starting health segments")
	player.health.set_current_health(2)
	hud._process(0.0)
	check(hud._health_meter.value == 2 and hud._health_meter.segments == 3, "damage empties one segment")
	player.circuit_breaker.set_equipped(true)
	player.circuit_breaker.reset_for_new_run()
	player.hurt_box.clear_invulnerability()
	var packet := DamagePacket.new()
	packet.base_damage = 99
	packet.source_faction = CombatFaction.Id.ENEMY
	player.receive_damage(packet)
	hud._process(0.0)
	check(player.circuit_breaker.circuit_breaker_used, "fatal damage triggers actual core")
	check(hud._health_meter.caption == "保护中", "health caption marks protection")
	check(hud._health_meter.meter_color == CyberUITheme.WARNING, "protected health is gold")
	check(hud._circuit_value.text == "断路保险触发 · 保护中", "explicit activation marker")
	player.hurt_box.clear_invulnerability()
	hud._process(0.0)
	check(hud._health_meter.caption == "耐久" and hud._circuit_value.text == "断路保险  已消耗", "protection expiry retains consumed status")
	check(hud._health_meter.meter_color == CyberUITheme.DANGER, "last health light takes precedence with the critical danger color")
	player.circuit_breaker.set_equipped(false)
	hud._process(0.0)
	check(hud._circuit_value.text == "断路保险  未装备", "unequipped core status")
	player.circuit_breaker.set_equipped(true)
	player.circuit_breaker.reset_for_new_run()
	player.health.configure_max_health(5)
	hud._process(0.0)
	check(hud._health_meter.segments == 5 and hud._circuit_value.text == "断路保险  就绪", "maximum health and reset update HUD")
	check(hud._health_meter.meter_color == CyberUITheme.PHOSPHOR, "resetting insurance restores green health")
	check(not hud._health_meter.show_numeric and not hud._health_meter.show_caption, "health lights stay icon-only")
	check(not hud._heat_meter.show_numeric and hud._heat_meter.segments == 10, "heat uses a numberless ten-segment strip")
	room.queue_free()
	await process_frame
	print("Health HUD checks: %d; failures: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)
