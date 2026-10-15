extends CanvasLayer

@onready var health_label: Label = $Overlay/TopLeft/Health
@onready var heat_label: Label = $Overlay/TopLeft/Heat
@onready var mobility_label: Label = $Overlay/TopLeft/Mobility
@onready var weapon_label: Label = $Overlay/TopLeft/Weapon
@onready var guard_label: Label = $Overlay/TopLeft/Guard
@onready var objective_label: Label = $Overlay/Objective
@onready var notice_queue: CombatNoticeQueue = $Overlay/NoticeQueue

var _player: PlayerController


func _ready() -> void:
	var events := get_node_or_null("/root/CombatEvents")
	if events != null:
		events.combat_message_requested.connect(show_message)
		events.combat_notice_requested.connect(_on_notice_requested)
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
	var health_state := _player.get_health_state()
	var heat_state := _player.get_heat_state()
	health_label.text = "耐久  %d / %d" % [health_state.current, health_state.maximum]
	heat_label.text = "热量  %03d / %03d%s" % [roundi(heat_state.current), roundi(heat_state.maximum), "  过热" if heat_state.overheated else ""]
	mobility_label.text = "机动  %s" % _player.get_mobility_display_name()
	weapon_label.text = "武装 %d/2  %s [Q/滚轮]" % [_player.weapons.current_index + 1, _player.get_weapon_display_name()]
	guard_label.text = "格挡  %s" % _guard_state_name(_player.get_guard_state())


func _bind_player(player: PlayerController) -> void:
	player.tree_exiting.connect(func() -> void: _player = null)


func _on_enemy_count_changed(remaining: int) -> void:
	objective_label.text = "必杀目标剩余：%d" % remaining if remaining > 0 else "区域清理完成"


func show_message(text: String, color: Color = Color.WHITE) -> void:
	notice_queue.push_legacy(text, color)


func _on_notice_requested(notice: CombatNotice) -> void:
	notice_queue.push_notice(notice)


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
