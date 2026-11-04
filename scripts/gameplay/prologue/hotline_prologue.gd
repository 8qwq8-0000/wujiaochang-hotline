class_name HotlinePrologue
extends Node2D

enum Step { BRIEFING, DODGE, PARRY, GUN_PICKUP, EQUIP, SUPPLIES, WAVE, RECOVER, CODEX, SYNTHESIZE, MINI_BOSS, TRANSFER }

const WAREHOUSE := "res://scenes/levels/base/warehouse.tscn"
const ENEMY := preload("res://scenes/actors/enemies/enemy.tscn")
const PICKUP := preload("res://scenes/items/component_pickup.tscn")
const SKIP_HOLD_SECONDS := 1.2
const STEP_TRANSITION_SECONDS := 1.5
const MOVE_SPEED_SCALE := 0.8
const PROJECTILE_SPEED_SCALE := 0.85
const CODEX_POINT := Vector2(1140, 190)
const FORGE_POINT := Vector2(1250, 174)
const BUFF_POINT := Vector2(708, 152)
const BOMB_SCENE := preload("res://scenes/environment/fuel_barrel.tscn")
const BUFF_SCENE := preload("res://scenes/environment/power_box.tscn")
const CYAN := Color("75e8df")
const AMBER := Color("f3c579")

var step: Step = Step.BRIEFING
var targets: Array[EnemyController] = []
var recovery_pickups: Array[ComponentPickup] = []
var gun_pickup: ComponentPickup
var _gun_drop_point := Vector2(594, 196)
var panel: CanvasLayer
var dialogue_completed := false
var _inventory_opened := false
var _codex_actor: Area2D
var _forge_actor: Area2D
var _boss_status: Label
var _boss_meter: ColorRect
var mini_boss: EnemyController
var chest: Inventory
var upgrade_panel: CanvasLayer
var last_synthesis_result: InventoryItem
var bomb: FuelBarrel
var boss_bomb: FuelBarrel
var boss_buff_box: PowerBox
var buff_box: PowerBox
var cleared := false
var _synthesis_done := false
var _line_age := 0.0
var _intro_backdrop: CyberSignalBackdrop
var _intro_continue: Button
var _dialogue_panel: CyberDialoguePanel
var _skip_track: ColorRect
var _gates: Array[StaticBody2D] = []
var _skip_key := false
var _skip_mouse := false
var _skip_elapsed := 0.0
var _leaving := false
var _pending_step := -1
var _transition_remaining := 0.0
var _transfer_remaining := 0.0
var _hit_flash := 0.0
var _dialogue_queue: Array[Dictionary] = []
var _dialogue_remaining := 0.0
var _owns_dialogue_pause := false
var _heat_tip: Label
var _heat_tip_remaining := 0.0
var _warned_high_heat := false
var _warned_overheat := false
var show_combat_hud := false
var _hud_process_mode := Node.PROCESS_MODE_INHERIT
var _hud: CanvasLayer
var _layout: Control
var _speaker: Label
var _dialogue: Label
var _skip_progress: ColorRect
var _skip_button: Button
var _target_marker: Label
var _flow: SceneContainerManager
var _radio: AudioStreamPlayer

@onready var player: PlayerController = $Player
@onready var camera: Camera2D = $Camera2D
@onready var ui: CanvasLayer = $UI


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	child_entered_tree.connect(_pause_gameplay_child)
	for child in get_children():
		_pause_gameplay_child(child)
	add_to_group("prologue")
	# Hide normal combat/persona prompts, without posing as a warehouse.
	add_to_group("intermission")
	add_to_group("combat_rooms")


func _pause_gameplay_child(child: Node) -> void:
	# Radio/UI stay live during dialogue; actors, projectiles and hazards freeze.
	if child is Node2D:
		child.process_mode = Node.PROCESS_MODE_PAUSABLE


