# 武器占位素材

`placeholder_weapon_spear.png` 原始文件名为 `spr_undynespear_l_0.png`，由组员在开发期提供，当前未确认来源与授权。

- 仅用于私有仓库的开发占位，不得进入公开构建；
- 原图为 53×8 RGBA 单帧，场景内按 0.5 倍、最近邻采样显示；
- 原图朝左，武器场景使用 `flip_h` 统一为朝右源姿态，再由玩家武器挂点完成 360° 旋转和左右镜像；
- 正式发布前必须替换并删除，同时更新 `docs/legal/素材来源与许可.md`。

## 无涂装腕锁武器占位图

以下三张透明 PNG 由 Codex 内置 ImageGen 母版经本地切分、减色、像素化和轮廓清理得到：

- `placeholder_arm_lock_baton_unpainted.png`：48×16；
- `placeholder_service_pistol_unpainted.png`：40×16；
- `placeholder_scattergun_unpainted.png`：48×20。

它们统一朝右，左边缘为腕锁锚点，不包含涂鸦、胶带、编号或随机喷漆。生成记录、原始母版和审计报告保存在 `art_sources/ai_drafts/weapons/`。这些文件仍属于 AI 占位素材；公开构建前必须按同一轮廓人工重绘，并保留程序化涂装的空白装甲面。
