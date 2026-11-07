class_name BossFloorGeometry
extends RefCounted

## Exact orthographic 32px cells composited into rooftop_server_chapel_topdown_v5.png.
const ORIGIN := Vector2(256.0, 300.0)
const CELL_SIZE := 32.0
const GRID_MAX := Vector2i(23, 13)

static func cell_point(cell: Vector2i) -> Vector2:
    var clamped := Vector2i(clampi(cell.x, 0, GRID_MAX.x), clampi(cell.y, 0, GRID_MAX.y))
    return ORIGIN + Vector2(clamped) * CELL_SIZE + Vector2.ONE * CELL_SIZE * 0.5

static func nearest_cell(point: Vector2) -> Vector2i:
    var relative := (point - ORIGIN) / CELL_SIZE
    return Vector2i(clampi(floori(relative.x), 0, GRID_MAX.x), clampi(floori(relative.y), 0, GRID_MAX.y))

static func cell_polygon(cell: Vector2i) -> PackedVector2Array:
    var corner := ORIGIN + Vector2(cell) * CELL_SIZE
    return PackedVector2Array([corner, corner + Vector2(CELL_SIZE, 0), corner + Vector2(CELL_SIZE, CELL_SIZE), corner + Vector2(0, CELL_SIZE)])
