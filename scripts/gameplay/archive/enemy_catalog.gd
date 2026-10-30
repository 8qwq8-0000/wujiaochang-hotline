class_name EnemyCatalog
extends RefCounted

# One entry per combat identity; floor scaling and tutorial variants share it.
const ENTRIES := [
	{"id": "melee_pressure", "name": "近战施压者", "tag": "机动 / 近战", "profile": "melee_pressure", "behavior": "主动逼近并尝试包抄，以短距离近战压缩走位空间。", "counter": "保留突进空间，观察起手动作；避免被多名敌人围住。"},
	{"id": "ranged_sightline", "name": "狙击手", "tag": "火力 / 远程", "profile": "ranged_sightline", "behavior": "保持射击距离，在攻击间隙横移，利用直线火力封锁路线。", "counter": "借掩体切断射线，横向移动躲避弹道，或把握时机格挡反击。"},
	{"id": "heavy_anchor", "name": "重装盾兵", "tag": "重装 / 屏障", "profile": "heavy_anchor", "behavior": "展开正面屏障推进，承受更多伤害；倒下后还会短暂蓄能自爆。", "counter": "绕至侧后方，利用屏障冷却攻击；击倒后及时远离残骸。"},
	{"id": "freight_lane_marksman", "name": "货运线哨兵", "tag": "警戒 / 长射程", "profile": "freight_lane_marksman", "behavior": "沿货运通道巡逻，以较长射程覆盖通道和开阔地带。", "counter": "沿掩体接近，避开通道中线；看清射击前摇后再穿过火线。"},
	{"id": "signal_amplifier", "name": "传令兵", "tag": "支援 / 信号源", "profile": "signal_amplifier", "behavior": "传递增援信号，在场时为其他敌人提供加速与减伤支援。", "counter": "优先锁定并击破信号源，再处理受其支援的敌群。"},
	{"id": "sentry_turret", "name": "警戒炮台", "tag": "设施 / 双排弹幕", "image": "res://assets/art/environment/turrets/sentry_turret_down_v1.png", "behavior": "固定驻守、转向瞄准，短暂预警后发射双排弹幕。", "counter": "利用转向间隙换位，借墙体遮挡弹道，避免停留在锁定方向。"},
	{"id": "rooftop_whale_goddess", "name": "鲸鱼女神 · DS 中枢", "tag": "首领 / 守卫联结", "image": "res://assets/art/characters/bosses/rooftop_whale_goddess/rooftop_boss_dormant.png", "behavior": "守卫清除后苏醒，以预警区域发动攻击，并与支援守卫联结。", "counter": "先处理守卫，观察地面预警并及时离开；联结阶段通过击败守卫削弱神像。"},
]


static func contains(enemy_id: String) -> bool:
	for entry in ENTRIES:
		if entry.id == enemy_id:
			return true
	return false


static func portrait(entry: Dictionary) -> Texture2D:
	if entry.has("image"):
		return load(entry.image) as Texture2D
	var profile_path := "res://resources/enemies/%s.tres" % entry.profile
	# Entries for optional enemy packs stay locked until that pack is installed.
	# The baseline build still needs a valid portrait for previews and validation.
	if not ResourceLoader.exists(profile_path):
		profile_path = "res://resources/enemies/ranged_sightline.tres"
	var profile := load(profile_path) as EnemyProfile
	var frames := profile.get("animation_frames") as SpriteFrames
	if frames == null:
		frames = load(EnemySpriteAnimator.FRAMES_PATH % ["melee", "ranged", "shield"][int(profile.role)]) as SpriteFrames
	var texture := frames.get_frame_texture(&"idle_down", 0)
	var image := texture.get_image()
	var bounds := image.get_used_rect()
	return ImageTexture.create_from_image(image.get_region(bounds)) if bounds.has_area() else texture
