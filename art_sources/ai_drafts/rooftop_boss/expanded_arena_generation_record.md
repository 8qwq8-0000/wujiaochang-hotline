# 楼顶 BOSS 扩大场景与挥击素材（2026-11-07）

使用 Codex 内置 ImageGen。

- 场景参考：`assets/art/environment/boss/rooftop_server_chapel_base_v4.png`。生成源图：`C:/Users/one/.codex/generated_images/01a1b547-4e21-7d31-a4ff-0f9433e27c2a/exec-164c445f-d02c-4044-bf57-d77a4c3827c9.png`。弃用候选：`rooftop_server_chapel_topdown_v5.png`，未接入最终场景。最终场景恢复原建筑图并另铺独立地板，见 `floor_overlay_generation_record.md`。
- 左翼卫挥击源图：`C:/Users/one/.codex/generated_images/01a1b547-4e21-7d31-a4ff-0f9433e27c2a/exec-404576fe-f973-46ac-925e-c15591612c7e.png`；运行图：`assets/art/effects/boss/rook_slash_arc.png`。
- 合翼卫挥击源图：`C:/Users/one/.codex/generated_images/01a1b547-4e21-7d31-a4ff-0f9433e27c2a/exec-fe81b839-c48f-4842-9625-80c0c6020fd3.png`；运行图：`assets/art/effects/boss/queen_slash_arc.png`。
- BOSS 放大主体与叠层从 `battle_sprite_v1` 目录中同尺寸的 1254×1254 AI 源图缩放到相同 358×358 画布，同锚点接入。

## 最终提示词

场景：以旧圣堂为参考，保留对称深蓝服务器圣堂、金属镶边、上方祭坛、两侧机柜、下方入口的相对布局；扩大中央可战斗地面，地板严格俯视、平坦无透视与障碍；不绘格子，格子后续精确合成；无角色、文字、UI。

左翼卫挥击：透明背景，单个向右飞行的纤窄金白新月剑气，暖金边缘、少量青蓝轻羽与火花；在约 80 像素显示尺寸下仍清晰；无人物、武器、文字与背景。

合翼卫挥击：基于左翼卫剑气，保持单个向右的新月轮廓与透明背景，扩大弧光，增加青蓝羽片残影及极少量紫色火花；无多余图形和背景。
