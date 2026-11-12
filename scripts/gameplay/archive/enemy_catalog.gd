class_name EnemyCatalog
extends RefCounted

# One entry per combat identity; floor scaling and tutorial variants share it.
const ENTRIES := [
	{"id": "melee_pressure", "name": "近战施压者", "tag": "机动 / 近战", "profile": "melee_pressure", "behavior": "主动逼近并尝试包抄，以短距离近战压缩走位空间。", "counter": "保留突进空间，观察起手动作；避免被多名敌人围住。"},
	{"id": "ranged_sightline", "name": "狙击手", "tag": "火力 / 远程", "profile": "ranged_sightline", "behavior": "保持射击距离，在攻击间隙横移，利用直线火力封锁路线。", "counter": "借掩体切断射线，横向移动躲避弹道，或把握时机格挡反击。"},
	{"id": "heavy_anchor", "name": "重装盾兵", "tag": "重装 / 屏障", "profile": "heavy_anchor", "behavior": "展开正面屏障推进，承受更多伤害；倒下后还会短暂蓄能自爆。", "counter": "绕至侧后方，利用屏障冷却攻击；击倒后及时远离残骸。"},
	{"id": "freight_lane_marksman", "name": "货运线哨兵", "tag": "警戒 / 长射程", "profile": "freight_lane_marksman", "behavior": "沿货运通道巡逻，以较长射程覆盖通道和开阔地带。", "counter": "沿掩体接近，避开通道中线；看清射击前摇后再穿过火线。"},
	{"id": "signal_amplifier", "name": "传令兵", "tag": "支援 / 信号源", "profile": "signal_amplifier", "behavior": "传递增援信号，在场时为其他敌人提供加速与减伤支援。", "counter": "优先锁定并击破信号源，再处理受其支援的敌群。"},
	{"id": "wing_guard_rook", "name": "左翼卫", "tag": "首领 / 直线突进", "image": "res://assets/art/characters/bosses/wing_guards/left_rook_guard.png", "behavior": "沿横竖格线移动，锁定与玩家对齐的路线后突进劈砍。", "counter": "离开被锁定的行列，等突进结束后反击；近身劈砍可以盾反。"},
	{"id": "wing_guard_bishop", "name": "右翼卫", "tag": "首领 / 斜向激光", "image": "res://assets/art/characters/bosses/wing_guards/right_bishop_guard.png", "behavior": "沿对角线跳跃，在斜线上锁定并发射激光。", "counter": "横向或纵向离开预警线，等光束消失再穿过。"},
	{"id": "wing_guard_queen", "name": "合翼卫", "tag": "首领 / 米字激光", "image": "res://assets/art/characters/bosses/wing_guards/fused_queen_guard.png", "behavior": "由左右翼卫的核心融合而成，会发射米字激光，跳跃落地时放出扇形刀气。", "counter": "站到激光束之间的空格，避开落点。每对合翼卫造成 7 点伤害，神像失去 1 格耐久。"},
	{"id": "rooftop_whale_goddess", "name": "鲸鱼女神 · DS 中枢", "tag": "首领 / 守卫联结", "image": "res://assets/art/characters/bosses/rooftop_whale_goddess/rooftop_boss_dormant_large.png", "behavior": "左右翼卫被击碎后苏醒，发动回声定位和落雷。合翼卫存活时，神像免疫直接伤害。", "counter": "留意落雷预警，先击败合翼卫解除联结，再打掉神像最后 1 格耐久。"},
	{"id": "rooftop_whale_goddess_channel", "name": "鲸鱼女神 · 频道归还", "tag": "首领 / 楼顶单挑", "image": "res://assets/art/characters/bosses/rooftop_whale_goddess/channel_returned_v1/idle.png", "behavior": "神像苏醒后用回声定位、光带与震波封锁走位。", "counter": "避开回声落点与光带，必要时用突进穿过震波。"},
]


static func contains(enemy_id: String) -> bool:
	for entry in ENTRIES:
		if entry.id == enemy_id:
			return true
	return false


static func portrait(entry: Dictionary) -> Texture2D:
	if entry.has("image"):
		return load(entry.image) as Texture2D
	var profile := load("res://resources/enemies/%s.tres" % entry.profile) as EnemyProfile
	var frames := profile.animation_frames
	if frames == null:
		frames = load(EnemySpriteAnimator.FRAMES_PATH % ["melee", "ranged", "shield"][int(profile.role)]) as SpriteFrames
	var texture := frames.get_frame_texture(&"idle_down", 0)
	var image := texture.get_image()
	var bounds := image.get_used_rect()
	return ImageTexture.create_from_image(image.get_region(bounds)) if bounds.has_area() else texture
