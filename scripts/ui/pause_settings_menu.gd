class_name PauseSettingsMenu
extends CanvasLayer

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]
const DISPLAY_CONFIRM_SECONDS := 10.0
const UI_SECTION := &"UISettings"
const CRT_STRENGTH_SETTING := &"CRTStrength"
const HUD_SCALE_SETTING := &"HUDScale"
const REDUCED_FLASHES_SETTING := &"ReducedFlashes"
const CAMERA_SHAKE_SETTING := &"CameraShakeStrength"
const FEEDBACK_QUALITY_SETTING := &"FeedbackQuality"
const HUD_SCALES := [1.0, 1.25, 1.5]
const CAMERA_SHAKE_STRENGTHS := [0.0, 0.5, 1.0]

var _owns_pause := false
var _settings_visible := false
var _overlay: ColorRect
var _menu_page: VBoxContainer
var _settings_page: VBoxContainer
var _history_page: VBoxContainer
var _history_label: Label
var _resolution: OptionButton
var _crt_strength: OptionButton
var _hud_scale: OptionButton
var _reduced_flashes: CheckButton
var _camera_shake: OptionButton
var _feedback_quality: OptionButton
var _feedback_preview_layer: PlayerDamageFeedbackLayer
var _fullscreen: CheckButton
var _mute: CheckButton
var _continuous_precharge: CheckButton
var _confirm_row: HBoxContainer
var _confirm_label: Label
var _confirm_remaining := 0.0
var _display_change_pending := false
var _previous_window_size := Vector2i.ZERO
var _previous_window_mode := Window.MODE_WINDOWED
var _previous_saved_resolution := Vector2i(1280, 720)
var _previous_saved_fullscreen := false
var _selected_resolution := Vector2i(1280, 720)
var _crt_overlay: CRTOverlay


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	hide()


func _process(delta: float) -> void:
	if not _display_change_pending:
		return
	_confirm_remaining = maxf(_confirm_remaining - delta, 0.0)
	_confirm_label.text = "保留此显示设置？（%d）" % ceili(_confirm_remaining)
	if _confirm_remaining <= 0.0:
		_revert_display_change()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_action_pressed("pause"):
		return
	if visible:
		if _display_change_pending:
			_revert_display_change()
		elif _settings_visible or (_history_page != null and _history_page.visible):
			_show_main_page()
		else:
			close_menu()
		get_viewport().set_input_as_handled()
	elif not get_tree().paused:
		open_menu()
		get_viewport().set_input_as_handled()


func open_menu() -> void:
	if visible:
		return
	_owns_pause = not get_tree().paused
	get_tree().paused = true
	show()
	_show_main_page()


func close_menu() -> void:
	if _display_change_pending:
		_revert_display_change()
	hide()
	if _owns_pause:
		get_tree().paused = false
		_owns_pause = false


func _build_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(CyberUITheme.BACKGROUND, 0.96)
	_overlay.theme = CyberUITheme.create_theme()
	add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := TerminalPanel.new()
	panel.title = "WJC COMBAT TERMINAL // SYSTEM"
	panel.custom_minimum_size = Vector2(520, 330)
	center.add_child(panel)
	var pages := VBoxContainer.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(pages)
	_menu_page = _build_main_page()
	pages.add_child(_menu_page)
	_settings_page = _build_settings_page()
	pages.add_child(_settings_page)
	_history_page = _build_history_page()
	pages.add_child(_history_page)
	_crt_overlay = CRTOverlay.new()
	_crt_overlay.name = "CRTOverlay"
	_crt_overlay.strength = _get_saved_crt_strength()
	add_child(_crt_overlay)


func _build_main_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 16)
	var title := Label.new()
	title.text = "暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	page.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 42
	page.add_child(spacer)
	var resume := Button.new()
	resume.text = "继续"
	resume.pressed.connect(close_menu)
	page.add_child(resume)
	var settings := Button.new()
	settings.text = "设置"
	settings.pressed.connect(_show_settings_page)
	page.add_child(settings)
	var history := Button.new()
	history.text = "最近通讯"
	history.pressed.connect(_show_history_page)
	page.add_child(history)
	page.set_meta("focus", resume)
	return page


