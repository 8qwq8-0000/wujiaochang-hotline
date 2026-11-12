class_name GameSettingsController
extends Node

signal ai_settings_changed

enum Difficulty {
	LOW,
	STANDARD,
	HIGH,
}

const ALERT_RESPONSE_LOW := 160.0
const ALERT_RESPONSE_STANDARD := 320.0
const VISUAL_RANGE_LOW_SCALE := 0.75
const HEARING_RANGE_LOW := 180.0
const KEY_DIFFICULTY := "Difficulty"
const KEY_HIGH_PRESSURE_ALERT := "HighPressureAlert"
const KEY_CONTINUOUS_PRECHARGE := "ContinuousPrecharge"

var difficulty: Difficulty = Difficulty.STANDARD
var high_pressure_alert := false
var continuous_precharge := false
var elemental_reactions_enabled := false
var _quitting := false
var test_tools: CanvasLayer


func _ready() -> void:
	get_tree().auto_accept_quit = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Keep test commands out of public release builds.
	if OS.has_feature("editor") or OS.has_feature("debug"):
		test_tools = load("res://scripts/ui/test_mode_panel.gd").new()
		test_tools.name = "TestTools"
		add_child(test_tools)
	# Headless tests use deterministic defaults and do not require user://.
	if DisplayServer.get_name() == "headless":
		return
	call_deferred("_load_and_apply")


func _load_and_apply() -> void:
	var saved_difficulty := int(PlayerConfig.get_config(AppSettings.GAME_SECTION, KEY_DIFFICULTY, -1))
	if saved_difficulty < Difficulty.LOW or saved_difficulty > Difficulty.HIGH:
		difficulty = Difficulty.HIGH if bool(PlayerConfig.get_config(AppSettings.GAME_SECTION, KEY_HIGH_PRESSURE_ALERT, false)) else Difficulty.STANDARD
		PlayerConfig.set_config(AppSettings.GAME_SECTION, KEY_DIFFICULTY, int(difficulty))
	else:
		difficulty = saved_difficulty as Difficulty
	var profile: Dictionary = get_node("/root/WarehouseStore").get_profile()
	if profile.has("difficulty"):
		difficulty = ["low_pressure", "standard", "high_pressure"].find(profile.difficulty) as Difficulty
	high_pressure_alert = difficulty == Difficulty.HIGH
	continuous_precharge = bool(PlayerConfig.get_config(AppSettings.GAME_SECTION, KEY_CONTINUOUS_PRECHARGE, false))
	AppSettings.set_from_config_and_window(get_window())
	ai_settings_changed.emit()


func set_high_pressure_alert(enabled: bool, persist: bool = true) -> void:
	set_difficulty(Difficulty.HIGH if enabled else Difficulty.STANDARD, persist)


func set_difficulty(value: Difficulty, persist: bool = true) -> void:
	value = clampi(int(value), Difficulty.LOW, Difficulty.HIGH) as Difficulty
	if difficulty == value:
		return
	difficulty = value
	high_pressure_alert = difficulty == Difficulty.HIGH
	if persist and DisplayServer.get_name() != "headless":
		PlayerConfig.set_config(AppSettings.GAME_SECTION, KEY_DIFFICULTY, int(difficulty))
		PlayerConfig.set_config(AppSettings.GAME_SECTION, KEY_HIGH_PRESSURE_ALERT, high_pressure_alert)
	ai_settings_changed.emit()


func set_continuous_precharge(enabled: bool, persist: bool = true) -> void:
	if continuous_precharge == enabled:
		return
	continuous_precharge = enabled
	if persist and DisplayServer.get_name() != "headless":
		PlayerConfig.set_config(AppSettings.GAME_SECTION, KEY_CONTINUOUS_PRECHARGE, enabled)
	ai_settings_changed.emit()


func get_alert_response_distance() -> float:
	match difficulty:
		Difficulty.LOW:
			return ALERT_RESPONSE_LOW
		Difficulty.HIGH:
			return INF
		_:
			return ALERT_RESPONSE_STANDARD


func get_visual_range_scale() -> float:
	return VISUAL_RANGE_LOW_SCALE if difficulty == Difficulty.LOW else 1.0


func get_hearing_range_limit() -> float:
	return HEARING_RANGE_LOW if difficulty == Difficulty.LOW else INF


func is_low_pressure() -> bool:
	return difficulty == Difficulty.LOW


func are_elemental_reactions_enabled() -> bool:
	# The shipped game keeps the deferred reaction system disabled for this UI pass.
	# Headless regression scenes can still exercise the preserved implementation.
	return elemental_reactions_enabled or DisplayServer.get_name() == "headless"


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


func quit_game(exit_code: int = 0) -> void:
	if _quitting:
		return
	_quitting = true
	var tree := get_tree()
	# Prevent gameplay, UI callbacks and music transitions from restarting audio.
	for child in tree.root.find_children("*", "Node", true, false):
		if child != self:
			child.process_mode = Node.PROCESS_MODE_DISABLED
	for kind in ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]:
		for player in tree.root.find_children("*", kind, true, false):
			player.stop()
			player.stream = null
	# AudioServer releases playback references on its next mix/update, before
	# SceneTree teardown destroys resources and the scripting VM.
	var deadline := Time.get_ticks_msec() + 100
	while Time.get_ticks_msec() < deadline:
		await tree.process_frame
	tree.quit(exit_code)
