class_name ComponentPickup
extends Node2D

@export_enum("pistol", "scattergun", "rail_cannon", "wheel", "armor") var component_id := "pistol"
var rolled_item: InventoryItem
var _picked := false
var _label: Label

func _ready() -> void:
	if rolled_item == null:
		rolled_item = ComponentRolls.create(component_id, 1, RandomNumberGenerator.new())
	add_to_group("component_pickups")
	var definition: Dictionary = ComponentInventory.PROTOTYPES.data.get(rolled_item.get_prototype().get_prototype_id(), {})
	var icon := Sprite2D.new()
	icon.texture = load(str(definition.get("image", "res://icon.svg")))
	add_child(icon)
	_label = Label.new()
	_label.position = Vector2(-90, 18)
	_label.size.x = 180
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 3)
	_label.text = "E 拾取 · %s" % ComponentRolls.title(rolled_item)
	ComponentRolls.apply_quality_color(_label, rolled_item)
	_label.visible = false
	add_child(_label)

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as PlayerController
	_label.visible = player != null and not player.health.is_dead() and can_reach(player)

func can_reach(player: Node2D) -> bool:
	if _picked or player.global_position.distance_to(global_position) > 44.0:
		return false
	var query := PhysicsRayQueryParameters2D.create(player.global_position, global_position, 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func try_pickup(inventory: ComponentInventory) -> bool:
	if not can_reach(inventory.player) or not inventory.pickup(component_id, rolled_item):
		return false
	_picked = true
	queue_free()
	return true

func _draw() -> void:
	if rolled_item != null:
		draw_arc(Vector2.ZERO, 17.0, 0.0, TAU, 28, ComponentRolls.quality_color(rolled_item), 2.0, true)