func _build_settings_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	page.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	_add_section_title(content, "视频")
	_resolution = OptionButton.new()
	for value in RESOLUTIONS:
		_resolution.add_item("%d × %d" % [value.x, value.y])
	_resolution.item_selected.connect(_on_resolution_selected)
	_add_labeled_control(content, "分辨率", _resolution)
	_fullscreen = CheckButton.new()
	_fullscreen.text = "全屏"
	_fullscreen.toggled.connect(_on_fullscreen_toggled)
	content.add_child(_fullscreen)
	_crt_strength = OptionButton.new()
	for label in ["关闭", "低", "标准"]:
		_crt_strength.add_item(label)
	_crt_strength.item_selected.connect(_on_crt_strength_selected)
	_add_labeled_control(content, "显像管效果", _crt_strength)
	_hud_scale = OptionButton.new()
	for label in ["100%", "125%", "150%"]:
		_hud_scale.add_item(label)
	_hud_scale.item_selected.connect(_on_hud_scale_selected)
	_add_labeled_control(content, "战斗 HUD 缩放", _hud_scale)
	_reduced_flashes = CheckButton.new()
	_reduced_flashes.text = "降低闪烁"
	_reduced_flashes.toggled.connect(_on_reduced_flashes_toggled)
	content.add_child(_reduced_flashes)
	_camera_shake = OptionButton.new()
	for label in ["关闭", "低", "标准"]:
		_camera_shake.add_item(label)
	_camera_shake.item_selected.connect(_on_camera_shake_selected)
	_add_labeled_control(content, "镜头震动", _camera_shake)
	_feedback_quality = OptionButton.new()
	for label in ["低", "标准"]:
		_feedback_quality.add_item(label)
	_feedback_quality.item_selected.connect(_on_feedback_quality_selected)
	_add_labeled_control(content, "战斗特效质量", _feedback_quality)
	var preview_frame := PanelContainer.new()
	preview_frame.custom_minimum_size = Vector2(360.0, 92.0)
	_feedback_preview_layer = PlayerDamageFeedbackLayer.new()
	_feedback_preview_layer.name = "FeedbackPreview"
	preview_frame.add_child(_feedback_preview_layer)
	content.add_child(preview_frame)
	_confirm_row = HBoxContainer.new()
	_confirm_row.add_theme_constant_override("separation", 10)
	_confirm_label = Label.new()
	_confirm_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_row.add_child(_confirm_label)
	var keep := Button.new()
	keep.text = "保留"
	keep.pressed.connect(_confirm_display_change)
	_confirm_row.add_child(keep)
	var revert := Button.new()
	revert.text = "恢复"
	revert.pressed.connect(_revert_display_change)
	_confirm_row.add_child(revert)
	content.add_child(_confirm_row)
	_confirm_row.hide()
	_add_section_title(content, "音频")
	_add_volume_slider(content, "总音量", AudioServer.get_bus_index(&"Master"))
	_add_volume_slider(content, "音乐", AudioServer.get_bus_index(&"Music"))
	_add_volume_slider(content, "音效", AudioServer.get_bus_index(&"SFX"))
	_add_volume_slider(content, "战斗提示", AudioServer.get_bus_index(&"CombatCue"))
	var preview := Button.new()
	preview.text = "预览战斗反馈"
	preview.pressed.connect(_on_feedback_preview_pressed)
	content.add_child(preview)
	_mute = CheckButton.new()
	_mute.text = "全部静音"
	_mute.toggled.connect(_on_mute_toggled)
	content.add_child(_mute)
	_add_section_title(content, "AI 测试")
	_continuous_precharge = CheckButton.new()
	_continuous_precharge.text = "连续蓄力"
	_continuous_precharge.toggled.connect(_on_continuous_precharge_toggled)
	content.add_child(_continuous_precharge)
	var back := Button.new()
	back.text = "返回"
	back.pressed.connect(_show_main_page)
	page.add_child(back)
	page.set_meta("focus", _resolution)
	return page


func _build_history_page() -> VBoxContainer:
	var page := VBoxContainer.new()
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = "最近通讯"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	page.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	_history_label = Label.new()
	_history_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_history_label.add_theme_constant_override("line_spacing", 5)
	scroll.add_child(_history_label)
	var back := Button.new()
	back.text = "返回"
	back.pressed.connect(_show_main_page)
	page.add_child(back)
	page.set_meta("focus", back)
	return page


