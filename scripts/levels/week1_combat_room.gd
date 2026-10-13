extends Node2D
## Week 1 Combat Room — Member C (scene builder)
## Handles: clear prompt display, room restart, ambience audio

@onready var clear_prompt: CanvasLayer = $ClearPrompt
@onready var clear_label: Label = $ClearPrompt/Label

## Spawn point references
@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var enemy_spawns: Array[Marker2D] = [
	$EnemySpawn1,
	$EnemySpawn2,
	$EnemySpawn3,
]
@onready var component_spawn: Marker2D = $ComponentSpawn

## Audio
@onready var ambience_player: AudioStreamPlayer = null

## State
var enemies_alive: int = 0
var room_cleared: bool = false

signal room_cleared_signal

func _ready() -> void:
	# Start ambience
	_start_ambience()
	# Count enemies (will be set by integration with B's code)
	enemies_alive = enemy_spawns.size()
	room_cleared = false
	clear_prompt.visible = false

func _start_ambience() -> void:
	var ambience_path := "res://assets/audio/ambience/ambience_placeholder.wav"
	if ResourceLoader.exists(ambience_path):
		ambience_player = AudioStreamPlayer.new()
		ambience_player.stream = load(ambience_path)
		ambience_player.volume_db = -12.0
		add_child(ambience_player)
		ambience_player.play()

func _process(_delta: float) -> void:
	# Check if all enemies are dead (placeholder logic)
	if not room_cleared and enemies_alive <= 0:
		_on_room_cleared()

func _on_room_cleared() -> void:
	room_cleared = true
	clear_prompt.visible = true
	room_cleared_signal.emit()

func _input(event: InputEvent) -> void:
	# R to restart room
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()
