extends SceneTree

# Run this script through the exported executable as well as the editor binary.
func _initialize() -> void:
	call_deferred("run_check")


func run_check() -> void:
	await process_frame
	var settings := root.get_node_or_null("GameSettings")
	if settings == null:
		push_error("GameSettings autoload is missing")
		quit(1)
		return
	var should_have_tools := OS.has_feature("editor") or OS.has_feature("debug")
	var has_tools := settings.get("test_tools") != null and settings.has_node("TestTools")
	if has_tools != should_have_tools:
		push_error("Test console build gate mismatch: expected %s, actual %s" % [should_have_tools, has_tools])
		quit(1)
		return
	print("Release build gate passed: test console present = ", has_tools)
	quit(0)
