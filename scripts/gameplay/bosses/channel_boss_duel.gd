class_name ChannelBossDuel
extends Node2D

enum Stage { INTRO, AWAKENING, ACTIVE, ENDING, COMPLETE, STOPPED }
const MAX_HEALTH := 60
const ECHO_FIRST_MARK := 0.35
const ECHO_INTERVAL := 0.52
const PROTECT_RELEASE := 0.70
const TAIL_CAST_DURATION := ChannelBossEffect.TAIL_WARNING + ChannelBossEffect.TAIL_FADE + 0.04
const GLIDE_SPEED := 60.0
const GLIDE_DISTANCE := 160.0
const GLIDE_BOUNDS := Rect2(330.0, 330.0, 620.0, 230.0)
const FORM_REVEAL := 0.55
const REVEAL_BLEND := 0.20
const INTRO := [
	["Codex / 通讯", "就是这里。修好的核心能把那些求救接回公共频道。我来维持连接，你替我争取时间。"],
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
var wings: Array[WingGuard] = []
var lightning_cell := Vector2.ZERO
var lightning_struck := false
var stage_clock := 0.0
var cast_skill: StringName = &""
var cast_clock := 0.0
var recovery := 0.8
var next_skill := 0
var echo_count := 0
var next_echo := -1.0
var pulse_pending := false
var tail_ready := true
var form_awakened := false
var attacks_started := [0, 0, 0, 0]
var auto_attacks := true
@onready var arena: RooftopBossArena = get_parent()
@onready var run: Node = get_node("/root/RunManager")


func _ready() -> void:
	dialogue = ChannelDialogue.new()
	arena.add_child(dialogue)
	arena.route_dialogue = dialogue
	camera = Camera2D.new()
	camera.position = Vector2(640, 420)
	camera.zoom = Vector2.ONE * 0.8
	arena.add_child(camera)
	camera.make_current()
	show_intro(0)


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
	arena.boss.get_node("PedestalCollision").set_deferred("disabled", true)
	var collision: CollisionShape2D = arena.boss.hurt_box.get_node("CollisionShape2D")
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(60, 142)
	collision.shape = rectangle
	collision.position = Vector2(0, -73)
	visual = ChannelBossAnimator.new()
	visual.modulate.a = 0.0
	arena.boss.add_child(visual)
	arena.boss.health.configure_max_health(MAX_HEALTH)
	arena.boss.health.damaged.connect(visual.flash_hit)
	arena.boss.queue_redraw()


func start_combat() -> void:
	if stage != Stage.AWAKENING:
		return
	awaken_form()
	visual.modulate.a = 1.0
	arena.boss.body_sprite.hide()
	arena.boss.glow_sprite.hide()
	stage = Stage.ACTIVE
	EnemyEncounterRecorder.watch(arena.boss, "rooftop_whale_goddess_channel", false)
	arena.player.camera.zoom = Vector2.ONE * 0.6
	arena.player.camera.position = Vector2.ZERO
	arena.player.camera.reset_smoothing()
	arena.player.camera.make_current()
	wings.append(arena._make_wing(WingGuard.Kind.ROOK, 10, BossFloorGeometry.cell_point(Vector2i(2, 5)), arena.get_node("Enemies")))
	wings.append(arena._make_wing(WingGuard.Kind.BISHOP, 8, BossFloorGeometry.cell_point(Vector2i(21, 5)), arena.get_node("Enemies")))
	cast_skill = &""
	cast_clock = 0
	recovery = 1.0
	tail_ready = true
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
	cast_skill = [&"echo", &"halo", &"protect", &"lightning"][index]
	cast_clock = 0
	echo_count = 0
	next_echo = ECHO_FIRST_MARK if index == 0 else -1.0
	pulse_pending = index == 2
	attacks_started[index] += 1
	next_skill = (index + 1) % 4
	if index == 0:
		visual.play_cast(cast_skill, ECHO_FIRST_MARK + ChannelBossEffect.ECHO_WARNING, ECHO_INTERVAL)
		arena.boss.play_echo_probe()
		arena.room_lighting.pulse_echo()
	elif index == 1:
		visual.play_cast(cast_skill, ChannelBossEffect.HALO_WARNING)
		var point := arena.to_local(arena.player.global_position)
		point.x = clampf(point.x, 270, 690)
		point.y = clampf(point.y, 300, 470)
		spawn_effect(&"halo", arena.to_global(point))
	elif index == 2:
		visual.play_cast(cast_skill, PROTECT_RELEASE)
	else:
		lightning_cell = arena._grid_cell(arena.player.global_position)
		lightning_struck = false
		arena.telegraph.show_thunder([lightning_cell], 0.7)
		arena.boss.play_echo_probe()


func spawn_effect(skill: StringName, point: Vector2) -> ChannelBossEffect:
	var effect := ChannelBossEffect.new()
	effect.arena = arena
	effect.skill = skill
	add_child(effect)
	effect.global_position = point
	return effect


func _cast_tail() -> void:
	tail_ready = false
	cast_skill = &"tail"
	cast_clock = 0.0
	var origin := arena.boss.global_position - Vector2(0, 8)
	var aim := (arena.player.global_position - origin) / Vector2(1.0, ChannelBossEffect.TAIL_Y_SCALE)
	var effect := spawn_effect(cast_skill, origin)
	effect.tail_angle = Vector2.DOWN.angle() if aim.is_zero_approx() else aim.angle()
	visual.play_tail(aim.x)


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
	_clear_wings()
	arena.telegraph.clear()
	if is_instance_valid(visual):
		visual.freeze(false)
	queue_redraw()


func begin_ending() -> void:
	if stage in [Stage.ENDING, Stage.COMPLETE, Stage.STOPPED]:
		return
	clear_effects()
	_clear_wings()
	arena.telegraph.clear()
	stage = Stage.ENDING
	cast_skill = &""
	next_echo = -1
	pulse_pending = false
	arena._set_phase(arena.Phase.CHANNEL_TAKEOVER)
	arena.boss.hurt_box.set_deferred("monitorable", false)
	arena._clear_hostile_projectiles()
	if is_instance_valid(visual):
		visual.freeze(true)
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
		if stage_clock < FORM_REVEAL:
			arena.boss.glow_sprite.modulate = Color(1, 0.85, 0.5, stage_clock / FORM_REVEAL)
		else:
			awaken_form()
			var blend := smoothstep(FORM_REVEAL, FORM_REVEAL + REVEAL_BLEND, stage_clock)
			visual.modulate.a = blend
			arena.boss.body_sprite.modulate.a = 1.0 - blend
			arena.boss.glow_sprite.modulate.a = 1.0 - blend
			var lift := smoothstep(FORM_REVEAL + REVEAL_BLEND, 1.55, stage_clock)
			arena.boss.position = Vector2(480, 245).lerp(Vector2(480, 315), lift)
		if stage_clock >= 1.7:
			start_combat()
	elif stage == Stage.ACTIVE:
		if arena.player.health.is_dead():
			stop_combat()
			return
		if cast_skill == &"lightning":
			cast_clock += delta
			if not lightning_struck and cast_clock >= 0.7:
				lightning_struck = true
				arena.telegraph.show_thunder([lightning_cell], 0.15, true)
				arena._show_lightning_at(lightning_cell)
				arena.get_node("LightningAudio").play()
				if arena.player.global_position.distance_to(lightning_cell) <= 24.0:
					arena._damage_player(lightning_cell, &"electric")
			if cast_clock >= 0.85:
				arena.telegraph.clear()
				cast_skill = &""
				recovery = 1.25 if arena.boss.health.get_health_ratio() > 0.5 else 0.85
		elif cast_skill == &"tail":
			cast_clock += delta
			visual.update_cast(cast_clock)
			if cast_clock >= TAIL_CAST_DURATION:
				recovery -= cast_clock
				cast_skill = &""
		elif cast_skill != &"":
			cast_clock += delta
			visual.update_cast(cast_clock)
			if next_echo >= 0 and cast_clock >= next_echo:
				spawn_effect(&"echo", arena.player.global_position)
				echo_count += 1
				next_echo = next_echo + ECHO_INTERVAL if echo_count < 3 else -1.0
			if pulse_pending and cast_clock >= PROTECT_RELEASE:
				spawn_effect(&"protect", arena.boss.global_position - Vector2(0, 8))
				pulse_pending = false
			if cast_clock >= 2.25:
				var combined := arena.boss.health.get_health_ratio() <= 0.5
				recovery = (0.25 if cast_skill == &"echo" else 0.85) if combined else 1.25
				tail_ready = true
				cast_skill = &""
		else:
			recovery -= delta
			var before := arena.boss.position
			var away := before - arena.player.position
			if away.is_zero_approx():
				away = Vector2.UP
			var desired := arena.player.position + away.normalized() * GLIDE_DISTANCE
			desired.x = clampf(desired.x, GLIDE_BOUNDS.position.x, GLIDE_BOUNDS.end.x)
			desired.y = clampf(desired.y, GLIDE_BOUNDS.position.y, GLIDE_BOUNDS.end.y)
			arena.boss.position = before.move_toward(desired, delta * GLIDE_SPEED)
			visual.update_motion((arena.boss.position.x - before.x) / (delta * GLIDE_SPEED))
			if auto_attacks and arena._optical_disruption_remaining <= 0:
				if tail_ready and recovery >= TAIL_CAST_DURATION:
					_cast_tail()
				elif recovery <= 0:
					cast_attack(next_skill)
		queue_redraw()


func _clear_wings() -> void:
	for wing in wings:
		if is_instance_valid(wing):
			wing.set_active(false)
			wing.queue_free()
	wings.clear()


func _draw() -> void:
	if stage not in [Stage.ACTIVE, Stage.ENDING] or not is_instance_valid(arena):
		return
	if pulse_pending:
		var charge := clampf(cast_clock / PROTECT_RELEASE, 0.0, 1.0)
		ChannelBossEffect.draw_wave_charge(self, to_local(arena.boss.global_position) - Vector2(0, 8), charge)
	var origin := to_local(arena.boss.global_position) + Vector2(-46, 15)
	draw_rect(Rect2(origin - Vector2(2, 2), Vector2(96, 8)), Color("0b1621"))
	draw_rect(Rect2(origin, Vector2(92, 4)), Color("33434d"))
	draw_rect(Rect2(origin, Vector2(92 * arena.boss.health.get_health_ratio(), 4)), Color("e7c77a"))
