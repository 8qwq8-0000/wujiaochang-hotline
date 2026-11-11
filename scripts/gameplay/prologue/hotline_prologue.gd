class_name HotlinePrologue
extends Node2D

enum Step { BRIEFING, DODGE, PARRY, GUN_PICKUP, EQUIP, WAVE, RECOVER, CODEX, CIRCUIT, SYNTHESIZE, MINI_BOSS, TRANSFER }

const WAREHOUSE := "res://scenes/levels/base/warehouse.tscn"
const ENEMY := preload("res://scenes/actors/enemies/enemy.tscn")
const PICKUP := preload("res://scenes/items/component_pickup.tscn")
const SKIP_HOLD_SECONDS := 1.2
const STEP_TRANSITION_SECONDS := 1.5
const MOVE_SPEED_SCALE := 0.8
const PROJECTILE_SPEED_SCALE := 0.85
const CODEX_POINT := Vector2(1140, 190)
const FORGE_POINT := Vector2(1250, 174)
const WAVE_REWARDS := ["pistol", "smart_fire", "armor", "explosive_magazine", "tactical_coprocessor"]
const ACCENT := CyberUITheme.ACCENT
const AMBER := CyberUITheme.ACCENT_LIGHT

var step: Step = Step.BRIEFING
var targets: Array[EnemyController] = []
var recovery_pickups: Array[ComponentPickup] = []
var gun_pickup: ComponentPickup
var _gun_drop_point := Vector2(594, 196)
var panel: CanvasLayer
var dialogue_completed := false
var _codex_actor: Area2D
var _forge_actor: Area2D
var _boss_status: Label
var _boss_meter: ColorRect
var mini_boss: EnemyController
var chest: Inventory
var upgrade_panel: CanvasLayer
var last_synthesis_result: InventoryItem
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
var show_combat_hud := false
var _hud_process_mode := Node.PROCESS_MODE_INHERIT
var _hud: CanvasLayer
var _layout: Control
var _speaker: Label
var _dialogue: Label
var _skip_progress: ColorRect
var _skip_button: Button
var _target_marker: Label
var _circuit_lesson_button: Button
var _circuit_lesson_hint: Label
var _circuit_lesson_complete := false
var _circuit_feedback_remaining := 0.0
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
	player.health.fatal_damage_interceptor = _prevent_tutorial_death
	player.health.damaged.connect(_on_player_damaged)
	player.cyberware.module_triggered.connect(_on_tutorial_module_triggered)
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
	panel.completion_text = "排列义体 [E]"
	panel.lines.assign([
		"我是 Codex。刚才捡到的智能火控、爆裂弹匣和战术协处理器，都是可以装进回路的义体。先把智能火控接上，我带你试一遍。",
		"回路从左往右执行。第一格放开火感应器，第二格放智能火控。你扣下扳机时，感应器会把信号交给后面的火控，让子弹追踪敌人。",
		"我帮你打开排列面板。先点槽 2，再从义体库选择智能火控。其余两件也留给你试搭，留意各自的说明和耗能。排好后关闭面板，我再教你合成装备。",
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


func _label(value: String, font_size := 12, color := CyberUITheme.HIGHLIGHT) -> Label:
	var label := Label.new()
	label.text = ControlPrompts.adapt(value)
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
	_skip_button.tooltip_text = "按住此按钮跳过整个序章" if OS.has_feature("mobile") else "Esc 跳过当前教学；按住此按钮跳过整个序章"
	_skip_button.position = Vector2(460, 10)
	_skip_button.size = Vector2(166, 24)
	CyberDialoguePanel.style_button(_skip_button)
	_skip_button.focus_mode = Control.FOCUS_NONE
	_skip_button.button_down.connect(func() -> void: _skip_mouse = true)
	_skip_button.button_up.connect(func() -> void: _skip_mouse = false)
	_layout.add_child(_skip_button)
	_skip_track = ColorRect.new()
	_skip_track.color = CyberUITheme.SURFACE
	_skip_track.position = Vector2(460, 36)
	_skip_track.size = Vector2(166, 3)
	_skip_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout.add_child(_skip_track)
	_skip_progress = ColorRect.new()
	_skip_progress.color = ACCENT
	_skip_progress.position = Vector2(460, 36)
	_skip_progress.size = Vector2(0, 3)
	_skip_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout.add_child(_skip_progress)
	_dialogue_panel = CyberDialoguePanel.new()
	var panel := _dialogue_panel
	panel.title = "HOTLINE / 公共频道                 Enter 继续"
	panel.gui_input.connect(_on_radio_click)
	panel.accent_color = ACCENT
	panel.position = Vector2(14, 279)
	panel.size = Vector2(612, 70)
	_layout.add_child(panel)
	# TerminalPanel._ready() defaults to click-through; override after entering the tree.
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)
	_speaker = _label("", 11, ACCENT)
	column.add_child(_speaker)
	_dialogue = _label("", 13)
	_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_dialogue)
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
	_circuit_lesson_button = Button.new()
	_circuit_lesson_button.text = "配置义体" if OS.has_feature("mobile") else "配置义体 [C]"
	_circuit_lesson_button.position = Vector2(14, 63)
	_circuit_lesson_button.size = Vector2(104, 24)
	_circuit_lesson_button.focus_mode = Control.FOCUS_NONE
	CyberDialoguePanel.style_button(_circuit_lesson_button)
	_circuit_lesson_button.pressed.connect(_open_circuit_lesson)
	_layout.add_child(_circuit_lesson_button)
	_circuit_lesson_button.hide()
	_circuit_lesson_hint = _label("", 11, AMBER)
	_circuit_lesson_hint.position = Vector2(124, 68)
	_layout.add_child(_circuit_lesson_hint)
	_circuit_lesson_hint.hide()
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
	_dialogue_panel.title = "五角场热线 / 信号接入" if intro else ("AI 接线员 / 通信中  [轻触屏幕继续]" if OS.has_feature("mobile") else "AI 接线员 / 通信中  [Enter 或点击继续]")
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
		["04 / 打开背包装备武器", "按 Tab 打开背包 · 点击手枪或拖到武器槽 · Tab 关闭", Vector2(640, 194), "Tab / 打开背包装备手枪"],
		["05 / 使用手枪清除敌人", "瞄准敌人，点击左键射击", Vector2(900, 194), "消灭三名敌人"],
		["06 / 回收战利品", "按 E 拾取三件义体、手枪和防弹背心", Vector2(948, 194), "E / 回收五件战利品"],
		["07 / 找到 Codex", "靠近 Codex 按 E，向她学习义体排列", CODEX_POINT, "E / 与 Codex 对话"],
		["08 / 排列义体", "开火感应器放槽 1，智能火控放槽 2 · 排好后关闭面板", CODEX_POINT, "C / 排列义体"],
		["09 / 合成装备", "两件同品质手枪放入主体和材料槽 · 确认合成", FORGE_POINT, "E / 打开合成台"],
		["10 / 击败中继守卫", "使用武器、盾反和突进突破最后封锁", Vector2(1850, 194), "小 Boss / 中继守卫"],
		["序章完成 / 准备传送", "接线员正在接通仓库……", Vector2(1850, 194), "传送至仓库"],
	]
	var definition: Array = objectives[int(step)]
	_target_marker.position = definition[2] + Vector2(-85, 34)
	_target_marker.text = ControlPrompts.adapt(definition[3])
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
			_say("接线员", "这下有枪用了！按 Tab 打开背包，点一下刚捡的手枪就能装上，拖到武器槽也可以。装好再按 Tab 回来，我们一起试试。")
		Step.WAVE:
			_clear_projectiles()
			for index in 3:
				var enemy := _spawn_enemy(Vector2(842 + index * 70, 166 + (index % 2) * 52), index == 1)
				if index == 0:
					enemy.health.fatal_damage_interceptor = _require_pistol_finish
				enemy.defeated.connect(_on_wave_defeated.bind(index))
			_say("接线员", "试试刚装好的枪。鼠标瞄准，点左键启动回路，执行完才会发射。耐久下面那条是回路能量。")
		Step.RECOVER:
			_clear_targets()
			_say("接线员", "靠近战利品按 E。这次有三件义体，还有手枪和背心。捡好后往前走，找到 Codex，她会带你排列义体、合成装备。")
		Step.CODEX:
			_codex_actor = _make_service("codex", CODEX_POINT)
			_forge_actor = _make_service("forge", FORGE_POINT)
			_say("接线员", "Codex 就在前面的维修站。靠近她按 E，聊聊刚捡到的义体。")
		Step.CIRCUIT:
			_dialogue_panel.hide()
			_open_circuit_lesson.call_deferred()
		Step.SYNTHESIZE:
			_dialogue_panel.hide()
			panel.lines.assign([
				"接好了。刚才这两格的顺序，就是先接收开火信号，再给子弹加上追踪。剩下的义体可以之后慢慢试，能量够不够也要留意。",
				"再看看装备。你手里和背包里各有一把手枪，正好可以合成。把想保留的那把放进主体槽，另一把放材料槽。两件必须同类型、同品质。",
				"确认合成会消耗这两把枪，提升品质并获得更好的词条，基础伤害还是原来的数值。成品会回到主体原来的位置。合成台给你打开，完成后按 Esc 回来。",
			])
			panel.completion_text = "打开合成台 [E]"
			panel.open(true)
		Step.MINI_BOSS:
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
			_say("接线员", "刚才那套义体正好能用上。鼠标瞄准，点左键开火，看看子弹会不会追着守卫走。耐久下面那条是回路能量，见底了就缓一缓，等它回上来。")
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


