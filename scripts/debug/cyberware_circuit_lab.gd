extends Node2D

const ENEMY_SCENE := preload("res://scenes/actors/enemies/enemy.tscn")
const MELEE_PROFILE := preload("res://resources/enemies/melee_pressure.tres")
const RANGED_PROFILE := preload("res://resources/enemies/ranged_sightline.tres")
const FIRST_PLAYABLE_MODULES := [
	&"active_neural_switch",
	&"combat_synapse_sensor",
	&"rhythm_pulser",
	&"smart_fire",
	&"explosive_magazine",
	&"tactical_coprocessor",
	&"kill_energy_sink",
	&"guard_coprocessor",
	&"instruction_mirror_synapse",
]
const DEFAULT_SLOTS := [
	"active_neural_switch",
	"smart_fire",
	"explosive_magazine",
	"tactical_coprocessor",
]

@onready var player: PlayerController = $Player
@onready var status: Label = $LabUI/Status


func _ready() -> void:
	add_to_group("combat_rooms")
	_build_controls()
	reset_circuit()
	_spawn_training_enemies()
	queue_redraw()


func receive_scene_payload(payload: Dictionary) -> void:
	if payload.has("player_state") and payload["player_state"] is Dictionary:
		player.import_run_state(payload["player_state"])
	reset_circuit()


func reset_energy_and_heat() -> void:
	var capacity_energy: float = CyberwareCircuitState.DEFAULT_MAXIMUM_ENERGY + 20.0 * (player.cyberware.circuit.slot_capacity - CyberwareCircuitState.INITIAL_SLOT_COUNT)
	player.cyberware.circuit.maximum_energy = capacity_energy
	player.cyberware.circuit.set_energy(capacity_energy)
	player.heat.set_heat(0.0)
	player.heat.is_overheated = false
	player.health.set_current_health(player.health.max_health)
	player.cyberware.circuit_changed.emit(player.cyberware.export_circuit_state())
	status.text = "能量、热量与耐久已复位。"


func reset_circuit() -> void:
	player.cyberware.reset_transient_state()
	player.cyberware.set_circuit_slots(PackedStringArray())
	player.cyberware.circuit.set_slot_capacity(DEFAULT_SLOTS.size())
	var counts: Dictionary = {}
	for module_id in FIRST_PLAYABLE_MODULES:
		counts[module_id] = CyberwareCircuitState.SLOT_COUNT
	player.cyberware.set_circuit_library_counts(counts)
	player.cyberware.set_circuit_slots(PackedStringArray(DEFAULT_SLOTS))
	reset_energy_and_heat()
	status.text = "已恢复 9 件义体库存与主动武器链示例；按 C 重排。"


func reset_enemies() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		if node is EnemyController and is_ancestor_of(node):
			node.free()
	_spawn_training_enemies()
	status.text = "固定射击敌人与近战敌人已复位。"


func get_training_enemies() -> Array[EnemyController]:
	var result: Array[EnemyController] = []
	for child in get_children():
		if child is EnemyController:
			result.append(child)
	return result


func _spawn_training_enemies() -> void:
	_spawn_enemy("StationaryShooter", Vector2(470, 118), RANGED_PROFILE, true)
	_spawn_enemy("MeleePressure", Vector2(500, 260), MELEE_PROFILE, false)


func _spawn_enemy(node_name: String, at: Vector2, profile: EnemyProfile, stationary: bool) -> void:
	var enemy := ENEMY_SCENE.instantiate() as EnemyController
	enemy.name = node_name
	enemy.profile = profile
	enemy.position = at
	enemy.mandatory = false
	enemy.stationary_test_target = stationary
	add_child(enemy)


func _build_controls() -> void:
	var row := $LabUI/Controls as HBoxContainer
	_button(row, "能量 / 热量复位", reset_energy_and_heat)
	_button(row, "回路复位", reset_circuit)
	_button(row, "敌人复位", reset_enemies)


func _button(parent: Control, text: String, callable: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.theme = CyberUITheme.create_theme()
	button.pressed.connect(callable)
	parent.add_child(button)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color("081211"), true)
	for x in range(0, 641, 32):
		draw_line(Vector2(x, 0), Vector2(x, 360), Color(0.12, 0.3, 0.23, 0.25), 1.0)
	for y in range(0, 361, 32):
		draw_line(Vector2(0, y), Vector2(640, y), Color(0.12, 0.3, 0.23, 0.25), 1.0)
	draw_string(CyberUITheme.FONT, Vector2(352, 88), "无限靶", HORIZONTAL_ALIGNMENT_CENTER, 96, 11, CyberUITheme.MUTED)
	draw_string(CyberUITheme.FONT, Vector2(424, 92), "固定敌人", HORIZONTAL_ALIGNMENT_CENTER, 96, 11, CyberUITheme.WARNING)
	draw_string(CyberUITheme.FONT, Vector2(452, 324), "近战敌人", HORIZONTAL_ALIGNMENT_CENTER, 96, 11, CyberUITheme.DANGER)
