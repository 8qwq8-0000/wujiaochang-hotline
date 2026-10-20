@tool
extends McpTestSuite

const WEAPON_PATHS := [
	"res://resources/weapons/initial_baton.tres",
	"res://resources/weapons/baton.tres",
	"res://resources/weapons/service_pistol.tres",
	"res://resources/weapons/scattergun.tres",
	"res://resources/weapons/rail_cannon.tres",
]
const COATING_SCRIPT := preload("res://scripts/presentation/procedural_coating_2d.gd")


func suite_name() -> String:
	return "weapon_scenes"


func test_all_runtime_weapons_have_valid_views() -> void:
	for path in WEAPON_PATHS:
		var data := load(path) as WeaponComponentData
		assert_true(data != null, path)
		assert_true(data.view_scene != null, path + " view_scene")
		var view := track(data.view_scene.instantiate()) as WeaponView
		assert_true(view != null, path + " WeaponView root")
		assert_true(view.get_node_or_null("BodyRoot/BodySprite") is Sprite2D, path + " body")
		var coating := view.get_node_or_null("BodyRoot/Coating")
		assert_true(coating != null and coating.get_script() == COATING_SCRIPT, path + " coating")
		assert_true(view.get_node_or_null(view.muzzle_socket_path) is Marker2D, path + " muzzle")
		assert_true(view.get_node_or_null("EffectSocket") is Marker2D, path + " effect")
		var sprite := view.get_node("BodyRoot/BodySprite") as Sprite2D
		assert_eq(sprite.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, path + " nearest")
	var scattergun: WeaponComponentData = load("res://resources/weapons/scattergun.tres")
	var scattergun_view := track(scattergun.view_scene.instantiate()) as WeaponView
	assert_true(scattergun_view.get_node_or_null("BodyRoot/RecoilBrace") is Polygon2D)


func test_new_weapon_template_is_valid_but_not_in_loot_catalog() -> void:
	var template := load("res://resources/weapons/templates/weapon_template.tres") as WeaponComponentData
	assert_true(template != null)
	assert_true(template.view_scene != null)
	var view := track(template.view_scene.instantiate()) as WeaponView
	assert_true(view != null)
	var catalog: JSON = load("res://resources/items/components.json")
	assert_false(catalog.data.has(String(template.id)))
