# 定向死亡喷血 v1

用户确认朝右动画后，扩展为16方向（每22.5°一档）。每方向14帧，15 FPS，逐帧192×192透明画布，喷射起点统一为(96,96)。spray_00朝右，Godot屏幕坐标顺时针递增：04下、08左、12上。不是直接旋转一张图：喷射在地面方向上变化，重力/落地始终保持屏幕竖直方向。

原生Godot动画源、GIF预览与224张逐帧PNG位于 `art_sources/animation_drafts/death_blood_spray_v1/directional/`；本目录保存16张横向图集，供 `DeathBloodSpray` 共享帧资源播放。源为本项目程序化像素动画，无新增第三方素材。每条喷流使用深红到高亮红的五色，血流断裂成滴并落地，与已有静态死亡痕迹并存。

运行：敌人保存致命DamagePacket的travel_direction，其次knockback，再其次从source_position指向敌人的方向。VFXManager在entity_defeated时生成一次方向动画；无明确攻击方向时才用死亡移动方向/面朝方向兜底。特效归属战斗房间，正常暂停，播放一次结束释放；共用现有死亡特效数量预算。没有更改伤害数值或掉落规则。

导出：`godot --path . --script res://tools/export_death_blood_spray.gd`。16向预览：`tools/preview_death_blood_directions.gd`。专项：`tests/integration/death_blood_spray_check.gd`，102/102，包括16向真实死亡、224帧透明边缘无裁切、方向优先级、来源位置回退、暂停、完成与房间清理。敌人战斗回归零失败。

本地仍存在敌人场景动画资源UID回退到路径的警告；既有战斗回归退出仍有资源释放诊断。未做Windows导出。本次尚未提交或推送PR。

## 红色地面印记修订

用户要求去掉敌人淡出及彩色血迹。VFXManager现不再生成DeathBurstEffect，也不再使用CyberStainLayer；仅播放红色方向喷血。每个方向另导出一张 `stain_XX.png`，直接取同一动画源完全落地后的血池和血滴，无空中粒子。喷血完成时由RedBloodStainLayer在原位置留下对应印记，保持原色不淡出；统一48枚预算，超过预算替换最早印记，离开房间清除。动画与印记共用画布、方向、缩放与锚点，地面层位于角色之前。死亡淡出/碎片旧资源保留在仓库历史中，已从运行入口移除。

修订专项122/122：16方向无淡出副本、对应红色落地帧、持续不淡出、房间卸载清理，及此前全部方向/暂停/裁切检查。实机预览：`directional/red_death.gif` 和 `ground_imprints.png`；工具为 `tools/preview_red_blood_death.gd`。

## 喷射速度修订

用户反馈动画过慢：实际播放从15 FPS提高至45 FPS，14帧总时长约0.31秒（原0.93秒）。16个方向统一提速，血迹仍在动画结束后持续保留。动画源及逐帧空间轨迹不变，仅收紧运行播放节奏。新增每方向小于350ms的时长检查；修订后专项138/138通过。新版实际效果动图为 `directional/red_death_fast.gif`。