func _ready() -> void:
	_flow = get_parent().get_parent().get_node_or_null("SceneFlow") as SceneContainerManager
	if _flow != null:
		_flow.load_failed.connect(_on_load_failed)
	player.camera.enabled = false
	camera.make_current()
	# A fresh practice actor owns its equipment; the saved loadout is never imported.
	player.inventory.set_process_input(false)
	player.inventory.weapon_slot.clear()
	player.inventory.secondary_weapon_slot.clear()
	player.inventory.set("_has_picked_up_weapon", true)
	player.inventory._apply_equipment()
	player.inventory.panel.get("_overlay").visibility_changed.connect(_on_inventory_visibility)
	player.heat.heat_changed.connect(_on_tutorial_heat_changed)
	player.heat.overheated.connect(_on_tutorial_overheated)
	player.health.fatal_damage_interceptor = _prevent_tutorial_death
	player.health.damaged.connect(_on_player_damaged)
	_hud = get_tree().current_scene.get_node_or_null("CombatHUD") as CanvasLayer
	if _hud != null:
		_hud_process_mode = _hud.process_mode
		_hud.process_mode = Node.PROCESS_MODE_ALWAYS
		_hud.show()
	_build_geometry()
	_build_ui()
	chest = Inventory.new()
	chest.protoset = ComponentInventory.PROTOTYPES
	add_child(chest)
	panel = preload("res://scripts/ui/codex_dialogue_panel.gd").new()
	panel.player = player
	panel.location_text = "Codex · 接入通道合成师"
	panel.lines.assign([
		"你就是刚接上线的那位吧？我是 Codex。你带来的这些装备刚好能用，要不要试试旁边的合成台？",
		"武器和防具都可以用两件同类型、同品质的来合成。想保留外形的放主体槽，另一件放材料槽。确认后会消耗原来的两件，成品回到主体的位置。",
		"义体也能合，不过要用不同模块，最多凑四种，相同模块不能重复合。你现在这件可以先装上试试，等捡到别的模块再来找我。",
		"你手里和背包里各有一把手枪，正好能试一次。合成会提升品质、获得更好的词条，基础伤害还是原来的数值。台子给你打开了，合好按 Esc 回来，咱们再往前走。",
	])
	panel.completed.connect(_on_codex_completed)
	add_child(panel)
	panel.get("_overlay").visibility_changed.connect(_on_codex_visibility)
	upgrade_panel = CanvasLayer.new()
	upgrade_panel.set_script(preload("res://scripts/ui/synthesis_panel.gd"))
	upgrade_panel.room = self
	upgrade_panel.heading_text = "序章 / 装备合成"
	add_child(upgrade_panel)
	_radio = AudioStreamPlayer.new()
	_radio.stream = preload("res://assets/audio/ui/hotline_connect.wav")
	_radio.volume_db = -14.0
	add_child(_radio)
	get_node("/root/RunManager").set_mandatory_enemy_count(0)
	var sound := get_node_or_null("/root/SoundManager")
	if sound != null:
		sound.play_music(preload("res://assets/audio/music/lobby/lobby_theme.ogg"), 0.75)
	_set_step(Step.BRIEFING)


func _exit_tree() -> void:
	if _owns_dialogue_pause:
		get_tree().paused = false
	if is_instance_valid(_hud):
		_hud.process_mode = _hud_process_mode
		_hud.show()


func _build_geometry() -> void:
	_wall(Rect2(24, 96, 2224, 8))
	_wall(Rect2(24, 264, 2224, 8))
	_wall(Rect2(24, 96, 8, 176))
	_wall(Rect2(2240, 96, 8, 176))
	for x in [452, 772, 1040, 1430]:
		_gates.append(_wall(Rect2(x, 104, 8, 160)))
	var navigation := NavigationRegion2D.new()
	var polygon := NavigationPolygon.new()
	polygon.vertices = PackedVector2Array([Vector2(44, 116), Vector2(2228, 116), Vector2(2228, 252), Vector2(44, 252)])
	polygon.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	navigation.navigation_polygon = polygon
	add_child(navigation)
	_target_marker = _label("", 12, AMBER)
	_target_marker.size = Vector2(170, 22)
	_target_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_target_marker)


func _wall(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body


func _label(value: String, font_size := 12, color := Color("ebf1f3")) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", CyberUITheme.FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("090f18"))
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _build_ui() -> void:
	_intro_backdrop = CyberSignalBackdrop.new()
	_intro_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_intro_backdrop)
	_layout = Control.new()
	_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_layout)
	_skip_button = Button.new()
	_skip_button.text = "按住跳过序章"
	_skip_button.tooltip_text = "Esc 跳过当前教学；按住此按钮跳过整个序章"
	_skip_button.position = Vector2(460, 10)
	_skip_button.size = Vector2(166, 24)
	CyberDialoguePanel.style_button(_skip_button)
	_skip_button.focus_mode = Control.FOCUS_NONE
	_skip_button.button_down.connect(func() -> void: _skip_mouse = true)
	_skip_button.button_up.connect(func() -> void: _skip_mouse = false)
	_layout.add_child(_skip_button)
	_skip_track = ColorRect.new()
	_skip_track.color = Color("1b3039")
	_skip_track.position = Vector2(460, 36)
	_skip_track.size = Vector2(166, 3)
	_skip_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout.add_child(_skip_track)
	_skip_progress = ColorRect.new()
	_skip_progress.color = CYAN
	_skip_progress.position = Vector2(460, 36)
	_skip_progress.size = Vector2(0, 3)
	_skip_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout.add_child(_skip_progress)
	_dialogue_panel = CyberDialoguePanel.new()
	var panel := _dialogue_panel
	panel.title = "HOTLINE / 公共频道                 Enter 继续"
	panel.gui_input.connect(_on_radio_click)
	panel.accent_color = CYAN
	panel.position = Vector2(14, 279)
	panel.size = Vector2(612, 70)
	_layout.add_child(panel)
	# TerminalPanel._ready() defaults to click-through; override after entering the tree.
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	_speaker = _label("", 11, CYAN)
	column.add_child(_speaker)
	_dialogue = _label("", 13)
	_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_dialogue)
	_heat_tip = _label("", 11, AMBER)
	_heat_tip.position = Vector2(14, 304)
	_heat_tip.size = Vector2(380, 36)
	_heat_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_heat_tip.hide()
	_layout.add_child(_heat_tip)
	_boss_status = _label("", 12, AMBER)
	_boss_status.position = Vector2(460, 47)
	_layout.add_child(_boss_status)
	_boss_meter = ColorRect.new()
	_boss_meter.color = Color("ef4ca8")
	_boss_meter.position = Vector2(460, 66)
	_boss_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout.add_child(_boss_meter)
	_intro_continue = Button.new()
	_intro_continue.text = "Enter / 继续"
	_intro_continue.position = Vector2(414, 234)
	_intro_continue.size = Vector2(158, 26)
	CyberDialoguePanel.style_button(_intro_continue, true)
	_intro_continue.focus_mode = Control.FOCUS_NONE
	_intro_continue.pressed.connect(_advance_intro)
	_layout.add_child(_intro_continue)
	for control in [_skip_button, _skip_track, _skip_progress]:
		_layout.move_child(control, _layout.get_child_count() - 1)


