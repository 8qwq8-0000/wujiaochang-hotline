# 楼顶鲸神 BOSS 两阶段像素立绘生成记录

## 基本信息

- 日期：2026-10-18
- 工具：Codex 内置 ImageGen
- 参考设定：`../rooftop_whale_goddess_boss_concept_v2.png`
- 生成源图尺寸：1254×1254 RGBA
- 运行候选尺寸：256×256 RGBA
- 运行候选目录：`runtime_candidates/`
- 统一锚点：`(128, 240)`
- 缩放方式：源图最近邻缩放至 224×224，再置于 256×256 透明画布中央，四周 16 px 安全区
- 当前状态：技术检查通过并已复制到 `assets/` 运行目录；最终公开构建仍需完成版权验收

## 运行候选

- `runtime_candidates/rooftop_boss_dormant.png`：第一阶段完全熄灭态
- `runtime_candidates/rooftop_boss_awakened.png`：第二阶段正常苏醒态
- `runtime_candidates/rooftop_boss_glow.png`：第二阶段彩色 RGBA 发光叠层

三张图片均为 256×256、RGBA、透明背景、同一中心与锚点。成年母神仅保留一条向画面右侧弯出的鲸尾；鲸子保留自己的小鲸尾；光环固定为五段。

## Prompt 1：熄灭态

```text
Use case: stylized-concept
Asset type: production-ready static pixel-art boss sprite for a 640×360 top-down Godot game; phase 1 dormant state.
Input image: the v2 concept sheet is the authoritative character design reference. Preserve its character identity and simplified design, but render only one isolated game sprite, not a concept sheet.

Create one full-body pixel-art sprite of the rooftop whale goddess BOSS in her completely dormant phase. She is a 12-meter stationary architectural statue, facing toward the bottom of the screen in a high three-quarter top-down game view. Use elegant adult anatomy with approximately 1:7.5 head-to-body proportions; not chibi and not big-headed.

Preserve the young compassionate blindfolded whale goddess, calm Madonna-like mouth, lowered chin, long deep-blue wavy hair, whale-fin ears, dark-blue sacred blindfold, upright pose, sleeping mechanical whale child, weathered ivory marble shell, sparse dark bronze inner structure, simple classical sacred robe, and compact circular pedestal. Show exactly one adult whale tail curving screen-right and exactly five intact halo segments. Keep only a few fluorescent rods near the shoulders.

Every light is off: blindfold slit, halo, child circuitry, stone cracks, pedestal seams, and rods emit no light. Use native hard-edged pixel art for a final 256×256 RGBA sprite, limited palette, 1–2 pixel deep blue-gray outline, no anti-aliasing, blur, painterly detail, bloom, aura, particles, cast shadow, background, text, UI, weapon, cable, extra tail, or extra halo segment. Center the complete sprite on a genuinely transparent background with 8–16 pixels of safety margin and contact anchor at (128, 240).
```

## Prompt 2：苏醒态

```text
Use case: precise-object-edit
Asset type: production-ready static pixel-art boss sprite; phase 2 awakened state.
Input image: the dormant sprite is the edit target.

Change only the lighting state from fully dormant to newly awakened. Preserve pose, anatomy, proportions, view, silhouette, alignment, transparent background, pedestal, hands, child, hair, robes, the single adult whale tail, the child's small tail, and exactly five halo segments.

Illuminate all five intact halo segments with amber-gold cores and restrained cyan circuitry. Turn on one thin amber blindfold warning slit; it is an indicator, not a beam. Add subtle amber light to selected marble cracks and pedestal seams. Turn on the child's cyan circuitry and small cyan AI core at normal mid-brightness. Turn on only the existing cyan, magenta, and yellow shoulder rods. Keep hard-edged native pixel art and restrained 1–2 pixel local rims; no large bloom, aura, rays, particles, sparks, scene, text, weapon, extra tail, or geometry changes.
```

## Prompt 3：Glow Overlay

```text
Use case: precise-object-edit / background-extraction
Asset type: colored RGBA emission overlay aligned to the awakened pixel-art boss sprite.

Remove all non-emissive marble, bronze, hair, robe, body, child shell, pedestal body, outlines, and shadows. Retain only narrow luminous cores at their original positions: one amber and one cyan strip for each of the five halo segments, the thin amber blindfold slit, the child's cyan circuitry and core, sparse thin amber crack lines, thin pedestal seam lines, and the few cyan, magenta, and yellow fluorescent rod cores.

All other pixels must have alpha 0. Preserve canvas, scale, alignment, native hard-edged pixel geometry, and limited colors. No black background, matte, structure fill, metal plate, marble body, large bloom, rays, particles, text, logo, or extra light groups.
```

## Godot 接入建议

```text
RooftopBossVisual (Node2D)
├── Body (Sprite2D)
├── GlowOverlay (Sprite2D, CanvasItemMaterial Add)
├── HeadLight (PointLight2D)
└── CoreLight (PointLight2D)
```

- 第一阶段：`Body.texture = rooftop_boss_dormant.png`，隐藏 `GlowOverlay` 与两盏灯。
- 第二阶段：`Body.texture = rooftop_boss_awakened.png`，显示 `GlowOverlay`。
- 呼吸：只调青蓝光区域；母神琥珀光保持稳定。
- 愤怒：琥珀金转橙红，五段光环错拍闪烁，鲸子青蓝光降低。
- 预警：提高眼罩光缝与对应装置的脉冲频率；不从光缝发射光线。
- 发光像素不是透明洞；透明只用于叠层中未发光的区域。
- 像素主体关闭 Filter 与 Mipmap，使用最近邻采样；柔光与 `PointLight2D` 独立处理。

## 验收记录

### 已完成的自动检查

- 三张候选均为 256×256。
- 三张候选均为 RGBA，保留透明通道。
- 文件名为小写 `snake_case`。
- 两阶段和发光叠层使用相同画布、中心与锚点约定。

### 后续人工检查

- 已在实际游戏场景检查轮廓、鲸子、蒙眼、五段光环和两阶段叠层对齐；当前版本可用于开发构建。
- 后续平衡阶段继续检查 Add 混合在不同显示亮度下是否过曝；必要时人工削弱石缝和基座亮线。
- 参考图来源、生成服务条款与项目发布范围是否兼容。
- 是否存在需在 Aseprite 中清除的边缘杂色或生成伪影。
