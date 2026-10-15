@tool
extends McpTestSuite


func suite_name() -> String:
	return "projectile_scene"


func test_placeholder_visual_keeps_projectile_contract() -> void:
	var projectile := load("res://scenes/combat/projectile.tscn").instantiate() as CombatProjectile
	var visual := projectile.get_node_or_null("Visual") as Sprite2D
	var collision := projectile.get_node_or_null("CollisionShape2D") as CollisionShape2D
	assert_true(visual != null)
	assert_true(visual.texture != null)
	assert_eq(visual.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(visual.scale, Vector2(0.25, 0.25))
	assert_true(collision != null and collision.shape is CircleShape2D)
	assert_true(is_equal_approx((collision.shape as CircleShape2D).radius, 3.0))

	projectile.setup(null, CombatFaction.Id.PLAYER, Vector2.UP, 2, 310.0)
	assert_eq(visual.modulate, Color(0.3, 0.9, 1.0))
	assert_true(is_equal_approx(projectile.rotation, -PI / 2.0))
	assert_eq(projectile.damage, 2)
	assert_true(is_equal_approx(projectile.speed, 310.0))
	projectile.free()
