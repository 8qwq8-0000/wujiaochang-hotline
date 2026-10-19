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
	for id in ["service_pistol", "scattergun", "rail_cannon"]:
		var view: WeaponView = load("res://scenes/weapons/"+id+".tscn").instantiate()
		root.add_child(view)
		var body: Sprite2D = view.get_node("BodyRoot/BodySprite")
		check(body.texture.get_image().detect_alpha() != Image.ALPHA_NONE, id+" has a transparent sprite")
		check(body.texture.get_width() <= 48 and body.texture.get_height() <= 20,id+" uses game-sized texture")
		check(not body.flip_h and body.scale == Vector2.ONE,id+" uses unit scale")
		var right_edge := body.position.x + body.texture.get_width() * (0.5 if body.centered else 1.0)
		check(absf(right_edge-view.muzzle_socket.position.x) <= 1.0 and is_zero_approx(view.muzzle_socket.position.y),id+" muzzle is at barrel end on wrist-lock axis")
		var data := WeaponComponentData.new()
		data.id = id
		view.configure(data)
		view.play_attack()
		check(view.muzzle_flash.visible,id+" attack shows effect")
		await create_timer(0.16).timeout
		check(view.muzzle_flash.visible == (id=="rail_cannon"),id+" beam holds longer than an ordinary flash")
		await create_timer(0.25).timeout
		check(not view.muzzle_flash.visible,id+" effect finishes and hides")
		view.play_attack()
		view.cancel_feedback()
		check(not view.muzzle_flash.visible and view.body_root.position == Vector2.ZERO,id+" switching cancels flash and recoil")
		view.queue_free()
		await process_frame
	print("Weapon art checks: ",checks,"; failures: ",failures)
	quit(0 if failures==0 else 1)
