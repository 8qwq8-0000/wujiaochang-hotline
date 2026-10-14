extends Node

const PICKUP_SCENE := preload("res://scenes/items/component_pickup.tscn")
func _ready() -> void:
	get_node("/root/CombatEvents").entity_defeated.connect(_on_defeated)

func _on_defeated(entity: Node) -> void:
	if not entity is EnemyController or entity.has_meta("component_loot_emitted"):
		return
	entity.set_meta("component_loot_emitted", true)
	var component := "baton"
	match entity.profile.role:
		EnemyProfile.Role.RANGED_SIGHTLINE:
			component = "pistol"
		EnemyProfile.Role.HEAVY_ANCHOR:
			component = "wheel"
	# Snapshot location now; the enemy is freed at the end of the frame.
	call_deferred("_spawn", component, entity.global_position)

func _spawn(component: String, location: Vector2) -> void:
	var pickup: ComponentPickup = PICKUP_SCENE.instantiate()
	pickup.component_id = component
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = location