func _on_wave_defeated(enemy: EnemyController, _mandatory: bool, index: int) -> void:
	for reward_index in range(index, WAVE_REWARDS.size(), 3):
		var offset := Vector2(-18 if reward_index < 3 else 18, 0)
		recovery_pickups.append(_drop_item(WAVE_REWARDS[reward_index], enemy.position + offset))


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
	var label := _label("Codex [E]" if action == "codex" else "合成台 [E]", 11, ACCENT)
	label.position = Vector2(-50, 24)
	area.add_child(label)
	add_child(area)
	return area


func use_service(action: String) -> void:
	if step not in [Step.CODEX, Step.CIRCUIT, Step.SYNTHESIZE]:
		return
	if step == Step.CIRCUIT:
		if action == "codex":
			_open_circuit_lesson()
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
	if step == Step.CODEX:
		_set_step(Step.CIRCUIT)
	elif step == Step.SYNTHESIZE:
		dialogue_completed = true
		upgrade_panel.call_deferred("open")


func _open_circuit_lesson() -> void:
	if is_instance_valid(_hud) and not get_tree().paused:
		_hud.get_circuit_editor().set_open(true)


func _on_tutorial_module_triggered(module_id: StringName) -> void:
	if step != Step.MINI_BOSS or module_id != CyberwareController.SMART_FIRE or _circuit_lesson_complete or not _has_tutorial_circuit():
		return
	_circuit_lesson_complete = true
	_circuit_feedback_remaining = 3.0


