# 主角四方向基准 v1

- 日期：2026-10-17
- 状态：用户已批准的高分辨率四方向基准；不是正式游戏素材
- 流程：`frameronin-codex` 方向扩展
- 身份与涂装参考：`../protagonist_sample_v2.png`
- 已批准方向锚点：`aligned/front.png`、`aligned/back.png`、`aligned/left.png`、`aligned/right.png`
- 方向：`front / back / left / right`
- 运行时映射：`front=down`、`back=up`、`left=left`、`right=right`
- 透明原图：`raw/`
- 1536×1536 中间画布：`normalized/`
- 统一脚底后的审核资产：`aligned/`
- 2×2 审核板：`review_board.png`，顺序为左上 front、右上 back、左下 left、右下 right

## 生图调用记录

| 方向 | 调用次数 | 结果与修正 |
|---|---:|---|
| front | 2 | 初稿俯视不足；第二次只提高镜头至明显中高俯视 |
| back | 1 | 首稿通过人工初检 |
| left | 3 | 首稿偏三分之四；第二次纠正为严格侧向；第三次统一双脚基线 |
| right | 2 | 首稿方向与非对称结构正确；第二次统一双脚基线 |
| 合计 | 8 | 每个方向独立生成；左右未使用镜像 |

## 共用提示词契约

```text
Use case: stylized-concept
Asset type: high-resolution directional character anchor — <DIRECTION>

Use the approved FRONT anchor for camera, compact 3.5–4-head proportions, neutral stance, linework, simplified material detail, palette and game-readable foreshortening. Use protagonist_sample_v2.png for identity, construction and asymmetrical paint placement.

Create exactly one complete full-body character facing the requested cardinal direction under a fixed 60-degree downward game camera. Change only the facing direction. Preserve identity, body proportions, armor construction, physical left/right asymmetry, palette, markings, scale, lighting and foot baseline.

Neutral operational stance: feet shoulder-width, equal weight, knees slightly flexed, hands relaxed half-closed, arms slightly separated. Anatomical-left guard arm hangs naturally with the shield plane outward about 15 degrees. Anatomical-right light forearm hangs about 10 degrees outward with a clear elbow layer-separation seam. No weapon.

Square transparent canvas; one centered character; complete head and feet; target height about 77–80 percent; foot baseline about 89 percent. Fixed soft key light from screen upper-left. Clean mechanical line art and restrained cel/material shading. Simplify random micro-scratches.

No mirrored or swapped asymmetry, no extra character, weapon, backpack, mobility module, floor, shadow, text, label, readable number, logo, watermark, detached part, inset, grid, border, cyan bloom, glowing magenta, crop or opaque background.
```

## 方向专用约束

### front

- 面向画面下方。
- 解剖学左侧护臂位于画面右侧；右腕标记与右腿计数位于画面左侧。
- 详细原始提示词与俯视修正提示词见 `front.md`。

### back

```text
Face straight toward the top edge, directly away from the viewer. No front visor should be visible.
From behind, anatomical LEFT appears on image-left and anatomical RIGHT appears on image-right.
Image-left keeps the heavy guard arm and left-temple crossed-eye glyph. Image-right keeps the light arm, wrist interface and right-shin tally group.
Continue the centered communication spine into exactly 4–5 inset dim-cyan upper-back modules, ending between the shoulder blades. No long spine and no backpack.
Show low-profile lower-back and paired hip mounting hardpoints, but attach no mobility module.
Do not add new magenta graffiti to the back torso.
```

### left

```text
Face exactly screen-left in a strict 90-degree cardinal side direction. Helmet, chest, pelvis, knees and all toe axes point left.
With the fixed camera above from screen-bottom, anatomical LEFT is the near side. The heavy left guard arm and its magenta arrow dominate the near silhouette; the left-temple crossed-eye glyph is visible.
The anatomical-right light arm, wrist mark and right-shin tallies remain on the far side and may be partly occluded. Never move or duplicate them.
Both complete split-toe feet point left and end on the same horizontal foot baseline. No stepping or raised foot.
```

定向修正只处理两个失败项：先把三分之四侧前视改成严格侧向，再把远侧脚移到与近侧脚相同的脚底基线；其余结构与标记保持不变。

### right

```text
Face exactly screen-right in a strict 90-degree cardinal side direction. Helmet, chest, pelvis, knees and all toe axes point right.
With the fixed camera above from screen-bottom, anatomical RIGHT is the near side. The light right arm, broken-ring wrist mark and right-shin extraction tallies dominate the near silhouette.
The anatomical-left heavy guard arm remains on the far side as a partial silhouette. The left-temple crossed-eye glyph is hidden or barely glimpsed; never move it onto the visible side.
Both complete split-toe feet point right and end on the same horizontal foot baseline. No stepping or raised foot.
```

定向修正只把远、近两只脚校正到同一脚底基线，其余结构与标记保持不变。

## 本地处理

内置生图四张最终原稿实际均为 1254×1254，未按提示词直接返回 1536×1536。处理过程保留全部原图：

1. `raw/`：保存未经处理的实际生图结果。
2. `normalized/`：不裁切、不缩放、不减色，只把透明画布扩为 1536×1536。
3. `aligned/`：裁取可见包围盒后，以 bottom-center 放入 1536×1370，再从 top-left 扩为 1536×1536，使所有方向的脚底统一到 y=1369；缩放始终为 1.0。
4. `review_board.png`：以 2×2 浅灰审核板展示四向，不作为游戏资产。

## 自动审计

- 文件数：4
- 画布：全部 1536×1536
- 透明背景：全部有效
- 脚底：全部 y=1369
- 可见包围盒底边：全部 y=1370
- 可见面积差异：未触发默认 35% 警告
- 重复帧：无警告
- 审计结果：`directions_audit.json`，`ok=true`、0 errors、0 warnings

## 人工检查

- 通过：四个文件朝向与名称一致；front/back 为正轴向，left/right 为独立生成的侧向稿。
- 通过：重型左护臂在四向间保持真实物理侧；左右方向没有通过镜像互相替代。
- 通过：右腕断环、右腿计数、左头盔遮眼符号和左护臂箭头按方向正确显隐。
- 通过：背部通讯脊终止于肩胛之间；后腰与髋部接口保持低矮，无背包或机动模块。
- 通过：角色身份、封闭头盔、冷灰／炭黑／暗青／洋红配色、线条粗细和中高俯视语言基本一致。
- 通过：无武器、投影、文字、边框、场景或额外对象。
- 注意：生成式方向扩展无法保证装甲接缝和磨损纹理逐像素连续；本组用于身份与方向锚定，不是可直接导入游戏的动画帧。
- 用户验收：2026-10-17 在审核板基础上继续进入像素样板阶段，四方向高分辨率基准视为通过。
