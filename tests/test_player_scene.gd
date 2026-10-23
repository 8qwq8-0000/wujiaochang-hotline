@tool
extends McpTestSuite


func suite_name() -> String:
	return "player_scene"


func test_player_scene_has_required_components() -> void:
	var scene: PackedScene = load("res://scenes/actors/player/player.tscn")
	var player := track(scene.instantiate()) as PlayerController
	assert_true(player != null)
	assert_true(player.get_node_or_null("HealthComponent") is HealthComponent)
	assert_true(player.get_node_or_null("StatusComponent") is StatusComponent)
	assert_true(player.get_node_or_null("TalentCoreController") is TalentCoreController)
	assert_true(player.get_node_or_null("PersonaCombatController") is PersonaCombatController)
	assert_true(player.get_node_or_null("CircuitBreakerComponent") is CircuitBreakerComponent)
	assert_true(player.get_node_or_null("InteractionDetector") is InteractorComponent)
	assert_true(player.get_node_or_null("VisualRoot/BodyVisual") is AnimatedSprite2D)
	var wrist_socket := player.get_node_or_null("VisualRoot/WristSocket") as PlayerWristSocket
	assert_true(wrist_socket != null)
	assert_true(player.get_node_or_null("VisualRoot/WeaponPivot") is WeaponMount)
	assert_true(player.get_node_or_null("VFXSockets/Foot") is Marker2D)
	var sprite := player.get_node("VisualRoot/BodyVisual") as AnimatedSprite2D
	for animation in [&"idle", &"idle_gesture", &"walk_left", &"walk_right"]:
		assert_true(sprite.sprite_frames.has_animation(animation))
	for removed_idle in [&"idle_down", &"idle_up", &"idle_left", &"idle_right"]:
		assert_false(sprite.sprite_frames.has_animation(removed_idle))
	assert_eq(sprite.sprite_frames.get_frame_count(&"walk_down"), 6)
	assert_eq(sprite.sprite_frames.get_frame_count(&"walk_up"), 6)
	assert_eq(sprite.sprite_frames.get_frame_count(&"walk_left"), 6)
	assert_eq(sprite.sprite_frames.get_frame_count(&"walk_right"), 6)
	assert_eq(sprite.sprite_frames.get_frame_count(&"idle"), 2)
	assert_eq(sprite.sprite_frames.get_frame_count(&"idle_gesture"), 5)
	assert_true(sprite.sprite_frames.get_animation_loop(&"idle"))
	assert_false(sprite.sprite_frames.get_animation_loop(&"idle_gesture"))
	var idle_regions: Array[float] = []
	for frame_index in sprite.sprite_frames.get_frame_count(&"idle"):
		var frame_texture := sprite.sprite_frames.get_frame_texture(
			&"idle",
			frame_index
		) as AtlasTexture
		idle_regions.append(frame_texture.region.position.x)
	assert_eq(idle_regions, [0.0, 640.0])
	var idle_gesture_regions: Array[float] = []
	for frame_index in sprite.sprite_frames.get_frame_count(&"idle_gesture"):
		var frame_texture := sprite.sprite_frames.get_frame_texture(
			&"idle_gesture",
			frame_index
		) as AtlasTexture
		idle_gesture_regions.append(frame_texture.region.position.x)
	assert_eq(idle_gesture_regions, [128.0, 256.0, 384.0, 512.0, 640.0])
	var walk_down_regions: Array[float] = []
	for frame_index in sprite.sprite_frames.get_frame_count(&"walk_down"):
		var frame_texture := sprite.sprite_frames.get_frame_texture(
			&"walk_down",
			frame_index
		) as AtlasTexture
		walk_down_regions.append(frame_texture.region.position.x)
	assert_eq(walk_down_regions, [0.0, 128.0, 384.0, 256.0, 512.0, 640.0])
	assert_false(
		sprite.sprite_frames.get_frame_texture(&"walk_left", 0)
		== sprite.sprite_frames.get_frame_texture(&"walk_right", 0)
	)
	var walk_right_frame := sprite.sprite_frames.get_frame_texture(
		&"walk_right",
		0
	) as AtlasTexture
	assert_true(walk_right_frame.atlas.resource_path.ends_with("player_walk_right.png"))
	assert_true(sprite.scale.is_equal_approx(Vector2(0.25, 0.25)))
	var visuals := player.get_node("VisualRoot") as PlayerVisualController
	assert_eq(visuals._direction_name(Vector2.LEFT), "left")
	assert_eq(visuals._direction_name(Vector2.RIGHT), "right")
	for direction in ["down", "up", "left", "right"]:
		assert_eq(visuals._body_animation(direction, false), StringName("walk_" + direction))
	assert_eq(visuals._body_animation("right", true), &"walk_right")
	assert_false(sprite.flip_h)
	assert_true(visuals._weapon_draws_in_front("down"))
	assert_true(visuals._weapon_draws_in_front("right"))
	assert_false(visuals._weapon_draws_in_front("up"))
	assert_false(visuals._weapon_draws_in_front("left"))
	for animation in [
		&"idle", &"idle_gesture",
		&"walk_down", &"walk_up", &"walk_left", &"walk_right",
	]:
		assert_eq(
			wrist_socket.get_pose_frame_count(animation),
			sprite.sprite_frames.get_frame_count(animation),
			String(animation) + " wrist frames"
		)
	assert_true(wrist_socket.get_source_wrist(&"walk_right", 0).x > 64.0)