func _has_tutorial_starter() -> bool:
	var slots := player.cyberware.circuit.get_slots()
	return not slots.is_empty() and slots[0] == String(CyberwareController.COMBAT_SYNAPSE_SENSOR)


func _has_tutorial_circuit() -> bool:
	var slots := player.cyberware.circuit.get_slots()
	return slots.size() >= 2 and _has_tutorial_starter() and slots[1] == String(CyberwareController.SMART_FIRE)


func _update_circuit_lesson(delta: float) -> void:
	var lesson_available := step in [Step.CIRCUIT, Step.MINI_BOSS]
	var configured := lesson_available and not _circuit_lesson_complete and _has_tutorial_circuit()
	if is_instance_valid(_hud):
		var editor: CyberwareCircuitPanel = _hud.get_circuit_editor()
		var editor_hint := ""
		if lesson_available and not _circuit_lesson_complete:
			if configured:
				editor_hint = "接好了，关掉面板就能去试枪。"
			elif _has_tutorial_starter():
				editor_hint = "点槽 2，再点左边的智能火控。"
			else:
				editor_hint = "先点槽 1，把开火感应器装回去。"
		editor.set_tutorial_hint(editor_hint)
	var show_lesson := lesson_available and not get_tree().paused and is_instance_valid(_hud)
	_circuit_lesson_button.visible = show_lesson and not configured and not _circuit_lesson_complete
	_circuit_lesson_hint.visible = show_lesson and (not _circuit_lesson_complete or _circuit_feedback_remaining > 0.0)
	if not show_lesson:
		return
	_circuit_lesson_hint.position.x = 124.0 if _circuit_lesson_button.visible else 14.0
	if _circuit_lesson_complete:
		_circuit_lesson_hint.text = "Codex：接上了！这发子弹会追附近的敌人。"
		_circuit_feedback_remaining = maxf(0.0, _circuit_feedback_remaining - delta)
	elif configured:
		_circuit_lesson_hint.text = "Codex：接好了，关闭面板后继续学合成。" if step == Step.CIRCUIT else ControlPrompts.adapt("Codex：瞄准守卫，点击左键射击，试试刚接的火控。")
	else:
		_circuit_lesson_hint.text = "开火感应器 → 智能火控"


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
	_dialogue_queue.append({"speaker": speaker, "text": ControlPrompts.adapt(text)})
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
	_intro_continue.text = ("一起出发" if _dialogue_queue.is_empty() else "继续") + (" [轻触屏幕]" if OS.has_feature("mobile") else " [Enter]")
	var interrupted := String(line.speaker).contains("大肥鱼")
	_speaker.modulate = Color.WHITE
	_speaker.add_theme_color_override("font_color", AMBER if interrupted else ACCENT)
	_dialogue_panel.set_channel(interrupted)
	_intro_backdrop.interrupted = interrupted


