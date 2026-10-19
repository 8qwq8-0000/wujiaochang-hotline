# 主角四方向基准：front v1

- 日期：2026-10-17
- 状态：用户已批准的 front 方向锚点；仍不是正式游戏素材
- 流程：`frameronin-codex` 方向扩展
- 身份参考：`../../protagonist_sample_v2.png`
- 方向：`front`，对应游戏运行时 `down`
- 内置生图次数：2（初稿 1 次；定向修正俯视角 1 次）
- 原始输出：`raw/front.png`
- 规范化预览：`normalized/front.png`
- 后续门槛：已满足；用户确认通过后才生成 `back / left / right`

## 角色锁定摘要

- 中高约 60°游戏俯视，固定镜头；角色面向画面下方。
- 视觉约 3.5～4 头高，头肩略强化、腿部轻微压缩。
- 中性作业站姿：肩宽平行站立、均匀承重、膝微屈、双手放松半握。
- 左护臂位于画面右侧，自然下垂并外旋约 15°；洋红箭头从腕部斜指向肘／肩。
- 右前臂位于画面左侧，自然下垂并外偏约 10°；断环缺口朝向指尖，肘部切分缝可见。
- 无武器、无机动模块、无背包；只保留身体接口。
- 青色为常态暗青，只允许极窄亮边，不允许明显光晕。
- 光源固定在屏幕左上；透明背景，无地面和投影。

## 第一轮生成提示词

```text
Use case: stylized-concept
Asset type: high-resolution directional character anchor — FRONT
Input image: Image 1 is the locked identity, construction, palette, asymmetry, paint-placement, line-art, and material-style reference. Do not preserve its three-quarter camera angle or combat-ready pose.

PRIMARY REQUEST
Create exactly one new full-body directional reference of the same locked character facing FRONT, meaning the character faces straight toward the bottom edge of the screen/viewer. Use a fixed game camera looking downward at approximately 60 degrees from horizontal. This is a cardinal front view, not a front-left or front-right three-quarter view.

CHARACTER LOCK
The exact same androgynous AI-guided temporary municipal contractor cyborg from Image 1:
- compact game-readable body, visually about 3.5–4 heads tall under mild top-down foreshortening;
- sealed front-low/back-high wedge helmet with short rear spine and narrow dim-cyan visor;
- cool light-gray matte ceramic armor, charcoal flexible neck/abdomen/hip underlayer and mechanical joints;
- permanent mechanical arms and plantigrade legs, normal knees, segmented ankles, broad split-toe feet;
- cyan segmented communication spine on the center chest, with dim emissive core and only an extremely narrow bright edge, no bloom;
- strong physical asymmetry: ANATOMICAL LEFT arm is the heavy wedge guard arm; ANATOMICAL RIGHT arm is the light dexterous five-finger arm with wrist weapon-interface casing;
- no weapon.

PAINT AND PHYSICAL SIDE LOCK
When facing the viewer, anatomical LEFT is on the RIGHT side of the image and anatomical RIGHT is on the LEFT side of the image.
- Heavy guard arm on image-right: dark-gray integrated shoulder-to-forearm armor, short shield face, one worn non-glowing purple-magenta arrow painted from wrist toward elbow/shoulder, sparse gray-white survival marks, faded municipal blocks.
- Helmet crossed-eye glyph exists only on anatomical-left rear temple; from this front view it may be only partially visible on image-right, but never move it or duplicate it.
- Light right forearm on image-left: fresh small magenta incomplete circular arrow surrounding one dot on the wrist interface; ring gap points toward the fingers.
- Anatomical-right shin on image-left: four faded gray-white extraction tally strokes plus one unfinished newer stroke.
- Municipal base marks are desaturated blue-gray and gray-white. Magenta is matte, non-emissive, approximately #D62C8B, total magenta coverage no more than about 10 percent.
- Do not add new magenta paint to the torso or communication spine.

POSE
Neutral operational stance for an animation anchor:
- feet shoulder-width, parallel, equal weight, toes facing straight toward the viewer/bottom edge;
- knees slightly flexed, foot soles on exactly the same baseline;
- both hands relaxed half-closed, articulated fingers readable;
- anatomical-right forearm hangs naturally and angles about 10 degrees outward, with a clear elbow layer-separation seam;
- anatomical-left guard arm hangs naturally and rotates its short shield surface outward about 15 degrees so the painted arrow is readable, but it is not raised into a blocking pose;
- arms remain slightly separated from the torso; no T-pose, no A-pose, no action pose.

CAMERA, SCALE, AND STYLE
- 1536×1536 square transparent canvas.
- Character centered, full head and complete feet visible, height about 80 percent of canvas.
- Foot baseline at about 90 percent of canvas height.
- Fixed 60-degree top-down game view with mild readability-driven foreshortening: slightly emphasize helmet and shoulders, mildly compress legs, but preserve human plantigrade anatomy.
- Fixed soft key light from screen upper-left; light does not rotate with the character.
- Match Image 1's clean mechanical line art and restrained cel/material shading, but simplify random scratches and micro-texture for a production model-sheet anchor.
- Genuine transparent background. No floor, no cast shadow, no halo, no frame.

STRICT AVOID
No three-quarter rotation, side turn, head turn, contrapposto, raised guard, weapon, backpack, mobility module, scenery, floor, contact shadow, text, labels, letters, readable numbers, logo, watermark, extra character, detached part, inset, alternate pose, turnaround sheet, grid, border, duplicated markings, swapped left/right parts, mirrored asymmetry, new armor geometry, giant shoulder pads, heavy robot proportions, cyan bloom, glowing magenta, or crop.
```

