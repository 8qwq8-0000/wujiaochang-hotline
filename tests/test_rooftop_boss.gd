@tool
extends McpTestSuite

const ARENA_SCENE := preload("res://scenes/levels/bosses/rooftop_boss_arena.tscn")
const BOSS_SCENE := preload("res://scenes/actors/bosses/rooftop_whale_goddess.tscn")
const WAREHOUSE_SCENE := preload("res://scenes/levels/base/warehouse.tscn")


func suite_name() -> String:
	return "rooftop_boss"


func test_runtime_textures_share_pixel_canvas() -> void:
	var dormant := load("res://assets/art/characters/bosses/rooftop_whale_goddess/rooftop_boss_dormant.png") as Texture2D
	var awakened := load("res://assets/art/characters/bosses/rooftop_whale_goddess/rooftop_boss_awakened.png") as Texture2D
	var glow := load("res://assets/art/characters/bosses/rooftop_whale_goddess/rooftop_boss_glow.png") as Texture2D
	assert_true(dormant != null)
	assert_true(awakened != null)
	assert_true(glow != null)
	assert_eq(dormant.get_size(), Vector2(256.0, 256.0))
	assert_eq(awakened.get_size(), dormant.get_size())
	assert_eq(glow.get_size(), dormant.get_size())
	var room := load("res://assets/art/environment/boss/rooftop_server_chapel_base_v4.png") as Texture2D
	assert_true(room != null)
	assert_eq(room.get_size(), Vector2(960.0, 540.0))


func test_boss_scene_has_six_step_weakpoint_health() -> void:
	var boss := track(BOSS_SCENE.instantiate()) as RooftopWhaleGoddess
	assert_true(boss != null)
	assert_eq(boss.get_node("HealthComponent").max_health, 6)
	assert_eq(boss.halo_segment_count, 5)
	assert_eq(boss.get_node("HurtBox").collision_layer, 16)
	assert_false(boss.get_node("HurtBox").monitorable)
	assert_true(boss.has_method("begin_awakening"))
	assert_true(boss.has_method("is_core_exposed"))
	assert_true(boss.has_method("play_echo_probe"))
	var echo_audio := boss.get_node_or_null("EchoProbeAudio") as AudioStreamPlayer2D
	assert_true(echo_audio != null)
	assert_true(echo_audio.stream != null)
	assert_eq(echo_audio.bus, &"SFX")


func test_arena_authors_phase_one_and_phase_two_contract() -> void:
	var arena := track(ARENA_SCENE.instantiate()) as RooftopBossArena
	assert_true(arena != null)
	assert_true(arena.is_in_group("combat_rooms"))
	assert_true(arena.get_node_or_null("Player") is PlayerController)
	assert_true(arena.get_node_or_null("Boss") is RooftopWhaleGoddess)
	assert_true(arena.get_node_or_null("AttackTelegraph") is BossAttackTelegraph)
	assert_true(arena.get_node_or_null("RoomLighting") is RooftopBossRoomLighting)
	assert_eq(arena.get_node("RoomArt").texture.get_size(), Vector2(960.0, 540.0))
	assert_true(arena.get_node("Boss").position.y < arena.get_node("Player").position.y)
	assert_true(arena.get_node("Boss").z_index < arena.get_node("Player").z_index)
	assert_eq(arena.get_node("Player").position, Vector2(480.0, 486.0))
	assert_eq(arena.get_node("EnemySpawnPoints").get_child_count(), 3)
	assert_true(arena.has_signal("room_cleared"))
	assert_true(arena.has_method("_damage_player_in_circle"))
	assert_true(arena.has_method("_damage_player_in_rect"))


func test_warehouse_exposes_boss_test_shortcut() -> void:
	var warehouse := track(WAREHOUSE_SCENE.instantiate())
	var shortcut: Node = warehouse.get_node_or_null("BossTest")
	assert_true(shortcut != null)
	assert_eq(shortcut.kind, "boss_test")
	assert_true(warehouse.has_method("enter_boss_test"))
