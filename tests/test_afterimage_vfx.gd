@tool
extends McpTestSuite


func suite_name() -> String:
	return "afterimage_vfx"


func _sprite_with_one_frame() -> AnimatedSprite2D:
	var sprite := track(AnimatedSprite2D.new()) as AnimatedSprite2D
	var frames := SpriteFrames.new()
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	frames.add_frame(&"default", ImageTexture.create_from_image(image))
	sprite.sprite_frames = frames
	sprite.flip_h = true
	return sprite


func test_afterimage_copies_frame_and_flip_state() -> void:
	var source := track(Node2D.new()) as Node2D
	var sprite := _sprite_with_one_frame()
	source.add_child(sprite)
	var effect := track(load("res://scenes/presentation/afterimage_effect.tscn").instantiate()) as AfterimageEffect
	assert_true(effect.play(source, sprite, Color.CYAN, 0.25))
	assert_true(effect.texture != null)
	assert_true(effect.flip_h)
	assert_eq(effect.source_id, source.get_instance_id())


func test_pool_never_exceeds_budget_and_source_clear_recycles() -> void:
	var manager := track(VFXManager.new()) as VFXManager
	manager.prewarm_count = 1
	manager.afterimage_budget = 2
	(Engine.get_main_loop() as SceneTree).root.add_child(manager)
	var source := track(Node2D.new()) as Node2D
	var sprite := _sprite_with_one_frame()
	source.add_child(sprite)
	for _index in 5:
		manager.spawn_afterimage(source, sprite)
	var active: Array = manager.get("_active_afterimages")
	assert_eq(active.size(), 2)
	manager.clear_afterimages(source)
	active = manager.get("_active_afterimages")
	var available: Array = manager.get("_available_afterimages")
	assert_eq(active.size(), 0)
	assert_eq(available.size(), 2)