func _add_section_title(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	parent.add_child(label)


func _add_labeled_control(parent: VBoxContainer, text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(control)
	parent.add_child(row)


func _add_volume_slider(parent: VBoxContainer, text: String, bus_index: int) -> void:
	if bus_index < 0:
		return
	var slider := HSlider.new()
	slider.custom_minimum_size.x = 240
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = AppSettings.get_bus_volume(bus_index)
	slider.value_changed.connect(_on_volume_changed.bind(bus_index))
	_add_labeled_control(parent, text, slider)


func _show_main_page() -> void:
	_settings_visible = false
	_settings_page.hide()
	_history_page.hide()
	_menu_page.show()
	(_menu_page.get_meta("focus") as Control).grab_focus()


func _show_settings_page() -> void:
	_sync_settings_controls()
	_settings_visible = true
	_menu_page.hide()
	_history_page.hide()
	_settings_page.show()
	(_settings_page.get_meta("focus") as Control).grab_focus()


func _sync_settings_controls() -> void:
	var saved_resolution: Vector2i = PlayerConfig.get_config(AppSettings.VIDEO_SECTION, AppSettings.SCREEN_RESOLUTION, Vector2i(1280, 720))
	_selected_resolution = saved_resolution if saved_resolution in RESOLUTIONS else Vector2i(1280, 720)
	_resolution.select(RESOLUTIONS.find(_selected_resolution))
	_fullscreen.set_pressed_no_signal(AppSettings.is_fullscreen(get_window()))
	_resolution.disabled = _fullscreen.button_pressed
	_mute.set_pressed_no_signal(AppSettings.is_muted())
	_crt_strength.select(int(_get_saved_crt_strength()))
	var saved_scale := clampf(float(PlayerConfig.get_config(UI_SECTION, HUD_SCALE_SETTING, 1.0)), 1.0, 1.5)
	var scale_index := 0
	for index in HUD_SCALES.size():
		if absf(float(HUD_SCALES[index]) - saved_scale) < absf(float(HUD_SCALES[scale_index]) - saved_scale):
			scale_index = index
	_hud_scale.select(scale_index)
	_reduced_flashes.set_pressed_no_signal(bool(PlayerConfig.get_config(UI_SECTION, REDUCED_FLASHES_SETTING, false)))
	var saved_shake := clampf(float(PlayerConfig.get_config(UI_SECTION, CAMERA_SHAKE_SETTING, 1.0)), 0.0, 1.0)
	var shake_index := 0
	for index in CAMERA_SHAKE_STRENGTHS.size():
		if absf(float(CAMERA_SHAKE_STRENGTHS[index]) - saved_shake) < absf(float(CAMERA_SHAKE_STRENGTHS[shake_index]) - saved_shake):
			shake_index = index
	_camera_shake.select(shake_index)
	_feedback_quality.select(clampi(int(PlayerConfig.get_config(UI_SECTION, FEEDBACK_QUALITY_SETTING, 1)), 0, 1))
	var settings := get_node_or_null("/root/GameSettings")
	if settings != null:
		_continuous_precharge.set_pressed_no_signal(bool(settings.continuous_precharge))


func _show_history_page() -> void:
	_settings_visible = false
	_menu_page.hide()
	_settings_page.hide()
	_history_page.show()
	var hud := get_tree().get_first_node_in_group(&"combat_hud")
	var lines := PackedStringArray()
	if hud != null and hud.has_method("get_communication_history"):
		var history: Array[Dictionary] = hud.get_communication_history()
		for entry in history:
			lines.append("【%s】%s" % [String(entry.get("persona_name", "AI")), String(entry.get("text", ""))])
	_history_label.text = "暂无通讯记录" if lines.is_empty() else "\n\n".join(lines)
	(_history_page.get_meta("focus") as Control).grab_focus()


func _begin_display_change() -> void:
	if not _display_change_pending:
		_previous_window_size = get_window().size
		_previous_window_mode = get_window().mode
		_previous_saved_resolution = PlayerConfig.get_config(AppSettings.VIDEO_SECTION, AppSettings.SCREEN_RESOLUTION, _previous_window_size)
		_previous_saved_fullscreen = PlayerConfig.get_config(AppSettings.VIDEO_SECTION, AppSettings.FULLSCREEN, false)
	_display_change_pending = true
	_confirm_remaining = DISPLAY_CONFIRM_SECONDS
	_confirm_row.show()


func _on_resolution_selected(index: int) -> void:
	if index < 0 or index >= RESOLUTIONS.size():
		return
	_begin_display_change()
	_selected_resolution = RESOLUTIONS[index]
	AppSettings.set_resolution(_selected_resolution, get_window(), false)
	_preserve_unconfirmed_display_config()


func _on_fullscreen_toggled(enabled: bool) -> void:
	_begin_display_change()
	AppSettings.set_fullscreen_enabled(enabled, get_window())
	_resolution.disabled = enabled
	if not enabled:
		AppSettings.set_resolution(_selected_resolution, get_window(), false)
	_preserve_unconfirmed_display_config()


func _confirm_display_change() -> void:
	if not _display_change_pending:
		return
	_display_change_pending = false
	_confirm_row.hide()
	PlayerConfig.set_config(AppSettings.VIDEO_SECTION, AppSettings.SCREEN_RESOLUTION, _selected_resolution)
	PlayerConfig.set_config(AppSettings.VIDEO_SECTION, AppSettings.FULLSCREEN, _fullscreen.button_pressed)


func _revert_display_change() -> void:
	if not _display_change_pending:
		return
	_display_change_pending = false
	get_window().mode = _previous_window_mode
	if _previous_window_mode == Window.MODE_WINDOWED:
		get_window().size = _previous_window_size
	PlayerConfig.set_config(AppSettings.VIDEO_SECTION, AppSettings.SCREEN_RESOLUTION, _previous_saved_resolution)
	PlayerConfig.set_config(AppSettings.VIDEO_SECTION, AppSettings.FULLSCREEN, _previous_saved_fullscreen)
	_confirm_row.hide()
	_sync_settings_controls()


func _preserve_unconfirmed_display_config() -> void:
	# AppSettings listens to window-size changes, so keep previews out of the saved config.
	PlayerConfig.set_config(AppSettings.VIDEO_SECTION, AppSettings.SCREEN_RESOLUTION, _previous_saved_resolution)
	PlayerConfig.set_config(AppSettings.VIDEO_SECTION, AppSettings.FULLSCREEN, _previous_saved_fullscreen)


func _on_volume_changed(value: float, bus_index: int) -> void:
	AppSettings.set_bus_volume(bus_index, value)
	PlayerConfig.set_config(AppSettings.AUDIO_SECTION, AppSettings.get_audio_bus_name(bus_index).to_pascal_case(), value)


func _on_mute_toggled(enabled: bool) -> void:
	AppSettings.set_mute(enabled)
	PlayerConfig.set_config(AppSettings.AUDIO_SECTION, AppSettings.MUTE_SETTING, enabled)


func _on_crt_strength_selected(index: int) -> void:
	var next_strength := clampi(index, CRTOverlay.Strength.OFF, CRTOverlay.Strength.STANDARD) as CRTOverlay.Strength
	PlayerConfig.set_config(UI_SECTION, CRT_STRENGTH_SETTING, int(next_strength))
	for overlay_node in get_tree().get_nodes_in_group(&"crt_overlay"):
		if overlay_node is CRTOverlay:
			(overlay_node as CRTOverlay).set_strength(next_strength)


func _on_hud_scale_selected(index: int) -> void:
	if index < 0 or index >= HUD_SCALES.size():
		return
	var value := float(HUD_SCALES[index])
	PlayerConfig.set_config(UI_SECTION, HUD_SCALE_SETTING, value)
	for hud in get_tree().get_nodes_in_group(&"combat_hud"):
		if hud.has_method("set_hud_scale"):
			hud.set_hud_scale(value)


func _on_reduced_flashes_toggled(enabled: bool) -> void:
	PlayerConfig.set_config(UI_SECTION, REDUCED_FLASHES_SETTING, enabled)


func _on_camera_shake_selected(index: int) -> void:
	if index < 0 or index >= CAMERA_SHAKE_STRENGTHS.size():
		return
	PlayerConfig.set_config(UI_SECTION, CAMERA_SHAKE_SETTING, float(CAMERA_SHAKE_STRENGTHS[index]))


func _on_feedback_quality_selected(index: int) -> void:
	PlayerConfig.set_config(UI_SECTION, FEEDBACK_QUALITY_SETTING, clampi(index, 0, 1))


func _on_feedback_preview_pressed() -> void:
	if _feedback_preview_layer != null:
		_feedback_preview_layer.preview_feedback()
	var audio := get_node_or_null("../AudioCueManager") as AudioCueManager
	if audio != null:
		audio.preview_combat_cue()


func _on_continuous_precharge_toggled(enabled: bool) -> void:
	var settings := get_node_or_null("/root/GameSettings")
	if settings != null:
		settings.set_continuous_precharge(enabled)


func _exit_tree() -> void:
	if _display_change_pending:
		_revert_display_change()
	if _owns_pause:
		get_tree().paused = false


func _get_saved_crt_strength() -> CRTOverlay.Strength:
	var saved := int(PlayerConfig.get_config(UI_SECTION, CRT_STRENGTH_SETTING, CRTOverlay.Strength.LOW))
	return clampi(saved, CRTOverlay.Strength.OFF, CRTOverlay.Strength.STANDARD) as CRTOverlay.Strength
