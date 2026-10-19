class_name CombatLayoutData
extends Resource

@export var id: StringName
@export var display_name: String
@export var covers: Array[Rect2] = []
@export var zones: Array[Rect2] = []
# x/y: opening center; z: rotation; w: clear opening width.
@export var doors: Array[Vector4] = []
@export var windows: Array[Rect2] = []
@export var enemy_positions: Array[Vector2] = []
@export var enemy_profiles: Array[Resource] = []
@export var power_position := Vector2(160, 280)
@export var bomb_position := Vector2(450, 245)
@export var floor_color := Color("15212b")
@export var cover_color := Color("405564")
var _navigation: NavigationPolygon


func navigation_polygon() -> NavigationPolygon:
	if _navigation != null:
		return _navigation
	var geometry := NavigationMeshSourceGeometryData2D.new()
	geometry.add_traversable_outline(_outline(Rect2(16, 16, 608, 328)))
	for rect in covers:
		geometry.add_obstruction_outline(_outline(rect))
	for rect in windows:
		geometry.add_obstruction_outline(_outline(rect))
	_navigation = NavigationPolygon.new()
	_navigation.agent_radius = 20.0
	NavigationServer2D.bake_from_source_geometry_data(_navigation, geometry)
	return _navigation


static func _outline(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
