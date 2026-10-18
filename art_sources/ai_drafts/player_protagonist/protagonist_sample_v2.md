# 主角形象样板 v2：街头改装涂装

- 日期：2026-10-17
- 状态：AI 设计草案；不是正式游戏素材
- 模式：基于 `protagonist_sample_v1.png` 的精确对象编辑
- 生成工具：Codex 内置 ImageGen
- 内置生图次数：1
- 编辑目标：`protagonist_sample_v1.png`
- 输出：`protagonist_sample_v2.png`
- 人工修改：无
- 后续：用户确认涂装方向后，再将该涂装规则带入四方向基准图；正式 32×32 像素素材仍需人工重绘和逐方向检查。

## 角色与涂装锁定摘要

- `v1` 的角色身份、封闭头盔、四肢结构、左侧一体护臂、右侧操作手、比例、姿态和青色 AI 光效保持不变。
- 装备属于市政外包装备池，由历任受 AI 指引的临时工反复领取、回收和维修。
- 市政底层标记使用低饱和蓝灰与灰白；青色只属于 AI 面罩和通讯脊。
- 街头层使用不发光的偏紫旧品红，新漆参考色为 `#D62C8B`，总覆盖约 10% 或更少。
- 左护臂是主要“移动涂鸦墙”：磨损洋红斜向箭头，周围叠加计数、缺口方框、断链暗语和被划改的资产块。
- 头盔后侧太阳穴：灰白抽象遮眼符号和一笔褪色洋红斜线，不遮挡青色面罩。
- 右腕接口：较新的“断开的环形箭头包围一点”，表示接受 AI 指引但保留自主权。
- 右小腿：四笔褪色撤离记录和一笔尚未完成的新痕。
- 地下符号系统以求生信息为主、劳工抵触为辅；箭头、计数短杠和缺口方框是主要语汇。
- 所有标记绑定真实物理侧；进入四方向时不得镜像换边。
- 32×32 游戏帧只强制保留左护臂洋红箭头色块、右腕亮点和右腿计数节奏；完整符号留在高分辨率样板中。

## 最终编辑提示词

```text
Use case: precise-object-edit
Asset type: protagonist concept-art paintover, version 2

EDIT TARGET
The attached image is the exact character and composition to preserve.

PRIMARY REQUEST
Add a restrained cyberpunk street-modification paint layer to the existing character. Change only surface paint, stencils, small symbolic marks, and age differences between paint layers.

ABSOLUTE INVARIANTS
Preserve the exact character identity, helmet, face covering, body proportions, pose, silhouette, armor geometry, mechanical joints, hands, feet, left integrated guard-arm structure, camera angle, white background, contact shadow, line-art style, material rendering, existing wear, and cyan visor/communication-spine lighting. Do not redesign, reshape, replace, remove, crop, or add any equipment. No weapon. Keep one full-body character.

PAINT SYSTEM
- Existing suit remains predominantly cool light gray and charcoal.
- Add subdued municipal equipment-pool markings underneath: desaturated blue-gray and gray-white cut-corner asset blocks and partial stencil-like inventory shapes. They may resemble numbers but MUST NOT form readable text, letters, logos, or real numerals.
- Add non-luminous matte street paint in old purple-leaning magenta, fresh tone approximately #D62C8B. Total magenta coverage must remain around 10 percent or less.
- Old marks are faded, scraped, overwritten, and partly covered by repairs. The current operator's single personal mark is fresher and brighter.
- Cyan remains the only emissive color. Magenta paint must not glow, bloom, or resemble neon light.

EXACT PHYSICAL-SIDE PLACEMENT
1. ANATOMICAL LEFT reinforced guard arm — the large dark-gray shield-like arm on the RIGHT side of the image: make this the main mobile graffiti wall. Add one bold but partly abraded diagonal magenta directional arrow across the outer forearm shield surface. Around it add a few small gray-white survival marks: short tally strokes, incomplete square glyphs, a subtle broken-chain-like glyph, and a partly crossed-out municipal asset block. Keep the marks sparse and layered, not a dense collage.
2. Helmet rear-side temple, without touching the cyan visor: add a small gray-white abstract crossed-eye glyph with one faded magenta slash. Symbolic only, no literal realistic eye.
3. ANATOMICAL RIGHT wrist weapon-interface casing — the slimmer hanging arm on the LEFT side of the image: add one fresh small magenta personal symbol, an incomplete circular arrow surrounding one dot. Keep it crisp, tiny, and clearly painted on the casing.
4. ANATOMICAL RIGHT shin — the leg on the LEFT side of the image: add four faded gray-white withdrawal tally strokes plus one newer unfinished short stroke. Keep this subtle and aligned to the armor panel.

VISUAL HIERARCHY
At first glance, the viewer must still read the cool-gray player silhouette and cyan AI signals. At second glance, discover the magenta guard-arm arrow and layered worker marks. The paint should communicate recycled municipal contractor armor modified by successive AI-guided temporary workers: survival information first, labor resistance second.

AVOID
No readable words, slogans, letters, brand marks, real numbers, logos, decals with text, stickers, additional cyan, yellow, orange, red, new glowing areas, graffiti covering the chest communication spine, nightclub neon styling, background changes, new objects, new armor panels, new damage, or geometry changes.
```

## 人工质量检查

- 通过：单人全身、无武器、白底、既有轮廓、封闭头盔、左护臂和青色 AI 光效均保留。
- 通过：洋红不发光，主要集中于左护臂；右腕、头盔后侧和右腿均出现对应标记。
- 通过：不存在可读文字、真实编号、品牌 Logo 或额外场景元素。
- 通过：第一视觉层仍是冷灰轮廓和青色 AI 信号，洋红处于第二视觉层。
- 注意：生成式编辑会重绘表面线条、磨损和少量边缘细节，不能视为与 `v1` 像素级完全相同；该图用于确定涂装语言，不作为精确生产覆盖层。
- 注意：当前仍是高分辨率概念图，尚未验证四方向一致性、32×32 可读性、脚底锚点或动画帧连续性。
