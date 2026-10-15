extends Node2D

@export var equip_test_weapons := true
@export var primary_id := "test_conductive_pistol"
@export var secondary_id := "test_electric_pistol"

signal room_cleared
var cleared := false
var remaining_targets := 3
@onready var player: PlayerController = $Player

func _ready() -> void:
	get_node("/root/RunManager").begin_run()
	get_node("/root/RunManager").set_scene_payload({})
	var back := Button.new()
	back.name = "ReturnWarehouse"
	back.position = Vector2(498,333)
	back.size = Vector2(122,23)
	back.text = "返回仓库"
	back.add_theme_font_size_override("font_size",13)
	back.process_mode = Node.PROCESS_MODE_ALWAYS
	back.pressed.connect(_return_warehouse)
	$UI.add_child(back)
	player.get_node("Camera2D").enabled = false
	_fit_viewport()
	get_viewport().size_changed.connect(_fit_viewport)
	if equip_test_weapons:
		var inventory := player.inventory
		inventory.backpack.add_item(inventory.weapon_slot.get_item())
		for entry in [{"slot":inventory.weapon_slot,"id":primary_id},{"slot":inventory.secondary_weapon_slot,"id":secondary_id}]:
			var item := InventoryItem.new(ComponentInventory.PROTOTYPES,entry.id)
			inventory._assign_instance_id(item)
			entry.slot.equip(item)
		inventory._apply_equipment()
		inventory.changed.emit()
	for index in 3:
		var enemy: EnemyController = load("res://scenes/actors/enemies/enemy.tscn").instantiate()
		enemy.profile = load("res://resources/enemies/melee_pressure.tres").duplicate()
		enemy.profile.max_health = 8
		enemy.profile.patrol_enabled = false
		enemy.position = Vector2(350+index*75,165)
		enemy.stationary_test_target = true
		$Targets.add_child(enemy)
		enemy.defeated.connect(_on_target_defeated)
		var label := Label.new()
		label.position = Vector2(-30,22)
		label.text = "标靶 %d" % (index+1)
		label.add_theme_font_size_override("font_size",12)
		enemy.add_child(label)
	get_node("/root/RunManager").set_mandatory_enemy_count(remaining_targets)

func _on_target_defeated(_enemy: EnemyController, _mandatory: bool) -> void:
	remaining_targets -= 1
	get_node("/root/RunManager").set_mandatory_enemy_count(remaining_targets)
	if remaining_targets == 0:
		cleared = true
		room_cleared.emit()
		get_node("/root/CombatEvents").publish_room_cleared(self)

func _process(_delta: float) -> void:
	var buff: RoomBuffComponent = player.get_node("RoomBuffComponent")
	var name: String = RoomBuffComponent.TITLES.get(buff.active_buff,"无")
	$UI/Status.text = "耐久 %d/3  热量 %.0f  %s  区域增益：%s" % [player.health.current_health,player.heat.current_heat,player.get_weapon_display_name(),name]

func _draw() -> void:
	draw_rect(Rect2(0,0,640,360),Color("101c28"))
	for x in range(16,640,24):
		draw_line(Vector2(x,80),Vector2(x,325),Color("203341"))
	for y in range(80,326,24):
		draw_line(Vector2(16,y),Vector2(624,y),Color("203341"))
	draw_rect(Rect2(16,80,608,245),Color("446371"),false,2)

func _fit_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	var factor := minf(viewport_size.x/640.0,viewport_size.y/360.0)
	$Camera2D.zoom = Vector2.ONE*factor
	$UI.transform = Transform2D(0,Vector2.ONE*factor,0,(viewport_size-Vector2(640,360)*factor)/2)

func _return_warehouse() -> void:
	get_tree().paused = false
	player.set_input_enabled(false)
	get_node("/root/RunManager").begin_run()
	get_node("/root/RunManager").set_scene_payload({})
	get_tree().call_deferred("change_scene_to_file", "res://scenes/bootstrap/warehouse_main.tscn")
