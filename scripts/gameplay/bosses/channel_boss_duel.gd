class_name ChannelBossDuel
extends Node2D

enum Stage { INTRO, AWAKENING, ACTIVE, ENDING, COMPLETE, STOPPED }
const MAX_HEALTH := 60
const INTRO := [
	["Codex / 楼顶", "就是这里。修好的核心能把那些求救接回公共频道。我留在祭坛旁维持连接，你替我争取时间。"],
	["神像 / 静默协议", "请保持安静。未经许可的声音，会惊醒她。"],
	["Codex / 频道直连", "它把求救也当成了噪声。核心接入后，你身上的负担就会解除。我来接通频道，你拦住她。"],
]
const ENDING := [
	["Codex / 封锁解除", "封锁解除了。别再开枪，我能把频道接回去。"],
	["未知呼叫 / 公共频道", "有人……能听见吗？"],
	["接线员 / 已接通", "听得见。报你的位置。\n\n公共频道已恢复。人员救援仍将继续。"],
]

var stage := Stage.INTRO
var dialogue: ChannelDialogue
var visual: ChannelBossAnimator
var camera: Camera2D
var stage_clock := 0.0
var cast_skill: StringName = &""
var cast_clock := 0.0
var recovery := 0.8
var next_skill := 0
var echo_count := 0
var next_echo := -1.0
var pulse_pending := false
var form_awakened := false
var attacks_started := [0, 0, 0]
var auto_attacks := true
var core_art: Sprite2D
@onready var arena: RooftopBossArena = get_parent()
@onready var run: Node = get_node("/root/RunManager")


func _ready() -> void:
	dialogue = ChannelDialogue.new()
	arena.add_child(dialogue)
	arena.route_dialogue = dialogue
	var codex := arena.codex
	codex.escort_complete = true
	codex.follow_player = false
	codex.walk_target = Vector2.INF
	codex.global_position = arena.to_global(Vector2(298, 260))
	_build_connection_art()
	camera = Camera2D.new()
	camera.position = Vector2(480, 270)
	camera.zoom = Vector2.ONE * (2.0 / 3.0)
	arena.add_child(camera)
	camera.make_current()
	show_intro(0)


func _build_connection_art() -> void:
	var altar := Sprite2D.new()
	altar.texture = preload("res://assets/art/environment/hidden_shrine_v1/altar.tres")
	altar.scale = Vector2(64, 50) / altar.texture.get_size()
	altar.position = Vector2(266, 250)
	altar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	altar.z_index = 3
	add_child(altar)
	core_art = Sprite2D.new()
	core_art.texture = preload("res://assets/art/environment/hidden_shrine_v1/core.tres")
	core_art.scale = Vector2(18, 22) / core_art.texture.get_size()
	core_art.position = Vector2(266, 219)
	core_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	core_art.z_index = 4
	core_art.hide()
	add_child(core_art)


func show_intro(index: int) -> void:
	if stage != Stage.INTRO or arena.player.health.is_dead():
		return
	if index >= INTRO.size():
		begin_awakening()
		return
	dialogue.open(INTRO[index][0], INTRO[index][1], [["继续", show_intro.bind(index + 1)]])


func begin_awakening() -> void:
	if stage != Stage.INTRO or arena.player.health.is_dead():
		return
	# The durable rooftop checkpoint intentionally remains BEFORE this transfer.
	# Quitting the duel restores the core and replays entry, not a half-saved fight.
	for item in arena.player.inventory.backpack.get_items():
		if arena.player.inventory.is_channel_core(item):
			arena.player.inventory.backpack.remove_item(item)
			arena.player.inventory.changed.emit()
			break
	arena.player.apply_channel_curse(false)
	arena.player.health.repair(arena.player.health.max_health)
	arena.player.set_input_enabled(false)
	core_art.show()
	stage = Stage.AWAKENING
	stage_clock = 0
	arena._set_phase(arena.Phase.AWAKENING)
	arena.boss.state = RooftopWhaleGoddess.State.AWAKENING
	arena.boss.glow_sprite.show()
	arena.room_lighting.begin_awakening()
	arena._publish_notice(&"channel_core_connected", "频道核心已接入，携带负担解除，耐久恢复", Color("75e8df"), 2.4)


func awaken_form() -> void:
	if form_awakened:
		return
	form_awakened = true
	arena.boss.channel_form = true
	arena.boss.body_sprite.hide()
	arena.boss.glow_sprite.hide()
	arena.boss.get_node("PedestalCollision").set_deferred("disabled", true)
	var collision: CollisionShape2D = arena.boss.hurt_box.get_node("CollisionShape2D")
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(60, 142)
	collision.shape = rectangle
	collision.position = Vector2(0, -73)
	visual = ChannelBossAnimator.new()
	arena.boss.add_child(visual)
	arena.boss.health.configure_max_health(MAX_HEALTH)
	arena.boss.health.damaged.connect(visual.flash_hit)
	arena.boss.queue_redraw()


