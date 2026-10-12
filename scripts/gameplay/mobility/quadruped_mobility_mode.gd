class_name QuadrupedMobilityMode
extends MobilityMode

@export_range(0.0, 1.0, 0.05) var rough_terrain_multiplier: float = 0.95


func terrain_speed_multiplier(terrain_tag: StringName) -> float:
	if terrain_tag == &"mud" or terrain_tag == &"rubble":
		return rough_terrain_multiplier
	return 1.0