## 定向修正提示词

第一轮已正确保持正面方向、透明背景、左右结构和涂装，但镜头接近水平正面，未达到约 60°游戏俯视，因此只修正镜头高度与透视压缩。

```text
Use case: precise-object-edit
Asset type: corrected FRONT directional character anchor

EDIT TARGET
Image 1 is the current front directional draft. Preserve its exact character identity, cardinal FRONT facing, neutral stance, physical left/right placement, armor construction, paint symbols, colors, transparent background, canvas composition, hand poses, feet spacing, and clean line-art/material style.

MAKE ONE TARGETED CORRECTION
Increase the camera elevation to a clearly readable fixed 60-degree downward game view, like a high top-down action-game character reference. The camera must be above the character, looking down from the screen-bottom/front side.

Required visual evidence of the corrected high angle:
- clearly show broad TOP surfaces of the helmet crown, both shoulder plates, forearms, thighs, knees, and split-toe feet;
- the helmet crown and shoulders are visually emphasized and overlap more of the chest;
- the chest, abdomen, and legs are progressively foreshortened downward;
- the feet remain complete and readable but appear vertically compressed, not as a horizontal eye-level view;
- preserve a centered cardinal FRONT direction: the character's nose/visor, chest, pelvis, knees, and both foot axes still point straight toward the bottom edge, with no left or right three-quarter turn;
- preserve the game-readable compact 3.5–4-head silhouette.

DO NOT CHANGE
Do not change the anatomical-left heavy guard arm on image-right, anatomical-right light arm on image-left, magenta arrow, wrist broken-ring symbol, extraction tallies, cyan visor or chest spine, armor shapes, municipal marks, stance, arm angles, hand gesture, scale, background transparency, or lighting direction. No weapon, shadow, floor, text, labels, extra objects, detached parts, glow bloom, or new design details.
```

## 本地规范化

内置生图实际输出为 1254×1254，未遵循提示词中的 1536×1536。原图完整保存在 `raw/front.png`。使用 `sprite_tools.py normalize` 仅扩展透明画布，不缩放、不裁切、不减色：

```powershell
python sprite_tools.py normalize --input raw/front.png --canvas 1536x1536 --anchor center --no-trim --out normalized
```

规范化结果：

- 画布：1536×1536
- 可见包围盒：`[190, 180, 1375, 1370]`
- 可见高度：1190 px，约占画布 77.5%
- 脚底：y=1370，约为画布高度 89.2%
- 透明背景：通过（不是完全不透明图）
- 缩放：1.0；未插值
- 减色：未执行

## 人工检查

- 通过：正面朝下语义、明显中高俯视、完整头脚、统一脚底、透明背景。
- 通过：左护臂仍在画面右侧，右腕个人标记和右腿计数仍在画面左侧。
- 通过：冷灰、炭黑、暗青和洋红层级保持；无武器、投影、文字或额外对象。
- 用户已确认通过：俯视压缩、左护臂体量、头盔与胸口通讯脊的正面读法。
- 尚未验证：与 `back / left / right` 的跨方向身份一致性、脚底差异、面积差异和四方向审核板。