func _end_radio() -> void:
	if _owns_dialogue_pause:
		get_tree().paused = false
	_owns_dialogue_pause = false
	_dialogue_panel.hide()
	player.set_input_enabled(step not in [Step.BRIEFING, Step.TRANSFER])


func _on_radio_click(event: InputEvent) -> void:
	if DialogueAdvanceInput.is_tap(event):
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
	_line_age += delta
	_dialogue.visible_characters = mini(_dialogue.get_total_character_count(), int(_line_age * 42.0))
	_intro_continue.disabled = step == Step.BRIEFING and _line_age < 1.0
	_intro_continue.text = ("一起出发" if _dialogue_queue.is_empty() else "继续") + (" [轻触屏幕]" if OS.has_feature("mobile") else " [Enter]")
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
	_update_circuit_lesson(delta)
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
			if not player.inventory.is_open and player.weapons.get_current_weapon() != null:
				_request_step(Step.WAVE)
		Step.WAVE:
			if _all_targets_dead():
				_request_step(Step.RECOVER)
		Step.RECOVER:
			var collected := 0
			for pickup in recovery_pickups:
				if not is_instance_valid(pickup) or pickup.get("_picked"):
					collected += 1
			if collected == WAVE_REWARDS.size():
				_request_step(Step.CODEX)
		Step.CIRCUIT:
			if _has_tutorial_circuit() and not _hud.get_circuit_editor().is_open and not player.inventory.is_open:
				_request_step(Step.SYNTHESIZE)
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
			if player.inventory.is_open:
				player.inventory.set_open(false)
			elif is_instance_valid(_hud) and _hud.get_circuit_editor().is_open:
				_hud.get_circuit_editor().set_open(false)
			else:
				_skip_tutorial_step()
		elif not event.pressed:
			_skip_key = false
		get_viewport().set_input_as_handled()
		return
	if event.is_echo():
		return
	if DialogueAdvanceInput.is_tap(event) and _dialogue_remaining > 0.0 and _dialogue_panel.visible:
		if not _skip_button.get_global_rect().has_point(DialogueAdvanceInput.position(event)):
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
	elif event.is_action_pressed("inventory_toggle"):
		# The prologue owns inventory input so actor/UI processing order cannot eat Tab.
		if step >= Step.EQUIP and _dialogue_remaining <= 0.0 and not panel.is_open and not upgrade_panel.is_open:
			if player.inventory.is_open or not get_tree().paused:
				player.inventory.set_open(not player.inventory.is_open)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart_room"):
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
	elif step in [Step.CODEX, Step.CIRCUIT, Step.SYNTHESIZE]:
		player.interactor.request_interaction(player)



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
			_set_step(Step.WAVE)
		Step.WAVE:
			var dropped_ids: Array[String] = []
			for pickup in recovery_pickups:
				if is_instance_valid(pickup):
					dropped_ids.append(pickup.component_id)
			for id in WAVE_REWARDS:
				if id not in dropped_ids:
					recovery_pickups.append(_drop_item(id, Vector2(850 + recovery_pickups.size() * 28, 196)))
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
			_set_step(Step.CIRCUIT)
		Step.CIRCUIT:
			_set_step(Step.SYNTHESIZE)
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