func start_combat() -> void:
	if stage != Stage.AWAKENING:
		return
	awaken_form()
	stage = Stage.ACTIVE
	cast_skill = &""
	cast_clock = 0
	recovery = 1.0
	arena.boss.state = RooftopWhaleGoddess.State.ACTIVE
	arena.boss.health.end_guard_link()
	arena.boss.hurt_box.set_deferred("monitorable", true)
	arena.player.set_input_enabled(true)
	arena._set_phase(arena.Phase.BOSS_ACTIVE)
	arena._start_boss_music(2)
	arena._publish_combat_moment(&"boss_phase")
	arena._publish_notice(&"channel_duel", "避开回声落点与光带；突进可穿过震波", Color("f0d49a"), 3.0)


func cast_attack(index: int) -> void:
	if stage != Stage.ACTIVE or arena.player.health.is_dead():
		return
	cast_skill = [&"echo", &"halo", &"protect"][index]
	cast_clock = 0
	echo_count = 0
	next_echo = 0.35 if index == 0 else -1.0
	pulse_pending = index == 2
	attacks_started[index] += 1
	next_skill = (index + 1) % 3
	visual.play_cast(cast_skill)
	if index == 0:
		arena.boss.play_echo_probe()
		arena.room_lighting.pulse_echo()
	elif index == 1:
		var point := arena.to_local(arena.player.global_position)
		point.x = clampf(point.x, 270, 690)
		point.y = clampf(point.y, 300, 470)
		spawn_effect(&"halo", arena.to_global(point))


func spawn_effect(skill: StringName, point: Vector2) -> ChannelBossEffect:
	var effect := ChannelBossEffect.new()
	effect.arena = arena
	effect.skill = skill
	add_child(effect)
	effect.global_position = point
	return effect


func clear_effects() -> void:
	for child in get_children():
		if child is ChannelBossEffect:
			child.set_physics_process(false)
			child.hide()
			child.queue_free()


func stop_combat() -> void:
	stage = Stage.STOPPED
	cast_skill = &""
	next_echo = -1
	pulse_pending = false
	clear_effects()
	if is_instance_valid(visual):
		visual.stop()
	queue_redraw()


func begin_ending() -> void:
	if stage in [Stage.ENDING, Stage.COMPLETE, Stage.STOPPED]:
		return
	clear_effects()
	stage = Stage.ENDING
	cast_skill = &""
	next_echo = -1
	pulse_pending = false
	arena._set_phase(arena.Phase.CHANNEL_TAKEOVER)
	arena.boss.hurt_box.set_deferred("monitorable", false)
	arena._clear_hostile_projectiles()
	if is_instance_valid(visual):
		visual.play(&"idle")
		visual.set_process(false)
		visual.modulate.a = 0.65
	show_ending(0)
	queue_redraw()


func show_ending(index: int) -> void:
	if stage != Stage.ENDING:
		return
	if index >= ENDING.size():
		complete_ending()
		return
	dialogue.open(ENDING[index][0], ENDING[index][1], [["继续", show_ending.bind(index + 1)]], complete_ending)


func complete_ending() -> void:
	if stage != Stage.ENDING or arena.player.health.is_dead():
		return
	dialogue.close()
	stage = Stage.COMPLETE
	run.channel_takeover_complete = true
	arena._on_boss_defeated()


func _physics_process(delta: float) -> void:
	if stage == Stage.AWAKENING:
		stage_clock += delta
		if stage_clock < 0.55:
			arena.boss.glow_sprite.modulate = Color(1, 0.85, 0.5, stage_clock / 0.55)
		else:
			awaken_form()
			arena.boss.position = Vector2(480, 245).lerp(Vector2(480, 315), smoothstep(0, 1, (stage_clock - 0.55) / 1.0))
		if stage_clock >= 1.7:
			start_combat()
	elif stage == Stage.ACTIVE:
		if arena.player.health.is_dead():
			stop_combat()
			return
		if cast_skill != &"":
			cast_clock += delta
			if next_echo >= 0 and cast_clock >= next_echo:
				spawn_effect(&"echo", arena.player.global_position)
				echo_count += 1
				next_echo = next_echo + 0.52 if echo_count < 3 else -1.0
			if pulse_pending and cast_clock >= 0.7:
				spawn_effect(&"protect", arena.boss.global_position - Vector2(0, 8))
				pulse_pending = false
			if cast_clock >= 2.25:
				var combined := arena.boss.health.get_health_ratio() <= 0.5
				recovery = (0.25 if cast_skill == &"echo" else 0.85) if combined else 1.25
				cast_skill = &""
		else:
			recovery -= delta
			var before := arena.boss.position
			var target_x := clampf(arena.player.position.x, 330, 630)
			arena.boss.position.x = move_toward(before.x, target_x, delta * 22)
			visual.update_motion(absf(before.x - arena.boss.position.x) > 0.01)
			if auto_attacks and recovery <= 0 and arena._optical_disruption_remaining <= 0:
				cast_attack(next_skill)
		queue_redraw()


func _draw() -> void:
	if stage not in [Stage.ACTIVE, Stage.ENDING] or not is_instance_valid(arena):
		return
	var origin := to_local(arena.boss.global_position) + Vector2(-46, 15)
	draw_rect(Rect2(origin - Vector2(2, 2), Vector2(96, 8)), Color("0b1621"))
	draw_rect(Rect2(origin, Vector2(92, 4)), Color("33434d"))
	draw_rect(Rect2(origin, Vector2(92 * arena.boss.health.get_health_ratio(), 4)), Color("e7c77a"))
