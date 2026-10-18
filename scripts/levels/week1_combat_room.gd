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
	# Count the actual living enemies in this room; never substitute a guessed count.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_ancestor_of(enemy):
			_connect_enemy(enemy)
	var run := get_node_or_null("/root/RunManager")
	if run != null:
		run.set_mandatory_enemy_count(enemies_alive)
	if enemies_alive == 0:
		_on_room_cleared()

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

func _on_enemy_died(_packet: DamagePacket) -> void:
	enemies_alive = max(0, enemies_alive - 1)
	var run := get_node_or_null("/root/RunManager")
	if run != null:
		run.set_mandatory_enemy_count(enemies_alive)

func _on_room_cleared() -> void:
	room_cleared = true
	clear_prompt.visible = true
	room_cleared_signal.emit()
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.publish_floor_cleared()

func _unhandled_input(event: InputEvent) -> void:
	# Bootstrap owns full-scene restart when loaded through Main.
	if get_tree().current_scene.get_node_or_null("SceneFlow") != null:
		return
	# F6 standalone room restart.
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		get_tree().reload_current_scene()
