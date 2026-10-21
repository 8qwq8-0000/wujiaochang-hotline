# 地下整备仓库模块素材

2026-10-21，按用户确认的「逐个生成组件，再拼装地图」流程制作。

- 内置 image_gen 分别生成各个组件，原始 PNG 原样保存在本目录。
- 地板为不透明素材，设备和墙段使用透明背景。
- 完整提示词：`art_sources/ai_drafts/warehouse_safehouse_v1/components_prompts.json`。
- `scripts/presentation/warehouse_art.gd` 使用独立纹理、AtlasTexture 显示区域和最近邻采样组装场景，不将概念图当成整张地图贴图。
- 透明边缘的微弱杂点通过 AtlasTexture 区域排除，不改写源图像素。
- 地面按 32 游戏像素铺设；原始生成图不是原生 32×32 手绘素材。
- 设备挂在原有交互节点下；原储物箱碰撞、交互距离、仓库数据和存档规则仍由业务节点负责。
- 现有白发龙形合成师来自 `assets/art/environment/refined/gpt_synthesist.png`，本次未重新生成。

F5 从主菜单进入仓库可查看；独立渲染命令：

```sh
godot --path . --windowed --resolution 1280x720 --script res://tools/preview_warehouse_art.gd
```

渲染器使用独立临时存档并在退出时清理，不读写正式玩家进度。


墙体 v2：四个朝向独立墙段和四个转角位于 `*_v2.png`，替换原来的单墙段旋转拼接。生成提示词见 AI 草稿目录的 `walls_v2_prompts.json` 与 `foreground_corner_prompts.json`。显示层使用原图中的墙体/转角接头区域，不改写 PNG。

增加 `-- --walls-v2` 可保存新版全景；`-- --front-wall` 可保存角色靠前墙的遮挡预览。


设备 v2：`chest_v2`、`elevator_v2`、`training_door_v2`、`workbench_v2`、`terminal_v2`、`parts_rack_v2`、`crates_v2` 为强化顶面、门框纵深、前立面和踏台的 2.5D 透明组件。使用等比缩放，提示词见 `props_v2_prompts.json`。旧版源图保留用于对照。
