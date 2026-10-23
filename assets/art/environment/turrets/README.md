# 警戒炮台美术

`sentry_turret_down_v1.png` 为内置 image_gen 生成的首版朝下静态炮台，深蓝灰装甲、四角固定底座、旋转轴承、双炮管、红色警戒传感器及琥珀色指示灯。

- 用户确认的目标占地：3×3 格；按项目 32 px 地砖计为 96×96 世界像素。
- 保留生成的 1254×1254 RGBA 透明源图，尚未缩成 96×96 位图。接入时应按主体裁切后缩放，不应把源图尺寸当成碰撞尺寸。
- alpha ≥128 的主体范围为 `(108, 134)` 至 `(1146, 1053)`；源图边缘有低 alpha 杂点。可供后续 AtlasTexture 裁取的带余量区域为 `Rect2(104, 130, 1046, 927)`，原始 alpha 未被修改。
- 已接入四张普通地图。固定底座 `sentry_base_v1.png` 与旋转炮头 `sentry_head_v1.png` 由内置 image_gen 编辑生成；96×96 占地、360 度跟踪、双管平行齐射。

完整提示词及来源信息：`art_sources/ai_drafts/sentry_turret_v1/prompt.txt`、`manifest.json`。
