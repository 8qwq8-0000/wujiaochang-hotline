class_name RefinedEnvironmentArt
extends Node2D

## Presentation-only adapter. Original interaction, damage and collision nodes
## remain authoritative; self_modulate hides only the parent's old debug drawing.
@export_enum("power", "explosive", "door", "exit", "gpt") var kind := "power"
@export var draw_size := Vector2(32, 40)
@export var draw_offset := Vector2.ZERO
var _owner: Node2D
var _state := -99
var _pose := 0.0
static var _textures: Dictionary = {}
const ROOT := "res://assets/art/environment/refined/"
# Opaque silhouette bounds measured once from the source PNGs. Ignore faint
# alpha speckles in their wide transparent margins without altering the images.
const REGIONS := {
	"charging_terminal.png": Rect2(283, 259, 641, 863),
	"explosive_crate.png": Rect2(301, 292, 652, 671),
	"bulkhead_closed.png": Rect2(228, 324, 667, 697),
	"bulkhead_open.png": Rect2(225, 322, 671, 700),
	"downward_elevator.png": Rect2(94, 228, 934, 936),
	"gpt_synthesist.png": Rect2(100, 12, 1017, 1376),
}

static func art_texture(filename: String) -> Texture2D:
	if not _textures.has(filename):
		var source: Texture2D = load(ROOT + filename)
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = REGIONS[filename]
		_textures[filename] = atlas
	return _textures[filename]

func _ready() -> void:
	_owner = get_parent() as Node2D
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if _owner == null:
		return
	_owner.self_modulate = Color(1, 1, 1, 0)
	if kind == "exit":
		var label := _owner.get_node_or_null("Label") as Label
		if label != null:
			label.position.y = -54
	_process(0.0)

func _process(_delta: float) -> void:
	var next := 0
	if kind == "power":
		next = int(_owner.get("state"))
	elif kind == "explosive":
		next = 1 if _owner.get("broken") else 0
	elif kind == "door":
		next = 1 if _owner.get("opened") else 0
	elif kind == "exit":
		next = 1 if _owner.get("enabled") else 0
	var pose := 0.0
	if next != _state or not is_equal_approx(pose, _pose):
		_state = next
		_pose = pose
		queue_redraw()

func _draw() -> void:
	if _owner == null:
		return
	var filename := ""
	var tint := Color.WHITE
	match kind:
		"power":
			filename = "charging_terminal.png"
			if _state != 0:
				tint = Color(0.50, 0.65, 0.57) if _state == 1 else Color(0.27, 0.30, 0.33)
		"explosive":
			# The explosion/fire patch owns the active aftermath, not an intact crate.
			if _state == 1:
				return
			filename = "explosive_crate.png"
		"door":
			filename = "bulkhead_open.png" if _state == 1 else "bulkhead_closed.png"
		"exit":
			filename = "downward_elevator.png"
			if _state == 0:
				tint = Color(0.40, 0.43, 0.46)
		"gpt":
			filename = "gpt_synthesist.png"
	if not filename.is_empty():
		draw_texture_rect(art_texture(filename), Rect2(draw_offset - draw_size * 0.5, draw_size), false, tint)
