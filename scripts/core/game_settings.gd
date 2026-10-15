class_name GameSettingsController
extends Node

signal ai_settings_changed

const ALERT_RESPONSE_STANDARD := 320.0
const KEY_HIGH_PRESSURE_ALERT := "HighPressureAlert"
const KEY_CONTINUOUS_PRECHARGE := "ContinuousPrecharge"

var high_pressure_alert := false
var continuous_precharge := false


func _ready() -> void:
	# Headless tests use deterministic defaults and do not require user://.
	if DisplayServer.get_name() == "headless":
		return
	call_deferred("_load_and_apply")


func _load_and_apply() -> void:
	high_pressure_alert = bool(PlayerConfig.get_config(AppSettings.GAME_SECTION, KEY_HIGH_PRESSURE_ALERT, false))
	continuous_precharge = bool(PlayerConfig.get_config(AppSettings.GAME_SECTION, KEY_CONTINUOUS_PRECHARGE, false))
	AppSettings.set_from_config_and_window(get_window())
	ai_settings_changed.emit()


func set_high_pressure_alert(enabled: bool, persist: bool = true) -> void:
	if high_pressure_alert == enabled:
		return
	high_pressure_alert = enabled
	if persist and DisplayServer.get_name() != "headless":
		PlayerConfig.set_config(AppSettings.GAME_SECTION, KEY_HIGH_PRESSURE_ALERT, enabled)
	ai_settings_changed.emit()


func set_continuous_precharge(enabled: bool, persist: bool = true) -> void:
	if continuous_precharge == enabled:
		return
	continuous_precharge = enabled
	if persist and DisplayServer.get_name() != "headless":
		PlayerConfig.set_config(AppSettings.GAME_SECTION, KEY_CONTINUOUS_PRECHARGE, enabled)
	ai_settings_changed.emit()


func get_alert_response_distance() -> float:
	return INF if high_pressure_alert else ALERT_RESPONSE_STANDARD
