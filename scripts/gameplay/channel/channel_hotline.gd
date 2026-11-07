extends Node

const INTRO_TEXT := "广播停了。但你带回的残片里，还留着一通没发出去的电话。\n“……有人能听见吗？”"
const UNLOCK_TEXT := "第二结局「频道归还」已解锁。\n下次出击，第一层清场后留意出口附近。那扇没有光环的门，似乎还连着别的地方。"

var dialogue: ChannelDialogue
var _unlock_dialogue: ChannelDialogue
var _intro_pending := false


func _ready() -> void:
	_unlock_dialogue = preload("res://scripts/ui/channel_unlock_dialogue.gd").new()
	add_child(_unlock_dialogue)
	dialogue = _unlock_dialogue
	var store := get_node("/root/WarehouseStore")
	_intro_pending = not store.has_seen_channel_intro()
	for record: Dictionary in store.get_legacy_drinks():
		if record.get("ending", "") == "channel_returned":
			_intro_pending = false


func _process(_delta: float) -> void:
	if not _intro_pending or get_tree().paused:
		return
	var player := get_parent().get_node_or_null("Player") as PlayerController
	if player == null or not player.is_input_enabled() or player.inventory.is_open:
		return
	var flow := get_tree().current_scene.get_node_or_null("SceneFlow") as SceneContainerManager
	if flow != null and flow._is_loading:
		return
	_intro_pending = false
	_show_intro()


func _show_intro() -> void:
	dialogue = _unlock_dialogue
	_unlock_dialogue.open("接线员 / 通信中", INTRO_TEXT,
		[["听下去 [Enter]", _show_unlock]], _show_unlock)


func _show_unlock(error: String = "") -> void:
	var text := UNLOCK_TEXT
	if not error.is_empty():
		text += "\n\n" + error + "，请重试。"
	_unlock_dialogue.open("热线 / 新的行动路线", text,
		[["收到，返回仓库 [Enter]" if error.is_empty() else "重试保存 [Enter]", acknowledge_intro]], acknowledge_intro)


func acknowledge_intro() -> void:
	if not get_node("/root/WarehouseStore").acknowledge_channel_intro():
		_show_unlock(get_node("/root/WarehouseStore").error_message)
