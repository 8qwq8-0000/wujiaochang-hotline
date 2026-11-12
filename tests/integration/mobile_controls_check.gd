extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func run() -> void:
	var mobile_input := root.get_node_or_null("MobileInput")
	check(mobile_input != null, "mobile input autoload is registered")
	if mobile_input == null:
		root.get_node("GameSettings").quit_game(1)
		return
	await process_frame
	check(bool(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch", false)), "touch can operate ordinary menu Buttons")
	check(not bool(ProjectSettings.get_setting("application/config/quit_on_go_back", true)), "Android back is delegated to the in-game navigation handler")

	var joystick := mobile_input.get("_joystick") as VirtualJoystick
	check(joystick != null, "touch controls use Godot's built-in VirtualJoystick")
	check(joystick.action_left == &"move_left" and joystick.action_right == &"move_right", "joystick feeds the shared movement InputMap")
	check(joystick.action_up == &"move_up" and joystick.action_down == &"move_down", "joystick covers both movement axes")

	var buttons: Dictionary = mobile_input.get("_buttons")
	var expected := {
		"attack": &"attack",
		"guard": &"guard",
		"dash": &"mobility_ability",
		"interact": &"interact",
		"weapon": &"weapon_switch",
		"inventory": &"inventory_toggle",
		"pause": &"pause",
	}
	for control_name in expected:
		var button := buttons.get(control_name) as MobileActionButton
		check(button != null and button.action_name == expected[control_name], "%s touch button uses the shared action" % control_name)
	check((buttons.attack as MobileActionButton).supports_direction, "attack supports manual drag aim")
	check((buttons.guard as MobileActionButton).supports_direction, "guard supports manual drag aim")
	var attack := buttons.attack as MobileActionButton
	check(attack.joystick_style and attack.defer_action_until_drag, "attack uses tap-or-drag joystick semantics")
	attack._begin_press(attack.size * 0.9)
	check(not attack.is_action_active(), "attack joystick waits for tap release or a drag before firing")
	check((mobile_input.get("_manual_aim") as Vector2).is_zero_approx(), "pressing off-center still uses auto aim until a drag occurs")
	attack._update_direction(attack.size * Vector2(0.95, 0.5))
	check(attack.is_action_active(), "crossing the attack joystick deadzone starts held fire")
	check(not (mobile_input.get("_manual_aim") as Vector2).is_zero_approx(), "dragging attack enables manual aim")
	attack._end_press()
	check(not attack.is_action_active(), "releasing the attack joystick stops held fire")
	check((mobile_input.get("_manual_aim") as Vector2).is_zero_approx(), "releasing attack clears manual aim")
	Input.action_release(&"attack")
	await process_frame

	var player := load("res://scenes/actors/player/player.tscn").instantiate() as PlayerController
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	mobile_input.set("_player", player)
	player.aim_direction = Vector2.RIGHT
	var near_behind := Node2D.new()
	near_behind.add_to_group(&"enemies")
	root.add_child(near_behind)
	near_behind.global_position = player.global_position + Vector2(-50.0, 0.0)
	var useful_ahead := Node2D.new()
	useful_ahead.add_to_group(&"enemies")
	root.add_child(useful_ahead)
	useful_ahead.global_position = player.global_position + Vector2(80.0, 0.0)
	mobile_input._refresh_target(true)
	check(mobile_input.get("_target") == useful_ahead, "auto aim favors an in-range target aligned with facing over a slightly nearer target behind")
	attack._begin_press(attack.size * 0.5)
	attack._end_press()
	check(attack.is_action_active(), "tap release holds attack long enough to commit one auto-aim shot")
	check(mobile_input.get("_target") == useful_ahead, "attack tap reselects the current optimal target")
	await physics_frame
	await physics_frame
	await process_frame
	check(not attack.is_action_active(), "tap attack releases automatically after one physics opportunity")
	attack._begin_press(attack.size * 0.5)
	attack._update_direction(attack.size * Vector2(0.95, 0.5))
	player.set("_attack_buffer_remaining", 0.0)
	check(mobile_input.is_manual_attack_active(player), "dragged attack joystick exposes manual-fire intent")
	check(player._should_attack_this_frame(), "manual-fire intent repeats semi-auto weapons while held")
	attack._end_press()
	near_behind.queue_free()
	useful_ahead.queue_free()
	await process_frame
	check(not mobile_input._has_available_interaction(), "interact button stays hidden without a nearby target")
	var pickup := load("res://scenes/items/component_pickup.tscn").instantiate() as ComponentPickup
	root.add_child(pickup)
	pickup.global_position = player.global_position + Vector2(20.0, 0.0)
	await physics_frame
	check(player.inventory.get_nearest_reachable_pickup() == pickup, "inventory query finds a reachable ground pickup")
	check(mobile_input._has_available_interaction(), "ground pickup makes the mobile interact button available")
	mobile_input.set("_touch_preview", true)
	mobile_input.set("_using_touch", true)
	mobile_input._process(0.0)
	check((buttons.interact as MobileActionButton).visible, "reachable ground pickup shows the actual mobile interact button")
	var pickup_item := pickup.rolled_item
	(buttons.interact as MobileActionButton)._begin_press(Vector2.ZERO)
	await process_frame
	(buttons.interact as MobileActionButton)._end_press()
	await process_frame
	check(not is_instance_valid(pickup) or pickup.is_queued_for_deletion(), "pressing the visible mobile interact button collects the ground pickup")
	check(player.inventory.item_location(pickup_item) != "", "mobile pickup preserves the same item instance in inventory")
	var distant_pickup := load("res://scenes/items/component_pickup.tscn").instantiate() as ComponentPickup
	root.add_child(distant_pickup)
	distant_pickup.global_position = player.global_position + Vector2(80.0, 0.0)
	await physics_frame
	check(not mobile_input._has_available_interaction(), "distant ground pickup hides the mobile interact button again")
	mobile_input._process(0.0)
	check(not (buttons.interact as MobileActionButton).visible, "distant ground pickup hides the actual mobile interact button")
	mobile_input.set("_touch_preview", false)

	var right: Dictionary = mobile_input._default_layout(false)
	var left: Dictionary = mobile_input._default_layout(true)
	for control_name in right:
		var right_position: Vector2 = right[control_name].position
		var left_position: Vector2 = left[control_name].position
		check(is_equal_approx(left_position.x, 1.0 - right_position.x) and is_equal_approx(left_position.y, right_position.y), "%s mirrors between handed presets" % control_name)

	mobile_input.begin_layout_edit()
	check(mobile_input.get("_editing") and mobile_input.get("_root").visible, "layout editor exposes all controls")
	mobile_input.finish_layout_edit()
	check(not mobile_input.get("_editing"), "layout editor exits cleanly")
	distant_pickup.queue_free()
	player.queue_free()
	await process_frame
	var master := AudioServer.get_bus_index(&"Master")
	var original_mute := AudioServer.is_bus_mute(master)
	mobile_input._mute_for_background()
	check(AudioServer.is_bus_mute(master), "mobile background transition mutes audio")
	mobile_input._restore_background_audio()
	check(AudioServer.is_bus_mute(master) == original_mute, "foreground restore preserves the user's prior mute state")

	var menu: PauseSettingsMenu = load("res://scenes/ui/pause_settings_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	mobile_input._handle_system_back()
	await process_frame
	check(menu.visible and paused, "Android system back opens the pause menu")
	mobile_input._handle_system_back()
	await process_frame
	check(not menu.visible and not paused, "Android system back closes the pause menu")

	menu.queue_free()
	await process_frame
	print("Mobile controls failures: ", failures)
	root.get_node("GameSettings").quit_game(0 if failures == 0 else 1)
