@tool
extends McpTestSuite


func suite_name() -> String:
	return "cyber_ui"


func test_theme_uses_confirmed_palette_and_font() -> void:
	var theme := CyberUITheme.create_theme()
	assert_true(theme.default_font != null)
	assert_eq(theme.default_font_size, 12)
	assert_eq(theme.get_color(&"font_color", &"Label"), CyberUITheme.PHOSPHOR)
	assert_eq(theme.get_color(&"font_color", &"TerminalWarningLabel"), CyberUITheme.WARNING)
	assert_eq(theme.get_color(&"font_color", &"TerminalDangerLabel"), CyberUITheme.DANGER)


func test_reusable_components_keep_pixel_scale_contract() -> void:
	var panel := track(TerminalPanel.new()) as TerminalPanel
	var meter := track(SegmentMeter.new()) as SegmentMeter
	var notice := track(TerminalNotice.new()) as TerminalNotice
	panel.cut_size = 6.0
	meter.segments = 10
	meter.set_meter(75, 100)
	notice.set_notice("ALERT", "同房间敌人已响应", CyberUITheme.WARNING)
	assert_eq(panel.cut_size, 6.0)
	assert_eq(meter.segments, 10)
	assert_eq(meter.value, 75.0)
	assert_eq(notice.accent_color, CyberUITheme.WARNING)


func test_crt_overlay_exposes_three_accessibility_levels() -> void:
	assert_eq(CRTOverlay.Strength.size(), 3)
	assert_true(load("res://shaders/ui/crt_ui.gdshader") is Shader)
	var overlay := track(CRTOverlay.new()) as CRTOverlay
	overlay.set_strength(CRTOverlay.Strength.OFF)
	assert_eq(overlay.strength, CRTOverlay.Strength.OFF)