func _set_step(value: Step) -> void:
	step = value
	_pending_step = -1
	_transition_remaining = 0.0
	var intro := step == Step.BRIEFING
	show_combat_hud = not intro
	_intro_backdrop.visible = intro
	_intro_continue.visible = intro
	$Art.visible = not intro
	player.visible = not intro
	_target_marker.visible = not intro
	player.set_input_enabled(not intro and step != Step.TRANSFER)
	_dialogue_panel.compact = not intro
	_dialogue_panel.position = Vector2(32, 108) if intro else Vector2(14, 272)
	_dialogue_panel.size = Vector2(576, 198) if intro else Vector2(612, 78)
	_dialogue_panel.title = "五角场热线 / 信号接入" if intro else "AI 接线员 / 通信中  [Enter 或点击继续]"
	_dialogue.add_theme_font_size_override("font_size", 17 if intro else 13)
	_skip_button.position = Vector2(52, 268) if intro else Vector2(460, 10)
	_intro_continue.position = Vector2(414, 268)
	_intro_continue.size = Vector2(174, 26)
	_skip_track.position = Vector2(52, 300) if intro else Vector2(460, 36)
	_skip_progress.position = _skip_track.position
	var objectives := [
		["", "", Vector2.ZERO, ""],
		["01 / 突进冲撞击杀", "WASD＋空格突进 · 避开攻击并撞向敌人", Vector2(280, 194), "空格 / 突进撞击敌人"],
		["02 / 空手盾反击杀", "鼠标朝向来弹 · 命中前按右键，将子弹弹回击杀敌人", Vector2(574, 194), "右键 / 盾反击杀哨兵"],
		["03 / 拾取掉落手枪", "靠近敌人掉落的手枪，按 E 放入背包", Vector2(594, 196), "E / 拾取手枪"],
		["04 / 打开背包装备武器", "按 Tab 打开背包 · 点击手枪或拖到武器槽 · Tab 关闭", Vector2(640, 194), "Tab / 装备手枪"],
		["08 / 领取战斗增益", "靠近入口的增益箱按 E · 领取后开始战斗", BUFF_POINT, "E / 领取攻速增益"],
		["09 / 使用手枪清除敌人", "点击左键射击 · 炸药箱可引爆，增益箱按 E 使用", Vector2(900, 194), "消灭三名敌人 / 留意环境箱"],
		["10 / 回收战利品", "按 E 拾取手枪、义体和防弹背心", Vector2(948, 194), "E / 回收三件装备"],
		["11 / 与 Codex 交谈", "前方维修站已出现 · 靠近 Codex 按 E，听取合成说明", CODEX_POINT, "E / 与 Codex 对话"],
		["12 / 合成装备", "两件同品质手枪放入主体和材料槽 · 确认合成", FORGE_POINT, "E / 打开合成台"],
		["13 / 击败中继守卫", "使用武器、盾反和突进突破最后封锁", Vector2(1850, 194), "小 Boss / 中继守卫"],
		["序章完成 / 准备传送", "接线员正在接通仓库……", Vector2(1850, 194), "传送至仓库"],
	]
	var definition: Array = objectives[int(step)]
	_target_marker.position = definition[2] + Vector2(-85, 34)
	_target_marker.text = definition[3]
	var thresholds := [Step.PARRY, Step.WAVE, Step.CODEX, Step.MINI_BOSS]
	for index in _gates.size():
		_gates[index].collision_layer = 0 if step >= thresholds[index] else 1
	_boss_status.visible = step == Step.MINI_BOSS
	_boss_meter.visible = step == Step.MINI_BOSS
	match step:
		Step.BRIEFING:
			_say("公共频道 / 大肥鱼", "这里是大肥鱼。您的求助正在处理中，请耐心等待。您的求助正在处理中……")
			_say("接线员 / 信号接入", "……喂？听得见吗？总算接通了！先别挂，刚才一直是那个声音，我还以为这条线也断了。")
			_say("接线员", "铁人叛乱以后，上海还留着不少失控的自治机械。有些街区恢复了联系，有些地方却一直没有消息，五角场这边也是。")
			_say("接线员", "你面前这座综合楼，已经被机械共同体占了。我们偶尔能收到楼里的求救，可每次还没听清，就又被盖过去了。里面到底怎么样，到现在也没人说得清。")
			_say("接线员", "盖住他们的，就是刚才那个“大肥鱼”。它霸着公共频道，不停地回复“正在处理”。听着像有人管，其实真正求救的人，连一句完整的话都传不出来。")
			_say("接线员", "我沿着干扰信号查过，源头在综合楼顶的 DS 中枢。如果能把它关掉，楼里的声音就有机会传出来。只是通往楼顶的路，还得一层一层打通。")
			_say("接线员", "好在去仓库的通道还能接上。那边可以休整，路上的装备也能收来用。Codex 就在途中，她会帮忙处理零件，你不用一下子弄懂所有东西。")
			_say("接线员 / 保持通话", "你手边暂时没枪，不过冲刺和盾反还能用。我们先走过眼前这段，找到装备，再去仓库歇脚。准备好了就出发吧，我会一直保持通话。")
		Step.DODGE:
			var target := _spawn_enemy(Vector2(316, 196), false)
			target.health.fatal_damage_interceptor = _require_dash_finish
			_say("接线员", "前面有个近战机械，正好试试冲刺。按住方向再按空格，就能冲过去撞伤它，也能趁机躲开攻击。别担心，我看着呢。")
		Step.PARRY:
			_clear_targets()
			_clear_projectiles()
			var sentry := _spawn_enemy(Vector2(594, 186), true)
			sentry.health.fatal_damage_interceptor = _require_reflected_finish
			sentry.defeated.connect(_on_parry_defeated)
			_say("接线员", "干得好，路通了！下一个会开枪，我们可以借它的子弹。鼠标朝着来弹，快打中你时按右键，就能把子弹弹回去，这就是盾反。")
		Step.GUN_PICKUP:
			_clear_targets()
			gun_pickup = _drop_item("pistol", _gun_drop_point)
			_target_marker.position = _gun_drop_point + Vector2(-85, 34)
			_say("接线员", "漂亮，真弹回去了！你看，它还掉了一把手枪。走近按 E，就能把枪捡起来。")
		Step.EQUIP:
			player.inventory.set_process_input(true)
			_say("接线员", "这下有枪用了！按 Tab 打开背包，点一下刚捡的手枪就能装上，拖到武器槽也可以。装好再按 Tab 回来，我们一起试试。")
		Step.SUPPLIES:
			_clear_projectiles()
			player.heat.reduce_heat(1000)
			bomb = BOMB_SCENE.instantiate() as FuelBarrel
			bomb.position = Vector2(880, 138)
			add_child(bomb)
			buff_box = BUFF_SCENE.instantiate() as PowerBox
			buff_box.buff_choice = 1
			buff_box.position = BUFF_POINT
			add_child(buff_box)
			_say("接线员", "前面还有几个敌人，不过旁边的箱子能帮上忙。炸药箱挨枪就会爆炸，还会留下一片火。等敌人靠近时引爆就很合适，自己可别站得太近。")
			_say("接线员", "近处这个是增益箱，走近按 E 就能领。里面是攻速增益，能让你在本区域射得更快。拿好以后，我就帮你打开前面的门。")
		Step.WAVE:
			for index in 3:
				var enemy := _spawn_enemy(Vector2(842 + index * 70, 166 + (index % 2) * 52), index == 1)
				if index == 0:
					enemy.health.fatal_damage_interceptor = _require_pistol_finish
				enemy.defeated.connect(_on_wave_defeated.bind(["pistol", "smart_fire", "armor"][index]))
			_say("接线员", "门开了！前面三个都在，试试刚装好的枪吧。鼠标瞄准，点左键开火。左上角的热量会随射击上涨，别一直打到过热。旁边那个炸药箱，现在也能派上用场了。")
		Step.RECOVER:
			_clear_targets()
			_say("接线员", "打得不错！地上那把手枪，还有义体和防弹背心，都能带走。靠近按 E 收进背包吧，前面的 Codex 正好能帮我们处理这些装备。")
		Step.CODEX:
			_codex_actor = _make_service("codex", CODEX_POINT)
			_forge_actor = _make_service("forge", FORGE_POINT)
			_say("接线员", "看见前面那位了吗？她就是 Codex，旁边是合成台。走近按 E 和她聊聊，刚才捡的装备，说不定能合出点好东西。")
		Step.SYNTHESIZE:
			_dialogue_panel.hide()
		Step.MINI_BOSS:
			boss_bomb = BOMB_SCENE.instantiate() as FuelBarrel
			boss_bomb.position = Vector2(1790, 138)
			add_child(boss_bomb)
			boss_buff_box = BUFF_SCENE.instantiate() as PowerBox
			boss_buff_box.position = Vector2(1530, 138)
			boss_buff_box.buff_choice = 2
			add_child(boss_buff_box)
			mini_boss = ENEMY.instantiate() as EnemyController
			mini_boss.profile = preload("res://resources/enemies/heavy_anchor.tres").duplicate(true)
			mini_boss.profile.max_health = 12
			_adjust_enemy_speed(mini_boss.profile)
			mini_boss.position = Vector2(1850, 194)
			mini_boss.mandatory = false
			add_child(mini_boss)
			mini_boss.sprite.scale *= 1.35
			targets.append(mini_boss)
			_say("接线员", "合好了？接下来就是最后的中继守卫了。它有护盾和屏障，出手前会有预警。我们刚学的枪、盾反和冲刺都能用上。过了这里，就是仓库。")
			_say("接线员", "入口还有个增益箱，这次是散热提升，会替换刚才的攻速增益。上边也有个炸药箱，找准机会再引爆吧。")
		Step.TRANSFER:
			_clear_targets()
			_transfer_remaining = STEP_TRANSITION_SECONDS
			_say("接线员", "干得漂亮，通道打通了！仓库那边也接上了，我送你过去。先歇一会儿，等装备整理好了再出发。")
	queue_redraw()


