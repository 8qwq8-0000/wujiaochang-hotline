extends Node2D
## Week 1 Combat Room — Member C (scene builder)
## Handles: clear prompt display, room restart, ambience audio, enemy tracking

@onready var clear_prompt: CanvasLayer = $ClearPrompt
@onready var clear_label: Label = $ClearPrompt/Label
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var component_spawn: Marker2D = $ComponentSpawn

## Audio
var ambience_player: AudioStreamPlayer = null

## State
var enemies_alive: int = 0
var room_cleared: bool = false

signal room_cleared_signal

func _ready() -> void:
	_start_ambience()
	clear_prompt.visible = false
	room_cleared = false
	# Count and connect enemies
	var enemies := get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		# Try to find enemy instances directly
		var instances := $Instances
		for child in instances.get_children():
			if child.name.begins_with("Enemy"):
				_connect_enemy(child)
	# If no enemies found through instances, assume 3
	if enemies_alive == 0:
		enemies_alive = 3

func _connect_enemy(enemy: Node) -> void:
	enemies_alive += 1
	var health := enemy.get_node_or_null("HealthComponent")
	if health and health.has_signal("died"):
		health.died.connect(_on_enemy_died)

func _start_ambience() -> void:
	var ambience_path := "res://assets/audio/ambience/ambience_placeholder.wav"
	if ResourceLoader.exists(ambience_path):
		ambience_player = AudioStreamPlayer.new()
		ambience_player.stream = load(ambience_path)
		ambience_player.volume_db = -12.0
		add_child(ambience_player)
		ambience_player.play()

func _process(_delta: float) -> void:
	if not room_cleared and enemies_alive <= 0:
		_on_room_cleared()

func _on_enemy_died() -> void:
	enemies_alive = max(0, enemies_alive - 1)

func _on_room_cleared() -> void:
	room_cleared = true
	clear_prompt.visible = true
	room_cleared_signal.emit()

func _input(event: InputEvent) -> void:
	# R to restart room
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()
