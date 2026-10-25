extends SceneTree

var characters: Dictionary = {}
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func collect(path: String) -> void:
	for filename in DirAccess.get_files_at(path):
		if filename.get_extension() not in ["gd", "tscn", "tres", "json", "dtl", "dch", "csv"]:
			continue
		var text := FileAccess.get_file_as_string(path.path_join(filename))
		for index in text.length():
			var code := text.unicode_at(index)
			if (code >= 0x3400 and code <= 0x9fff) or (code >= 0xf900 and code <= 0xfaff):
				characters[code] = true
	for directory in DirAccess.get_directories_at(path):
		collect(path.path_join(directory))

func run() -> void:
	for path in ["res://scripts", "res://scenes", "res://resources", "res://data"]:
		collect(path)
	for path in ["res://resources/ui/chinese_font_12.tres", "res://resources/ui/chinese_font_16.tres"]:
		var font := load(path) as Font
		for code in characters:
			if not font.has_char(code):
				push_error("Missing Chinese character %s in %s" % [String.chr(code), path])
				failures += 1
	var label := Label.new()
	root.add_child(label)
	var default_font := label.get_theme_font("font")
	if default_font != load("res://resources/ui/chinese_font_12.tres"):
		push_error("Default UI font does not use bundled Chinese font")
		failures += 1
	for character in "远程返回训练营鼠标朝向":
		if not default_font.has_char(character.unicode_at(0)):
			push_error("Default UI font misses %s" % character)
			failures += 1
	label.queue_free()
	await process_frame
	print("Chinese font coverage: ", characters.size(), " unique characters across two fonts; failures: ", failures)
	quit(0 if failures == 0 else 1)