func test_default_player_config_uses_service_pistol_and_fixed_dash() -> void:
	var config: CombatPlayerConfig = load("res://resources/player/default_player_config.tres")
	assert_eq(config.max_health, 3)
	assert_true(is_equal_approx(config.damage_invulnerability_seconds, 0.18))
	assert_eq(config.default_weapon.id, &"service_pistol")
	assert_eq(config.default_weapon.heat_per_attack, 17.0)
	var dash: DashConfigData = load("res://resources/player/default_dash_config.tres")
	assert_eq(dash.walk_speed, 125.0)
	assert_eq(dash.dash_speed, 420.0)
	assert_false(config.debug_loadout_enabled)


func test_confirmed_weapon_heat_capacities_ignore_natural_cooling() -> void:
	var pistol: WeaponComponentData = load("res://resources/weapons/service_pistol.tres")
	var scattergun: WeaponComponentData = load("res://resources/weapons/scattergun.tres")
	var baton: WeaponComponentData = load("res://resources/weapons/baton.tres")
	var heat := HeatComponent.new()
	for shot in 5:
		assert_true(heat.try_add_heat(pistol.heat_per_attack))
	assert_false(heat.is_overheated)
	assert_true(heat.try_add_heat(pistol.heat_per_attack))
	assert_true(heat.is_overheated)
	heat.set_heat(0.0)
	heat.is_overheated = false
	for shot in 4:
		assert_true(heat.try_add_heat(scattergun.heat_per_attack))
	assert_true(heat.is_overheated)
	heat.set_heat(0.0)
	heat.is_overheated = false
	for swing in 20:
		assert_true(heat.try_add_heat(baton.heat_per_attack))
	assert_false(heat.is_overheated)


func test_circuit_breaker_prevents_only_first_fatal_hit() -> void:
	var health := HealthComponent.new()
	health.max_health = 3
	health.current_health = 3
	var breaker := CircuitBreakerComponent.new()
	breaker.set_equipped(true)
	health.fatal_damage_interceptor = func(_amount: int, _packet: DamagePacket) -> bool:
		return breaker.try_prevent_fatal_damage()
	var packet := DamagePacket.new()
	packet.base_damage = 5
	packet.source_faction = CombatFaction.Id.ENEMY
	health.apply_damage(packet.base_damage, packet)
	assert_eq(health.current_health, 1)
	assert_true(breaker.circuit_breaker_used)
	health.apply_damage(1, packet)
	assert_true(health.is_dead())
	health.free()
	breaker.free()


func test_circuit_breaker_re_equipping_does_not_refresh_it() -> void:
	var breaker := CircuitBreakerComponent.new()
	assert_true(breaker.try_prevent_fatal_damage())
	breaker.set_equipped(false)
	breaker.set_equipped(true)
	assert_false(breaker.try_prevent_fatal_damage())
	breaker.free()


func test_persona_state_is_independent_and_persistent() -> void:
	var talent_core := TalentCoreController.new()
	assert_true(talent_core.consume_persona_drink(TalentCoreController.ROCK_VIGILANTE))
	assert_true(talent_core.consume_persona_drink(TalentCoreController.ROCK_VIGILANTE))
	assert_true(talent_core.set_talent_choice(
		TalentCoreController.ROCK_VIGILANTE,
		1,
		&"steady_beat"
	))
	assert_true(talent_core.set_talent_choice(
		TalentCoreController.ROCK_VIGILANTE,
		2,
		&"seamless_switch"
	))
	assert_true(talent_core.advance_relationship(TalentCoreController.ROCK_VIGILANTE))
	assert_true(talent_core.consume_persona_drink(TalentCoreController.LEGENDARY_MASTER))
	assert_false(talent_core.record_relationship_event(TalentCoreController.LEGENDARY_MASTER))
	assert_false(talent_core.record_relationship_event(TalentCoreController.LEGENDARY_MASTER))
	assert_true(talent_core.set_persona(TalentCoreController.ROCK_VIGILANTE))
	talent_core.refill_takeover_charges()
	assert_true(talent_core.arm_takeover())
	assert_true(talent_core.consume_takeover_after_success())

	var restored := TalentCoreController.new()
	restored.import_state(talent_core.export_state())
	assert_eq(restored.get_persona_level(TalentCoreController.ROCK_VIGILANTE), 2)
	assert_eq(restored.current_persona_id, TalentCoreController.ROCK_VIGILANTE)
	assert_eq(restored.get_talent_choice(TalentCoreController.ROCK_VIGILANTE, 1), &"steady_beat")
	assert_eq(restored.get_talent_choice(TalentCoreController.ROCK_VIGILANTE, 2), &"seamless_switch")
	assert_eq(restored.get_relationship_stage(TalentCoreController.ROCK_VIGILANTE), 1)
	assert_eq(restored.get_relationship_progress(TalentCoreController.LEGENDARY_MASTER), 2)
	assert_true(restored.record_relationship_event(TalentCoreController.LEGENDARY_MASTER))
	assert_eq(restored.get_relationship_stage(TalentCoreController.LEGENDARY_MASTER), 1)
	assert_eq(restored.get_relationship_progress(TalentCoreController.LEGENDARY_MASTER), 0)
	assert_eq(restored.takeover_charges, 0)
	talent_core.free()
	restored.free()