func _advance_intro() -> void:
	if step != Step.BRIEFING or _line_age < 1.0:
		return
	if _dialogue_queue.is_empty():
		_dialogue_remaining = 0.0
		_end_radio()
		_radio.play()
		_set_step(Step.DODGE)
	else:
		_next_dialogue()


func _clear_projectiles() -> void:
	for child in get_children():
		if child is CombatProjectile:
			child.queue_free()




func _require_reflected_finish(_amount: int, packet: DamagePacket) -> bool:
	# Projectiles transfer source ownership to the defender on reflection.
	return not (packet.source == player and packet.is_projectile and packet.source_faction == CombatFaction.Id.PLAYER)


func _require_dash_finish(_amount: int, packet: DamagePacket) -> bool:
	return not (packet.source == player and packet.is_melee and not packet.reflected and player.dash.is_dashing())


func _require_pistol_finish(_amount: int, packet: DamagePacket) -> bool:
	return packet.weapon_id != &"service_pistol"


func _on_parry_defeated(enemy: EnemyController, _mandatory: bool) -> void:
	_gun_drop_point = enemy.position


func _drop_item(id: String, point: Vector2) -> ComponentPickup:
	var pickup := PICKUP.instantiate() as ComponentPickup
	pickup.component_id = id
	pickup.position = point
	pickup.rolled_item = ComponentRolls.create(id, 1, RandomNumberGenerator.new())
	if id == "armor":
		pickup.rolled_item.set_property("name", "防弹背心")
	add_child(pickup)
	return pickup


