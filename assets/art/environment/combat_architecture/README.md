# 战斗场景 2.5D 门体

2026-10-21，Codex 内置 image_gen 分别生成横墙门、纵墙门。原图保留透明背景与生成分辨率，未旋转或重绘源像素。完整提示词：`art_sources/ai_drafts/combat_architecture_v1/prompts.json`。

`CombatArchitecture` 通过 AtlasTexture 选取有效区域，并按门所在墙面的世界方向选图。破门后仅保留端部门框，碎片取自对应方向的门体。围墙和转角复用已登记的 `assets/art/environment/warehouse/*_v2.png`，地板、机器和货箱复用 `assets/art/environment/workshop/`。

全部使用最近邻采样；原始生成图并非原生低分辨率手绘素材。