func test_persona_authorization_is_single_use_per_floor() -> void:
	var manager: Node = load("res://scripts/core/run_manager.gd").new()
	manager.persistent_run = true
	assert_true(manager.prepare_persona_rest(0))
	assert_true(manager.has_persona_authorization(0))
	assert_true(manager.consume_persona_rest_refill(0))
	assert_false(manager.consume_persona_rest_refill(0))
	assert_true(manager.consume_persona_authorization(0))
	assert_false(manager.has_persona_authorization(0))
	assert_false(manager.prepare_persona_rest(0))
	assert_true(manager.prepare_persona_rest(1))
	assert_true(manager.has_persona_authorization(1))
	assert_true(manager.consume_persona_authorization(1))
	assert_true(manager.prepare_persona_rest(2))
	assert_true(manager.has_persona_authorization(2))
	assert_false(manager.prepare_persona_rest(3))
	assert_false(manager.consume_persona_rest_refill(3))
	manager.free()


func test_persona_switch_preserves_build_and_unlocks_level_three_leak_once() -> void:
	var talent_core := TalentCoreController.new()
	var leaks: Array[StringName] = []
	talent_core.semantic_leak_unlocked.connect(func(_persona_id: StringName, leak_id: StringName) -> void: leaks.append(leak_id))
	for _index in range(3):
		assert_true(talent_core.consume_persona_drink(TalentCoreController.DEEP_NINJA))
	assert_true(talent_core.set_talent_choice(TalentCoreController.DEEP_NINJA, 3, &"ceaseless_hunt"))
	assert_true(talent_core.consume_persona_drink(TalentCoreController.LEGENDARY_MASTER))
	assert_true(talent_core.set_persona(TalentCoreController.DEEP_NINJA))
	assert_eq(talent_core.get_persona_level(TalentCoreController.DEEP_NINJA), 3)
	assert_eq(talent_core.get_talent_choice(TalentCoreController.DEEP_NINJA, 3), &"ceaseless_hunt")
	assert_eq(leaks, [&"compute_containment_slip"])
	assert_true(talent_core.consume_persona_drink(TalentCoreController.DEEP_NINJA))
	assert_eq(leaks.size(), 1)
	talent_core.free()


func test_legacy_protocol_snapshot_migrates_to_persona_state() -> void:
	var talent_core := TalentCoreController.new()
	talent_core.import_state({
		"core_level": 2,
		"current_protocol_id": "assault",
		"talent_builds": {
			"assault": {"tier_1": "rapid_fire", "tier_2": "switch_strike"},
			"mobility": {"tier_1": "propulsion_calibration", "tier_2": "momentum_retention"},
		},
		"takeover_charges": 0,
	})
	assert_eq(talent_core.current_persona_id, TalentCoreController.ROCK_VIGILANTE)
	assert_eq(talent_core.get_persona_level(TalentCoreController.ROCK_VIGILANTE), 2)
	assert_eq(talent_core.get_talent_choice(TalentCoreController.ROCK_VIGILANTE, 1), &"steady_beat")
	assert_eq(talent_core.get_talent_choice(TalentCoreController.ROCK_VIGILANTE, 2), &"seamless_switch")
	assert_eq(talent_core.get_persona_level(TalentCoreController.DEEP_NINJA), 2)
	assert_eq(talent_core.get_talent_choice(TalentCoreController.DEEP_NINJA, 1), &"read_opening")
	assert_eq(talent_core.get_talent_choice(TalentCoreController.DEEP_NINJA, 2), &"borrowed_step")
	assert_eq(talent_core.takeover_charges, 0)
	talent_core.free()


func test_dash_does_not_lock_weapon_or_guard() -> void:
	var dash := DashController.new()
	assert_true(dash.can_attack())
	assert_true(dash.can_guard())
	dash.free()


func test_player_config_does_not_shadow_menu_plugin() -> void:
	var gameplay: Script = load("res://scripts/gameplay/player/player_config.gd")
	var menu: Script = load("res://addons/maaacks_menus_template/base/nodes/config/player_config.gd")
	assert_false(gameplay.get_global_name() == menu.get_global_name())
	var config_resource: Resource = load("res://resources/player/default_player_config.tres")
	assert_true(config_resource is CombatPlayerConfig)