func _on_wave_defeated(enemy: EnemyController, _mandatory: bool, id: String) -> void:
	recovery_pickups.append(_drop_item(id, enemy.position))


func _on_inventory_visibility() -> void:
	if step == Step.EQUIP and player.inventory.is_open:
		_inventory_opened = true


func _on_codex_visibility() -> void:
	_dialogue_panel.visible = _dialogue_remaining > 0.0 and not panel.is_open
	for control in [_skip_button, _skip_track, _skip_progress]:
		control.visible = not panel.is_open


func _make_service(action: String, point: Vector2) -> Area2D:
	var area := Area2D.new()
	area.name = "Codex" if action == "codex" else "SynthesisTable"
	area.set_script(preload("res://scripts/gameplay/prologue/prologue_service.gd"))
	area.action = action
	area.collision_layer = 32
	area.collision_mask = 0
	area.position = point
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 28
	shape.shape = circle
	area.add_child(shape)
	if action == "codex":
		var dragon: DragonSpriteAnimator = preload("res://scenes/actors/companions/dragon_visual.tscn").instantiate()
		dragon.name = "DragonVisual"
		dragon.position.y = 14
		dragon.scale = Vector2.ONE * 0.3
		area.add_child(dragon)
	else:
		var sprite := Sprite2D.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = preload("res://assets/art/environment/warehouse/workbench.png")
		atlas.region = Rect2(183, 76, 1163, 873)
		sprite.texture = atlas
		sprite.scale = Vector2(76, 54) / sprite.texture.get_size()
		sprite.position.y = -20
		area.add_child(sprite)
	var label := _label("Codex [E]" if action == "codex" else "合成台 [E]", 11, CYAN)
	label.position = Vector2(-50, 24)
	area.add_child(label)
	add_child(area)
	return area


func use_service(action: String) -> void:
	if step not in [Step.CODEX, Step.SYNTHESIZE]:
		return
	if not dialogue_completed:
		if action == "forge":
			return
		_dialogue_queue.clear()
		_dialogue_remaining = 0
		panel.open()
	else:
		upgrade_panel.open()


