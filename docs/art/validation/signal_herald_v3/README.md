# 举旗传令兵（2026-10-29）

采用用户确认的举旗概念：橙红信号旗、深蓝护甲、橙色头盔与肩甲、斜挎传令包和小型背部电台。四方向移动与攻击使用独立的 48 帧透明图集；每方向 6 帧移动、6 帧攻击，待机取对应攻击序列的起始姿势。受击与死亡继续接入现有反应和碎裂系统。

- 正式资源：`assets/art/characters/enemies/animated/signal_herald_v3.png` 与 `signal_herald_v3_frames.tres`。
- 概念图已获用户确认，保存在 `art_sources/ai_drafts/enemies/signal_herald_v3/approved_concept.png`。
- 生成方式：内置 image_gen，以确认概念与现有远程兵为参考。提示词见同目录 `generation_prompt.md`。不将新图集的生成来源套用于旧素材。
- 导入只分析透明边界与靴底位置，并生成 Godot AtlasTexture 描述；未修改生成图像像素。对齐记录见 `atlas_manifest.json`。
- 脚下保留两道扩散光环和一圈常驻光环，随角色移动，绘制在身体下方。
- 受强化者恢复第一版的紫色头顶盾形标记与脚边上升箭头；最后一个同区域信号源死亡后隐藏提示。
- 第二、三层每个普通战斗区域替换一只原有后排远程兵；第一层不出现，总怪物数量不变。
- 强化数值保留：同区域其他敌人移速 +30%、攻击间隔 -30%、累计减伤 40%；不强化自身、不叠加、不跨区域。

`animation_preview.gif` 为 Godot 图形模式实际渲染的广播、移动、攻击、受击和断链过程。复现入口：`tools/preview_signal_amplifier.gd`。

自动检查通过不代表完成整局平衡试玩；Godot 退出时仍有资源、ObjectDB/RID 释放提示。
