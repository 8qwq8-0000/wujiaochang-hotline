extends Node

const CUES := {
	&"pickup": preload("res://assets/audio/sfx/enemy_ui/pickup.wav"),
	&"equip": preload("res://assets/audio/sfx/enemy_ui/equip.wav"),
	&"full": preload("res://assets/audio/sfx/enemy_ui/full.wav"),
}
var _voice: AudioStreamPlayer
func _ready() -> void:
	_voice = AudioStreamPlayer.new()
	_voice.volume_db = -10.0
	add_child(_voice)
	get_parent().feedback.connect(_on_feedback)

func _on_feedback(_text: String, cue: StringName) -> void:
	if DisplayServer.get_name() != "headless" and CUES.has(cue):
		_voice.stream = CUES[cue]
		_voice.play()


func _exit_tree() -> void:
	if is_instance_valid(_voice):
		_voice.stop()
