extends CanvasLayer

@onready var health_label: Label = $Overlay/TopLeft/Health
@onready var heat_label: Label = $Overlay/TopLeft/Heat
@onready var mobility_label: Label = $Overlay/TopLeft/Mobility
@onready var weapon_label: Label = $Overlay/TopLeft/Weapon
@onready var guard_label: Label = $Overlay/TopLeft/Guard
@onready var objective_label: Label = $Overlay/Objective
@onready var message_label: Label = $Overlay/Message

var _player: PlayerController
var _message_tween: Tween


func _ready() -> void:
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.combat_message_requested.connect(show_message)
		events.floor_cleared.connect(func() -> void: objective_label.text = "本层已清理：前往出口")
	var run_manager := get_node_or_null("/root/RunManager")
	if run_manager != null:
		run_manager.mandatory_enemy_count_changed.connect(_on_enemy_count_changed)
	set_process(true)


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as PlayerController
		if is_instance_valid(_player):
			_bind_player(_player)
	if not is_instance_valid(_player):
		return
	health_label.text = "耐久  %d / %d" % [_player.health.current_health, _player.health.max_health]
	heat_label.text = "热量  %03d / %03d%s" % [roundi(_player.heat.current_heat), roundi(_player.heat.max_heat), "  过热" if _player.heat.is_overheated else ""]
	var mode := _player.mobility.get_current_mode()
	mobility_label.text = "机动  %s  [1-4]" % mode.display_name
	var weapon := _player.weapons.get_current_weapon()
	weapon_label.text = "武装  %s  [滚轮]" % (weapon.display_name if weapon != null else "无")
	guard_label.text = "格挡  %s" % _guard_state_name(_player.guard.state)


func _bind_player(player: PlayerController) -> void:
	player.tree_exiting.connect(func() -> void: _player = null)


func _on_enemy_count_changed(remaining: int) -> void:
	objective_label.text = "必杀目标剩余：%d" % remaining if remaining > 0 else "区域清理完成"


func show_message(text: String, color: Color = Color.WHITE) -> void:
	message_label.text = text
	message_label.modulate = color
	message_label.modulate.a = 1.0
	if _message_tween != null and _message_tween.is_valid():
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(1.1)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.4)


func _guard_state_name(state: GuardComponent.State) -> String:
	match state:
		GuardComponent.State.STARTUP:
			return "起手"
		GuardComponent.State.PERFECT:
			return "完美窗口"
		GuardComponent.State.NORMAL:
			return "普通窗口"
		GuardComponent.State.RECOVERY:
			return "后摇"
		_:
			return "就绪"
