# 主角形象样板 v1

- 日期：2026-10-17
- 状态：AI 设计草案；不是正式游戏素材
- 生成工具：Codex 内置 ImageGen
- 参考图：`C:\Users\one\AppData\Local\Temp\codex-clipboard-b3e23085-7d85-4181-83f5-0b04d0eb5848.jpg`
- 样板图：`protagonist_sample_v1.png`
- 人工修改：无
- 后续：样板形象获批后再制作四向基准图；正式 32×32 像素素材仍需人工重绘、对齐、减色和逐帧检查。

## 已锁定设计

- 人类改造清剿兵，永久机械四肢与模块化外骨骼，不是重型全机器人。
- 约四头身的紧凑战术比例，中性轮廓；封闭式楔形头盔、窄青色面罩与短后脑脊。
- 主色为浅冷灰哑光陶瓷复合装甲，深炭色关节和软质连接层，青色仅用于面罩与通讯脊。
- 胸口至上背中央为分段式 AI 通讯脊；常态暗青，接管、完美格挡和紧急状态时近白青。
- 左重右轻的不对称结构：左肩至前臂为楔形一体护臂，外侧形成短盾面；右臂轻量，五指机械手和隐藏式腕部武器接口。
- 双腿保持人形跖行结构、正常膝关节、分段脚踝和宽大分趾脚。
- 中度、受控的服役痕迹集中于左护臂、膝和靴；左护臂含较深冷灰色替换板。
- 市政应急装备语汇使用切角条块、编号块和维护标记形状，不依赖可读文字。

## 第一轮提示词

```text
Create a brand-new stylized character concept sample for a top-down pixel-action game. Use the attached sketch only as a loose reference for angular hard-surface paneling, segmented mechanical joints, and confident mechanical linework; do not copy its character, pose, proportions, or exact armor shapes.

SUBJECT
One full-body androgynous human military-modified clearing operative in a modular exoskeleton, roughly four heads tall. This is still recognizably a human cyborg, not a giant robot and not heavy power armor. The torso core is flexible and human-shaped; both arms and legs are permanent mechanical prostheses.

POSE AND CAMERA
Front-left three-quarter view, stable combat-ready standing pose. The reinforced LEFT arm is slightly raised outside the chest as a guard. The lighter RIGHT hand is half-closed beside the waist. Show the entire body and feet with generous whitespace. No weapon.

DESIGN
- Fully enclosed lightweight tactical helmet: front-low/back-high wedge silhouette, short rear head spine, narrow dim-cyan visor, no exposed face.
- Medium-light cool-gray matte ceramic-composite armor over charcoal mechanical joints and narrow but clearly visible flexible underlayer bands at the neck, central abdomen, and hips.
- A centered segmented cyan “communication spine” runs from the sternum over the upper torso toward the upper back; it glows dim cyan in normal state.
- Strong left/right asymmetry: LEFT shoulder and forearm form a coherent wedge-shaped reinforced guard arm; the outer forearm has a short integrated shield face, not a separate shield. A few controlled darker cool-gray replacement plates and fasteners appear on this left arm.
- RIGHT arm is visibly lighter and more dexterous: slim forearm, articulated five-finger mechanical hand, discreet concealed weapon-interface hardpoint at the wrist/forearm, but no mounted weapon.
- Human plantigrade mechanical legs with normal knees, segmented ankles, broad stable split-toe feet. Slight controlled service wear on the left guard arm, knees, and boots; visor and cyan communication spine remain intact.
- Municipal emergency-service identity through small cut-corner stripe blocks, number-like blocks, and maintenance-mark shapes, but no readable writing, real logos, or insignia.
- Matte materials, practical field-repair logic, ex-military equipment recalled to service.

STYLE
Professional character-design sample: clean precise mechanical line art, flat color blocking, restrained cel/material shading, readable silhouette, production-oriented design. Pure white or extremely light cool-gray background with only a subtle contact shadow. Moderate detail that can later be simplified into a 32x32 pixel sprite.

STRICT EXCLUSIONS
No weapon, gun, sword, backpack weapon, extra character, alternate pose, inset, turnaround, exploded diagram, scenery, dramatic lighting, cinematic effects, photorealism, painterly rendering, text, captions, labels, logos, watermark, huge shoulder pads, bulky mech proportions, exposed human face, neon nightclub cyberpunk.
```

## 定向修正提示词

第一轮的机械语言和配色可用，但身形过高、过像完整机器人，因此使用第一轮输出作为参考，仅修正比例、躯干读法和防御姿态。

```text
Revise the attached character concept while preserving its successful visual identity: cool light-gray matte ceramic armor, charcoal joints, cyan visor and segmented chest communication spine, angular clean linework, asymmetrical dark-gray reinforced left guard arm, split-toe feet, white background, and no weapon.

Make these targeted corrections:
1. Change the overall proportions to a compact stylized tactical figure about FOUR HEADS TALL. Shorten the legs and slightly enlarge the helmet and torso mass so the silhouette can translate to a 32x32 top-down sprite. Keep it agile, not chibi-cute.
2. Make the torso read more clearly as a human-shaped flexible cyborg core inside modular armor, not a fully armored giant robot. Show narrow charcoal flexible underlayer bands at the neck, central abdomen, and hips.
3. Keep anatomical LEFT arm as the reinforced guard arm, but raise it slightly outward across the side of the chest in a ready defensive pose. Its integrated forearm shield face must remain short and body-mounted, not a large separate shield.
4. Keep the anatomical RIGHT arm light and dexterous, with a visible five-finger hand half-closed beside the waist and a discreet wrist weapon-interface hardpoint, but no weapon.
5. Keep one single full-body front-left three-quarter character, feet fully visible, ample whitespace, subtle contact shadow.

Do not add text, labels, logos, weapon, scenery, second pose, inset, turnaround, diagram, giant shoulder armor, cinematic lighting, or exposed face.
```

## 当前评估

- 已达到：单人全身、无武器、浅冷灰/深炭/青色配色、封闭头盔、左重右轻、分趾脚、白底和受控磨损。
- 基本达到：紧凑战术比例、可见软质躯干、左护臂防御姿态。
- 四向基准阶段仍需解决：背部通讯脊完整走向、俯视 32×32 轮廓取舍、左右独立序列的锚点一致性，以及身体层与右前臂武器层的切分线。
