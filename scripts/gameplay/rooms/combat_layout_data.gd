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
@export var room_size := Vector2(640.0, 360.0)
var _navigation: NavigationPolygon


func navigation_polygon() -> NavigationPolygon:
	if _navigation != null:
		return _navigation
	var geometry := NavigationMeshSourceGeometryData2D.new()
	geometry.add_traversable_outline(_outline(Rect2(Vector2(16, 16), room_size - Vector2(32, 32))))
	for rect in covers:
		geometry.add_obstruction_outline(_outline(rect))
	for rect in windows:
		geometry.add_obstruction_outline(_outline(rect))
	_navigation = NavigationPolygon.new()
	_navigation.agent_radius = 20.0
	NavigationServer2D.bake_from_source_geometry_data(_navigation, geometry)
	return _navigation


func scaled_for_room(scale_factor: float, base_size: Vector2 = Vector2(640.0, 360.0)) -> CombatLayoutData:
	if is_equal_approx(scale_factor, 1.0):
		return self
	var result := CombatLayoutData.new()
	result.id = id
	result.display_name = display_name
	result.room_size = base_size * scale_factor
	result.floor_color = floor_color
	result.cover_color = cover_color
	for rect in covers:
		result.covers.append(_scaled_rect_center(rect, scale_factor, base_size, false))
	for rect in windows:
		result.windows.append(_scaled_rect_center(rect, scale_factor, base_size, false))
	for rect in zones:
		result.zones.append(_scaled_rect_center(rect, scale_factor, base_size, true))
	for definition in doors:
		var point := _scaled_point(Vector2(definition.x, definition.y), scale_factor, base_size)
		result.doors.append(Vector4(point.x, point.y, definition.z, definition.w))
	for point in enemy_positions:
		result.enemy_positions.append(_scaled_point(point, scale_factor, base_size))
	result.enemy_profiles.assign(enemy_profiles)
	result.power_position = _scaled_point(power_position, scale_factor, base_size)
	result.bomb_position = _scaled_point(bomb_position, scale_factor, base_size)
	return result


static func _scaled_point(point: Vector2, scale_factor: float, base_size: Vector2) -> Vector2:
	return base_size * scale_factor * 0.5 + (point - base_size * 0.5) * scale_factor


static func _scaled_rect_center(rect: Rect2, scale_factor: float, base_size: Vector2, scale_size: bool) -> Rect2:
	var size := rect.size * scale_factor if scale_size else rect.size
	return Rect2(_scaled_point(rect.get_center(), scale_factor, base_size) - size * 0.5, size)


static func _outline(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
