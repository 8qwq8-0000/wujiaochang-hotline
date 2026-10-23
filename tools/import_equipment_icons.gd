extends SceneTree

## Package generated source art into transparent icons; keep the source intact.
const SOURCE_DIR := "res://art_sources/ai_drafts/equipment_icons_v1/"
const TARGET_DIR := "res://assets/art/items/equipment_v1/"
const IDS := ["armor", "smart_fire", "explosive_magazine", "tactical_coprocessor", "optical_intruder", "kill_heat_sink", "heat_threshold_pulser", "compound_cyberware"]

func _initialize() -> void:
	var failures := 0
	for id in IDS:
		var image := Image.load_from_file(SOURCE_DIR + id + ".png")
		if image == null or image.is_empty():
			failures += 1
			continue
		image.convert(Image.FORMAT_RGBA8)
		var cropped := image.get_region(image.get_used_rect())
		for canvas_size in [32, 64]:
			var inner_size: int = canvas_size - canvas_size / 8
			var ratio := float(inner_size) / maxf(cropped.get_width(), cropped.get_height())
			var scaled := cropped.duplicate() as Image
			scaled.resize(maxi(1, roundi(cropped.get_width() * ratio)), maxi(1, roundi(cropped.get_height() * ratio)), Image.INTERPOLATE_NEAREST)
			var result := Image.create(canvas_size, canvas_size, false, Image.FORMAT_RGBA8)
			result.fill(Color.TRANSPARENT)
			var origin := Vector2i((canvas_size - scaled.get_width()) / 2, (canvas_size - scaled.get_height()) / 2)
			result.blit_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()), origin)
			var suffix := "" if canvas_size == 32 else "_64"
			if result.save_png(TARGET_DIR + id + suffix + ".png") != OK:
				failures += 1
	print("Equipment icon packaging failures: ", failures)
	quit(0 if failures == 0 else 1)