func _on_codex_completed() -> void:
	dialogue_completed = true
	_set_step(Step.SYNTHESIZE)
	upgrade_panel.call_deferred("open")


func owns_synthesis_item(item: InventoryItem) -> bool:
	return item != null and player.inventory.item_location(item) != ""


func synthesize(subject: InventoryItem, material: InventoryItem) -> bool:
	if step != Step.SYNTHESIZE or not dialogue_completed or _synthesis_done or not owns_synthesis_item(subject) or not owns_synthesis_item(material) or not ComponentRolls.compatible(subject, material):
		return false
	var inv := player.inventory
	var location := inv.item_location(subject)
	var result := ComponentRolls.fuse(subject, material, RandomNumberGenerator.new())
	if result == null:
		return false
	var before := player.export_run_state()
	subject.get_inventory().remove_item(subject)
	material.get_inventory().remove_item(material)
	var placed: bool = inv.backpack.add_item(result) if location == "backpack" else inv._slot_for(location).equip(result)
	if not placed:
		player.import_run_state(before)
		upgrade_panel.show_message("合成失败，原装备已恢复，请重试。")
		return false
	inv._apply_equipment()
	inv.changed.emit()
	last_synthesis_result = result
	_synthesis_done = true
	upgrade_panel.show_message("合成成功。成品已放回主体原位，按 Esc 返回通道继续教学。")
	return true


func _request_step(value: Step) -> void:
	if _pending_step >= 0:
		return
	_pending_step = int(value)
	_transition_remaining = STEP_TRANSITION_SECONDS
	_target_marker.text = "✓ 已完成"


func _say(speaker: String, text: String) -> void:
	if not _owns_dialogue_pause:
		_owns_dialogue_pause = not get_tree().paused
	get_tree().paused = true
	player.set_input_enabled(false)
	_dialogue_panel.show()
	_dialogue_queue.append({"speaker": speaker, "text": text})
	if _dialogue_remaining <= 0.0:
		_next_dialogue()


func _next_dialogue() -> void:
	if _dialogue_queue.is_empty():
		_dialogue_remaining = 0.0
		_end_radio()
		return
	var line: Dictionary = _dialogue_queue.pop_front()
	_speaker.text = line.speaker
	_dialogue.text = line.text
	_dialogue.visible_characters = 0
	_dialogue_remaining = 1.0 # Held until the player finishes reading and confirms.
	_line_age = 0.0
	_intro_continue.text = "一起出发 [Enter]" if _dialogue_queue.is_empty() else "继续 [Enter]"
	var interrupted := String(line.speaker).contains("大肥鱼")
	_speaker.modulate = Color.WHITE
	_speaker.add_theme_color_override("font_color", AMBER if interrupted else CYAN)
	_dialogue_panel.set_channel(interrupted)
	_intro_backdrop.interrupted = interrupted


func _end_radio() -> void:
	if _owns_dialogue_pause:
		get_tree().paused = false
	_owns_dialogue_pause = false
	_dialogue_panel.hide()
	player.set_input_enabled(step not in [Step.BRIEFING, Step.TRANSFER])


func _on_radio_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_continue_radio()
		get_viewport().set_input_as_handled()


func _continue_radio() -> void:
	if step == Step.BRIEFING:
		_advance_intro()
	elif _dialogue_remaining > 0.0:
		if _dialogue.visible_characters < _dialogue.get_total_character_count():
			_line_age = (_dialogue.get_total_character_count() + 1) / 42.0
			_dialogue.visible_characters = _dialogue.get_total_character_count()
		else:
			_next_dialogue()


func _on_tutorial_heat_changed(current: float, maximum: float) -> void:
	if step not in [Step.WAVE, Step.MINI_BOSS] or _warned_high_heat or current < maximum * 0.7:
		return
	_warned_high_heat = true
	_show_heat_tip("枪有点烫了，换个位置，给它一点散热的时间。")


func _on_tutorial_overheated() -> void:
	if step not in [Step.WAVE, Step.MINI_BOSS] or _warned_overheat:
		return
	_warned_overheat = true
	_show_heat_tip("过热了，先躲一躲。热量降下来就能继续开火。")


func _show_heat_tip(text: String) -> void:
	_heat_tip.text = text
	_heat_tip_remaining = 5.0
	_heat_tip.show()


func _spawn_enemy(point: Vector2, ranged: bool) -> EnemyController:
	var enemy := ENEMY.instantiate() as EnemyController
	# Retain production behavior; slow only this tutorial's copied resources.
	enemy.profile = load("res://resources/enemies/ranged_sightline.tres" if ranged else "res://resources/enemies/melee_pressure.tres").duplicate(true)
	_adjust_enemy_speed(enemy.profile)
	enemy.mandatory = false
	enemy.position = point
	add_child(enemy)
	targets.append(enemy)
	return enemy


