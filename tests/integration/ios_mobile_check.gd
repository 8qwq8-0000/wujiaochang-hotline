extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var mobile := root.get_node("MobileInput")
	var viewport := Rect2(0, 0, 844, 390)
	# Landscape iPhone: 47pt left/right notch inset, 21pt home-indicator inset.
	var safe: Rect2 = mobile.safe_rect_for_display(viewport, Vector2(2532, 1170), Rect2i(141, 0, 2250, 1107))
	check(safe.is_equal_approx(Rect2(53, 6, 738, 357)), "retina pixels map to landscape UI coordinates with home indicator clearance")
	var left: Rect2 = mobile.safe_rect_for_display(viewport, Vector2(2532, 1170), Rect2i(141, 0, 2391, 1107))
	var right: Rect2 = mobile.safe_rect_for_display(viewport, Vector2(2532, 1170), Rect2i(0, 0, 2391, 1107))
	check(is_equal_approx(left.position.x, 53) and is_equal_approx(right.end.x, 791), "either landscape notch side is respected")
	check(mobile.safe_rect_for_display(viewport, Vector2.ZERO, Rect2i()).is_equal_approx(viewport.grow(-6)), "unavailable safe-area data uses the viewport")
	var ipad: Rect2 = mobile.safe_rect_for_display(Rect2(0, 0, 1024, 768), Vector2(2048, 1536), Rect2i(0, 48, 2048, 1448))
	check(ipad.position.y == 30 and ipad.end.y == 742, "iPad top and bottom safe insets scale correctly")
	var preset := ConfigFile.new()
	check(preset.load("res://export_presets.cfg") == OK, "export configuration loads")
	check(preset.get_value("preset.2", "platform") == "iOS", "native iOS export is configured")
	check(preset.get_value("preset.2.options", "application/export_project_only"), "shared preset exports a project without attempting signing")
	check(preset.get_value("preset.2.options", "application/app_store_team_id") == "0000000000", "shared preset contains only the unsigned placeholder team")
	check(preset.get_value("preset.2.options", "application/bundle_identifier") == "com.wujiaochang.hotline", "iOS app has a stable bundle identifier")
	check(ProjectSettings.get_setting("display/window/handheld/orientation") == 4, "both landscape orientations are supported")
	check(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile") == "gl_compatibility", "mobile renderer is compatible with the iOS simulator")
	check(preset.get_value("preset.1", "platform") == "Android", "Android export remains present")
	print("iOS mobile checks: %d; failures: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)
