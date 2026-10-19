# 楼顶鲸神 BOSS 概念设定 v1

## 生成记录

- 日期：2026-10-18
- 工具：Codex 内置 ImageGen
- 用途：楼顶 BOSS 造型、材质、发光分层与像素化轮廓参考
- 输出：`rooftop_whale_goddess_boss_concept_v1.png`
- 状态：AI 视觉草稿，不得直接作为正式像素素材进入运行目录
- 人工修改：暂无；正式使用前须由项目成员按 640×360 逻辑画布、核心调色板和像素网格重绘

## 参考图角色

1. 赛博朋克女神神像：参考纪念碑式构图、垂褶体量与彩色荧光棒装饰。
2. 成年鲸鱼女性设定：参考深蓝长卷发、鲸鳍耳、鲸尾与蓝白金配色；现代女仆装转译为古典神袍。
3. Q 版鲸鱼角色：参考怀中沉睡机械鲸子的蓝发、鲸鳍耳、鲸尾与可爱比例。
4. 经典圣母子画作：参考慈悲、低垂、平静的神态与母子怀抱关系，不复刻原画服装和构图。

## 主生成提示词

```text
Use case: stylized-concept
Asset type: wide landscape game boss character design sheet for the Godot game “五角场热线”; this is a high-resolution visual-development draft, not the final pixel sprite.

Create a 12-meter-tall stationary rooftop BOSS: a cyberpunk whale goddess statue holding a sleeping mechanical whale child, symbolizing a new AI model being gestated. The central hero view shows phase-two awakened form.

Front-facing upright monument pose, almost perfectly symmetrical, solemn and architectural. Young but non-childlike compassionate goddess face; chin slightly lowered toward the child; calm mouth. A wide dark-blue metallic sacred blindfold completely covers both eyes, with one very thin horizontal slit; the slit glows only as a warning indicator, never as a beam weapon. Very long flowing cobalt/deep-blue hair, whale-fin ears, subtle whale-belly ribbing in the torso and drapery, enormous passive whale tail curling behind the robes into the base. No weapon. Both arms cradle the sleeping whale child in a stable triangular Madonna-and-child composition.

The whale child is a sleeping mechanical sacred infant with chibi humanoid proportions, eyes closed, tiny folded hands, blue hair, fin ears and small whale tail. White porcelain and ivory stone shell with delicate cyan circuitry visible between joints and hair strands. Cute, peaceful, unmistakably artificial, not injured or macabre.

Weathered ivory marble outer shell with rain erosion, noble cracks and restrained chipped edges; dark aged bronze mechanical skeleton visible inside selected cracks. Classical Greek-inspired sacred robe and vertical sculptural folds. Translate apron, frills, bows and gold trim into carved layered borders, a whale-tail sacred emblem and subtle gilded inlay. Add restrained clusters of cyan, magenta and yellow fluorescent rod ornaments around shoulders, back and chest like cyber ritual votive pins.

Behind the head floats a five-segment broken mechanical halo. Each segment is a distinct destructible weak point. Awakened halo glows amber-gold with subtle cyan inner circuitry. The statue is fused to a circular five-way radial server altar suggesting five roads converging. Five mechanical rails extend outward. Long robes, passive whale tail and heavy data cables merge into the altar.

Awakened phase uses amber-gold as hostile main light and cyan-blue as AI core auxiliary light. Mother’s amber light is steady. The child’s cyan circuits glow in a slow breathing rhythm. For skill warning, blindfold slit and relevant arena mechanisms pulse brighter; do not depict the slit firing. Use neutral concept-sheet lighting, controlled glow, crisp luminous cores and limited halos.

Wide clean landscape character concept sheet on a warm light-gray neutral background. Center: large, fully visible front view of awakened full statue and five-way altar. Supporting panels without written labels: small dormant phase silhouette with all lights off; rear/three-quarter silhouette showing passive whale tail, cables and halo construction; close-up of blindfold, serene mouth and fin ear; close-up of sleeping mechanical whale child; exploded view of five destructible halo segments including one cracked segment; material details; tiny bottom-corner pixel-art readability thumbnail at 640×360 game-view scale with a player silhouette only ankle-high relative to the statue.

Polished high-end anime game character concept art with crisp professional production-design rendering, controlled painterly shading, precise mechanical design, readable materials and elegant line control. Original design.

No text, labels, letters, logos or watermark. No attack pose, walking pose, body rotation or weapon. Do not make the mother monstrous, skeletal, eroticized, childlike or a literal modern maid. Do not make the whale tail a weapon. Do not show a beam firing from the blindfold. Keep the blindfold, long blue hair, fin ears, sleeping whale child, five halo segments, passive whale tail, five-way altar, marble/bronze split and fluorescent rods readable. Avoid excessive tiny details, photographic realism and overblown bloom.
```

## 定向修正提示词

```text
Change only the central awakened goddess’s large mechanical halo so that it is made of exactly FIVE clearly separated, equally important destructible arc segments arranged as one broken circular halo behind her head. The five pieces must be unmistakably countable at a glance, with broad gaps between them. Preserve the amber-gold outer glow, cyan internal circuitry, mechanical construction and ritual cyberpunk feeling.

Make the dormant view, rear view and weak-point detail row use the same exact five-segment design; show the fifth detail segment cracked and extinguished. Preserve the goddess, blindfold, hair, fin ears, materials, fluorescent rods, sleeping whale child, pose, robes, passive whale tail, five-way server altar, supporting panels, lighting, palette and pixel thumbnail. No sixth halo plate, text, logo, weapon or beam.
```

## 后续制作约束

- 正式像素素材必须人工重绘，使用透明背景 RGBA PNG、sRGB 与最近邻采样。
- 发光核心和光晕分层；像素主体关闭过滤与 Mipmap，柔光遮罩可单独使用线性过滤。
- BOSS 主发光为琥珀金，AI 内核辅光为青蓝；敌意和危险不能只靠颜色表达。
- 五段圣光轮必须保持可数、可区分，并与战斗弱点状态一一对应。
- 正式运行素材与生产源文件需要另行登记负责人、路径和人工修改内容。