func _adjust_enemy_speed(profile: EnemyProfile) -> void:
	profile.move_speed *= MOVE_SPEED_SCALE
	profile.projectile_speed *= PROJECTILE_SPEED_SCALE


func _clear_targets() -> void:
	for enemy in targets:
		if is_instance_valid(enemy):
			enemy.queue_free()
	targets.clear()


func _all_targets_dead() -> bool:
	for enemy in targets:
		if is_instance_valid(enemy) and enemy.state != EnemyController.State.DEAD:
			return false
	return not targets.is_empty()


func _process(delta: float) -> void:
	if _leaving:
		return
	_tick_skip(delta)
	if _leaving:
		return
	if not get_tree().paused:
		_heat_tip_remaining = maxf(0.0, _heat_tip_remaining - delta)
	_heat_tip.visible = _heat_tip_remaining > 0.0 and step in [Step.WAVE, Step.MINI_BOSS]
	_line_age += delta
	_dialogue.visible_characters = mini(_dialogue.get_total_character_count(), int(_line_age * 42.0))
	_intro_continue.disabled = step == Step.BRIEFING and _line_age < 1.0
	_intro_continue.text = "一起出发 [Enter]" if _dialogue_queue.is_empty() else "继续 [Enter]"
	if _pending_step >= 0 and not get_tree().paused and _dialogue_remaining <= 0.0 and _dialogue_queue.is_empty():
		_transition_remaining = maxf(0.0, _transition_remaining - delta)
		if _transition_remaining <= 0.0:
			_set_step(_pending_step as Step)
	var viewport_size := get_viewport_rect().size
	var ratio := minf(viewport_size.x / 640.0, viewport_size.y / 360.0)
	_intro_backdrop.size = viewport_size
	_layout.scale = Vector2.ONE * ratio
	_layout.position = (viewport_size - Vector2(640, 360) * ratio) * 0.5
	camera.position = Vector2(clampf(player.position.x, 320, 1952), 180)
	if _pending_step < 0 and not get_tree().paused:
		_tick_step(delta)
	if step == Step.MINI_BOSS and is_instance_valid(mini_boss):
		_boss_status.text = "中继守卫  %d / %d" % [mini_boss.health.current_health, mini_boss.health.max_health]
		_boss_meter.size = Vector2(166.0 * mini_boss.health.current_health / mini_boss.health.max_health, 4)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	queue_redraw()


func _tick_step(delta: float) -> void:
	match step:
		Step.DODGE:
			if _all_targets_dead():
				_request_step(Step.PARRY)
		Step.PARRY:
			if _all_targets_dead():
				_clear_projectiles()
				_request_step(Step.GUN_PICKUP)
		Step.GUN_PICKUP:
			if not is_instance_valid(gun_pickup) or gun_pickup.get("_picked"):
				_request_step(Step.EQUIP)
		Step.EQUIP:
			if _inventory_opened and not player.inventory.is_open and player.weapons.get_current_weapon() != null:
				_request_step(Step.SUPPLIES)
		Step.SUPPLIES:
			if buff_box.state == PowerBox.State.CLAIMED:
				_request_step(Step.WAVE)
		Step.WAVE:
			if _all_targets_dead():
				_request_step(Step.RECOVER)
		Step.RECOVER:
			var collected := 0
			for pickup in recovery_pickups:
				if not is_instance_valid(pickup) or pickup.get("_picked"):
					collected += 1
			if collected == 3:
				_request_step(Step.CODEX)
		Step.SYNTHESIZE:
			if _synthesis_done and not upgrade_panel.is_open:
				_request_step(Step.MINI_BOSS)
		Step.MINI_BOSS:
			if _all_targets_dead():
				_request_step(Step.TRANSFER)
		Step.TRANSFER:
			if _dialogue_remaining <= 0 and _dialogue_queue.is_empty():
				_transfer_remaining = maxf(0.0, _transfer_remaining - delta)
				if _transfer_remaining <= 0.0:
					finish_prologue()


func _input(event: InputEvent) -> void:
	if _leaving:
		return
	if event is InputEventKey and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
		if event.pressed and not event.echo and not _skip_key:
			_skip_key = true
			_skip_tutorial_step()
		elif not event.pressed:
			_skip_key = false
		get_viewport().set_input_as_handled()
		return
	if event.is_echo():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and step != Step.BRIEFING and _dialogue_remaining > 0.0:
		if not _skip_button.get_global_rect().has_point(event.position):
			_continue_radio()
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("interact"):
		_interact()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		_continue_radio()
		get_viewport().set_input_as_handled()
	elif step == Step.PARRY and _dialogue_remaining <= 0.0 and event.is_action("attack"):
		if event is InputEventMouseButton and _skip_button.get_global_rect().has_point(event.position):
			return
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart_room") or event.is_action_pressed("inventory_toggle"):
		# Inventory and run restart are introduced after the prologue.
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_skip_key = false
		_skip_mouse = false
		_skip_elapsed = 0.0


