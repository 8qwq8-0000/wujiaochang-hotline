extends "res://scripts/debug/electric_reaction_sandbox.gd"

func _ready() -> void:
	super._ready()
	$UI/Ignite.pressed.connect(_ignite_patches)

func _ignite_patches() -> void:
	if get_tree().paused or player.health.is_dead():
		return
	for patch in get_tree().get_nodes_in_group("fuel_patches"):
		if CombatProjectile.room_for_actor(patch) != self:
			continue
		var packet := DamagePacket.new()
		packet.damage_type = &"fire"
		packet.source_faction = CombatFaction.Id.ENVIRONMENT
		patch.receive_hit(packet)
