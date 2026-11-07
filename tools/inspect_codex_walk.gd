extends "res://tools/play_codex_escort.gd"

var finishing := false
var active := false
var preparing := 0
var elapsed := 0.0
var last_clip := ""
var switches := 0
var resets := 0
var last_frame := 0
var last_progress := 0.0
var sample := 0
var escort_room: Node

func _process(delta: float) -> bool:
	if finishing or not ready_for_playtest:
		return false
	if not active:
		escort_room = current_scene.get_node("SceneContainer").get_child(0)
		escort_room.talk_to_codex()
		while escort_room.panel.is_open:
			escort_room.panel.advance()
		active = true
		return false
	if preparing < 4:
		preparing += 1
		escort_room.upgrade_panel.close()
		return false
	var actor: PlayerController = escort_room.player
	actor.set_physics_process(false)
	actor.position = Vector2(325 + minf(elapsed, 1.8) * 90, 250)
	actor.velocity = Vector2(90, 0) if elapsed < 1.8 else Vector2.ZERO
	var escort: CodexCompanion = escort_room.companion
	var clip := String(escort.visual.animation)
	if not last_clip.is_empty() and clip != last_clip:
		switches += 1
	if clip.begins_with("walk") and last_clip.begins_with("walk") and escort.visual.frame == 0 and last_frame > 0:
		resets += 1
	last_clip = clip
	last_frame = escort.visual.frame
	last_progress = escort.visual.frame_progress
	elapsed += delta
	if elapsed > float(sample) * 0.25:
		print("Walk sample ", sample, " distance=", snappedf(actor.position.distance_to(escort.position), 0.1), " clip=", clip, " frame=", last_frame, " rate=", snappedf(escort.visual.speed_scale * escort.visual.sprite_frames.get_animation_speed(escort.visual.animation), 0.1))
		_capture.call_deferred(sample)
		sample += 1
	if elapsed >= 3.0:
		print("Walk inspection: clip switches=", switches, "; frame wraps/resets=", resets)
		finishing = true
		_finish.call_deferred()
	return false

func _capture(index: int) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/codex-walk-%02d.png" % index)

func _finish() -> void:
	await RenderingServer.frame_post_draw
	current_scene.queue_free()
	current_scene = null
	await process_frame
	quit()