func _interact() -> void:
	if _pending_step >= 0 or get_tree().paused:
		return
	if step in [Step.GUN_PICKUP, Step.RECOVER]:
		player.inventory.try_pick_nearest()
	elif step in [Step.CODEX, Step.SYNTHESIZE]:
		player.interactor.request_interaction(player)
	elif step == Step.MINI_BOSS and is_instance_valid(boss_buff_box):
		boss_buff_box.interact(player)
	elif step in [Step.SUPPLIES, Step.WAVE] and is_instance_valid(buff_box):
		buff_box.interact(player)


func _skip_tutorial_step() -> void:
	if player.inventory.is_open or panel.is_open or upgrade_panel.is_open:
		return # Esc keeps its normal close behavior inside equipment windows.
	_dialogue_queue.clear()
	_dialogue_remaining = 0.0
	_end_radio()
	_pending_step = -1
	_clear_projectiles()
	match step:
		Step.BRIEFING:
			_set_step(Step.DODGE)
		Step.DODGE:
			_clear_targets()
			player.dash.reset_transient_state()
			player.position = Vector2(490, 196)
			_set_step(Step.PARRY)
		Step.PARRY:
			_gun_drop_point = Vector2(594, 196)
			player.position = Vector2(560, 196)
			_set_step(Step.GUN_PICKUP)
		Step.GUN_PICKUP:
			if is_instance_valid(gun_pickup):
				player.inventory.pickup("pistol", gun_pickup.rolled_item)
				gun_pickup.queue_free()
			_set_step(Step.EQUIP)
		Step.EQUIP:
			var items := player.inventory.backpack.get_items()
			for index in items.size():
				if items[index].get_prototype().get_prototype_id() == "pistol":
					player.inventory.equip(index)
					break
			player.position = Vector2(670, 196)
			_set_step(Step.SUPPLIES)
		Step.SUPPLIES:
			buff_box.interact(player)
			player.position = Vector2(800, 196)
			_set_step(Step.WAVE)
		Step.WAVE:
			var dropped_ids: Array[String] = []
			for pickup in recovery_pickups:
				if is_instance_valid(pickup):
					dropped_ids.append(pickup.component_id)
			for id in ["pistol", "smart_fire", "armor"]:
				if id not in dropped_ids:
					recovery_pickups.append(_drop_item(id, Vector2(900 + recovery_pickups.size() * 30, 196)))
			player.position = Vector2(900, 196)
			_set_step(Step.RECOVER)
		Step.RECOVER:
			for pickup in recovery_pickups:
				if is_instance_valid(pickup) and not pickup.get("_picked"):
					player.inventory.pickup(pickup.component_id, pickup.rolled_item)
					pickup.queue_free()
			player.position = Vector2(1100, 196)
			_set_step(Step.CODEX)
		Step.CODEX:
			dialogue_completed = true
			_set_step(Step.SYNTHESIZE)
			player.position = Vector2(1250, 218)
			upgrade_panel.open()
		Step.SYNTHESIZE:
			player.position = Vector2(1500, 196)
			_set_step(Step.MINI_BOSS)
		Step.MINI_BOSS:
			_set_step(Step.TRANSFER)
		Step.TRANSFER:
			finish_prologue()


func _tick_skip(delta: float) -> void:
	_skip_elapsed = minf(_skip_elapsed + delta, SKIP_HOLD_SECONDS) if _skip_mouse else 0.0
	_skip_progress.size.x = 166.0 * _skip_elapsed / SKIP_HOLD_SECONDS
	if _skip_elapsed >= SKIP_HOLD_SECONDS:
		finish_prologue()




func _prevent_tutorial_death(_amount: int, _packet: DamagePacket) -> bool:
	return true


func _on_player_damaged(_amount: int, _packet: DamagePacket) -> void:
	_hit_flash = 0.3
	player.health.call_deferred("repair", player.health.max_health)


func finish_prologue() -> bool:
	if _leaving or _flow == null:
		return false
	_end_radio()
	if not _flow.request_scene(WAREHOUSE, {"guide_storage": true}):
		return false
	_leaving = true
	_skip_key = false
	_skip_mouse = false
	player.set_input_enabled(false)
	var run := get_node("/root/RunManager")
	run.begin_run()
	run.set_scene_payload({})
	return true


func _on_load_failed(_path: String, _error: String) -> void:
	_leaving = false
	_skip_elapsed = 0.0
	player.set_input_enabled(step != Step.BRIEFING)


func _draw() -> void:
	if step == Step.BRIEFING:
		return
	for index in _gates.size():
		if _gates[index].collision_layer != 0:
			var point := _gates[index].position
			draw_rect(Rect2(point - Vector2(4, 80), Vector2(8, 160)), Color("355360"))
			for y in range(116, 260, 16):
				draw_line(Vector2(point.x - 4, y), Vector2(point.x + 4, y + 6), AMBER, 2)
	if _hit_flash > 0.0:
		draw_circle(player.position, 24, Color(1.0, 0.25, 0.25, _hit_flash))
