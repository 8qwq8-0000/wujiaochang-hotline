class_name PersonaStatusPanel
extends Control

const PANEL_SIZE := Vector2(224, 72)
var _title: Label
var _detail: Label
var _meter: SegmentMeter
var _effects: RichTextLabel
var _accent := Color("55d9ff")

func _ready() -> void:
	size = PANEL_SIZE
	custom_minimum_size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = _label(Vector2(8, 3), 12)
	_detail = _label(Vector2(8, 23), 10)
	_meter = SegmentMeter.new()
	_meter.position = Vector2(8, 41)
	_meter.size = Vector2(208, 6)
	_meter.custom_minimum_size = _meter.size
	_meter.show_caption = false
	_meter.show_numeric = false
	_meter.segments = 16
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_meter)
	_effects = RichTextLabel.new()
	_effects.position = Vector2(8, 50)
	_effects.size = Vector2(208, 18)
	_effects.bbcode_enabled = true
	_effects.scroll_active = false
	_effects.add_theme_font_size_override("normal_font_size", 10)
	_effects.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_effects)

func _label(point: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = point
	label.size = Vector2(208, 18)
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func update_status(core: TalentCoreController, state: Dictionary, alive: bool) -> void:
	var id := core.current_persona_id
	var level := core.get_persona_level(id)
	var enabled := level > 0 and alive
	_accent = {TalentCoreController.DEEP_NINJA: Color("ff4b55"), TalentCoreController.LEGENDARY_MASTER: Color("55d9ff"), TalentCoreController.ROCK_VIGILANTE: Color("ffe34a")}.get(id, Color("55d9ff"))
	_title.text = "%s Lv.%d" % [core.get_persona_display_name(id), level] if level > 0 else "尚未选择人格"
	_title.add_theme_color_override("font_color", _accent if enabled else CyberUITheme.MUTED)
	_detail.add_theme_color_override("font_color", Color("d8e8e9"))
	_meter.meter_color = _accent
	_meter.visible = enabled
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.tooltip_text = ""
	if not enabled:
		_effects.text = ""
		_detail.text = "前往整备处选择人格" if alive else "行动失败"
		queue_redraw()
		return
	var tags: Array[String] = []
	match id:
		TalentCoreController.DEEP_NINJA:
			var locked := int(state.get("marked_target_id", 0)) != 0
			_detail.text = "已锁定猎痕目标" if locked else "正在寻找猎痕目标"
			_meter.maximum = 1
			_meter.value = 1 if locked else 0
			_add_tag(tags, core, &"blood_step", "踏血", float(state.get("blood_step_remaining", 0)) > 0)
			_add_tag(tags, core, &"shared_hunt_resonance", "风林山火", float(state.get("resonance_remaining", 0)) > 0)
			_add_tag(tags, core, &"gaze", "凝视", bool(state.get("gaze_active", false)))
			_add_tag(tags, core, &"ceaseless_hunt", "追猎", bool(state.get("chase_active", false)))
			_add_tag(tags, core, &"read_opening", "识隙", false)
			_add_tag(tags, core, &"borrowed_step", "借步", false)
		TalentCoreController.LEGENDARY_MASTER:
			var samples := int(state.get("analysis_samples", 0))
			var required := int(state.get("analysis_required", 2))
			_detail.text = "威胁解析 %d/%d%s" % [samples, required, "，已完成" if samples >= required else ""] if state.get("analysis_has_threat", false) else "等待敌人出招"
			_meter.maximum = required
			_meter.value = samples
			_add_tag(tags, core, &"calibrated_window", "格挡强化", bool(state.get("guard_window_active", false)))
			_add_tag(tags, core, &"master_loop", "宗师气场", float(state.get("master_loop_remaining", 0)) > 0)
			if state.get("ai_guard_active", false):
				tags.append(_tag("代行格挡中", true, "正在自动格挡；任何玩家输入都会立即中止。"))
			elif state.get("master_takeover_pending", false):
				tags.append(_tag("拆招待命", false, "正在等待可格挡的攻击；自动拆招后消耗 1 次接管。"))
			if not state.get("ai_guard_active", false) and not state.get("master_takeover_pending", false):
				_add_tag(tags, core, &"proxy_stance", "代拟架势", false)
				_add_tag(tags, core, &"proxy_counter", "代行一招", false)
			_add_tag(tags, core, &"refutation_reward", "反证收益", false)
			_add_tag(tags, core, &"open_model", "预测轨迹", int(state.get("prediction_source_count", 0)) > 0)
		TalentCoreController.ROCK_VIGILANTE:
			var feedback := float(state.get("rock_feedback", 0))
			_detail.text = "战斗反馈 %d%%" % int(feedback)
			_meter.maximum = 100
			_meter.value = feedback
			_meter.mouse_filter = Control.MOUSE_FILTER_PASS
			_meter.tooltip_text = "移速 +%d%%\n散热 +%d%%\n攻速 +%d%%" % [
				floori(float(state.get("rock_move_bonus_percent", 0.0)) + 0.501),
				floori(float(state.get("rock_cooling_bonus_percent", 0.0)) + 0.501),
				floori(float(state.get("rock_attack_speed_bonus_percent", 0.0)) + 0.501),
			]
			_add_tag(tags, core, &"seamless_switch", "无缝换台", bool(state.get("seamless_free_attack", false)))
			_add_tag(tags, core, &"encore_autopilot", "核武器", float(state.get("encore_remaining", 0)) > 0)
			_add_tag(tags, core, &"distortion_gain", "破音增益", bool(state.get("distortion_active", false)))
			_add_tag(tags, core, &"steady_beat", "稳定拍点", false)
			_add_tag(tags, core, &"overload_scream", "过载嘶鸣", bool(state.get("overload_scream_active", false)))
			_add_tag(tags, core, &"dual_channel_performance", "双通道", false)
	var next_text := "  ".join(tags) if not tags.is_empty() else "[color=#83949e]尚未选择天赋[/color]"
	if _effects.text != next_text:
		_effects.text = next_text
	queue_redraw()

func _add_tag(tags: Array[String], core: TalentCoreController, talent: StringName, title: String, active: bool) -> void:
	if talent in core.get_active_talents():
		tags.append(_tag(title, active, talent_tooltip(talent)))

func _tag(title: String, active: bool, description: String = "") -> String:
	var text := "[color=#%s]%s%s[/color]" % [_accent.to_html(false) if active else "83949e", "●" if active else "·", title]
	return "[hint=%s]%s[/hint]" % [description, text] if not description.is_empty() else text

static func talent_tooltip(talent: StringName) -> String:
	var entry: Array = PersonaRestFlow.TALENT_TEXT.get(talent, [])
	if entry.is_empty():
		return ""
	return "%s：%s" % [entry[0], entry[1]]

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, PANEL_SIZE), Color("071017", 0.82))
	draw_line(Vector2(0, 0), Vector2(0, PANEL_SIZE.y), Color(_accent, 0.8), 2)
