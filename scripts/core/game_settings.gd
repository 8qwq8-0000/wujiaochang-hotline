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


func _ready() -> void:
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
