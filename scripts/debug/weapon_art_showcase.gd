extends Node2D

var _views: Array[WeaponView] = []
var _elapsed := 0.0

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("101c28"))
	scale = Vector2.ONE * minf(get_viewport_rect().size.x / 1280.0, get_viewport_rect().size.y / 720.0)
	var ids := ["service_pistol", "scattergun", "rail_cannon"]
	var titles := ["腕锁制式手枪", "腕锁热能散射器", "腕锁电磁炮 · 美术预览"]
	_label("工业警用武器 // 持握、背包图标与枪口效果", Vector2(38, 24), 28)
	_label("左：背包图标    中：6 倍持握预览    右：游戏尺寸 / 1 倍", Vector2(38, 70), 18)
	for i in ids.size():
		var y := 165.0 + i * 170.0
		_label(titles[i], Vector2(38,y-36), 21)
		var icon := TextureRect.new()
		icon.texture = load("res://assets/art/weapons/placeholder/placeholder_"+ids[i]+"_unpainted.png") if i<2 else load("res://assets/art/weapons/placeholder/arm_lock_rail_cannon.png")
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		icon.position = Vector2(40,y)
		icon.size = Vector2(112,72)
		add_child(icon)
		for zoom in [6.0,1.0]:
			var view: WeaponView = load("res://scenes/weapons/"+ids[i]+".tscn").instantiate()
			view.position = Vector2(400 if zoom==6.0 else 890,y+(25 if zoom==6.0 else 78))
			view.scale = Vector2.ONE * zoom
			add_child(view)
			var data := WeaponComponentData.new()
			data.id = ids[i]
			view.configure(data)
			_views.append(view)

func _label(value: String, point: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = value
	label.position = point
	label.add_theme_font_override("font",CyberUITheme.FONT)
	label.add_theme_font_size_override("font_size",font_size)
	label.modulate = Color("d8ffe2")
	add_child(label)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 1.2:
		_elapsed = 0.0
		for view in _views:
			view.play_attack()
