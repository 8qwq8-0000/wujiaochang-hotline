# 龙娘四方向移动动画

2026-11-03。已完成二、三层旧前置清理及龙娘动画资源制作。按后续要求，仓库、Codex 整备通道、序章三处龙娘均已替换为 `dragon_visual.tscn`；正式同行、协作及招募流程尚未接入。

- 原型参考：`assets/art/environment/refined/gpt_synthesist.png`，保留白发、浅紫角、白色服装、翅膀、尾巴。
- 图集：`assets/art/characters/companions/dragon_gpt_v1/walk_atlas.png`，1536×1024，六列四行，透明 PNG，方向依次为下、左、上、右。
- 动画：同目录 `frames.tres`，四个六帧 walk 循环，8 fps 基准，同行时读取主角行走步频；四个单帧 idle。左右独立素材，不使用水平翻转代替方向。
- 组件：`scenes/actors/companions/dragon_visual.tscn`；`DragonSpriteAnimator.update_motion()` 根据移动量切方向，停下保留朝向；斜向分界与主角相同。
- 原点：256×256 逻辑帧，脚底 (128,232)；同方向六帧共用一个原点，保留实际步幅，不按每帧伸出的脚重新居中。`.tres` 仅裁切/补齐纹理区域，不改绘原始 PNG。角色缩放 0.22，与主角实际尺寸对比验收。
- 生成方式：先试用用户本机 Draw Things 的 Z Image Turbo 1.0 (8-bit S)，8 步、UniPC Trailing。试稿只得到三排且绝大部分为左侧站姿，未采用。正式素材使用内置 imagegen，一次动作图集生成、一次背景去除，未调用付费外部 API。原立绘文件作为参考保留，三处游戏角色已换用新版组件。
- 验证：初版 headless 20 项与窗口 20 项检查通过；检查四方向选取、帧推进、停步朝向、脚底原点；窗口确认透明背景、四方向和主角尺寸对比。既有退出资源释放诊断仍存在。

## 预览与导入

```sh
godot --headless --path . --script res://tests/integration/dragon_animation_check.gd
godot --path . --windowed --resolution 1280x720 --script res://tests/integration/dragon_animation_check.gd -- --preview
uv run --with pillow --with numpy python tools/import_dragon_animation.py
```

追加 `--capture` 保存 `/tmp/hotline-dragon-animation.png`。窗口预览顶部放大对比四方向循环，底部显示正式大小的主角与龙娘；本目录 `preview.png` 是实机截图。

## 正式生成提示词

Use case: identity-preserve. Asset type: production sprite atlas for a top-down 2D pixel art action game. Use attached dragon girl as identity reference. Make ONE transparent PNG sprite atlas, landscape 1536x1024, exactly SIX columns and FOUR rows. All 24 cells equal 256x256. Every cell contains one COMPLETE full-body small pixel-art version of this SAME white-haired lavender-horned dragon girl, white dress, detached sleeves, small lavender wings, long lavender tail, lavender eyes, white shoes. Simplify details into crisp readable pixel clusters. Keep her recognizable; no weapon or new accessories. Each sprite fits within its cell with generous padding and identical scale, feet centered at x=128,y=232 within cell, maximum sprite height 200px. EXACT ROW ORDER: row 1 WALK DOWN (front view toward viewer); row 2 WALK LEFT (strict left profile, face toward left edge); row 3 WALK UP (back view away from viewer, NO FACE/EYES VISIBLE, back of hair and wings); row 4 WALK RIGHT (strict right profile toward right edge). Each row is a six-frame complete walking loop IN PLACE. Frame 1 left foot forward right foot back; 2 left foot planting and right foot lifting; 3 feet passing under body; 4 right foot forward left foot back; 5 right foot planting left foot lifting; 6 feet passing back under body. Make distinct visible leg positions and counter-swing arms, subtle hair/tail sway with consistent horns, body proportions, floor baseline and torso placement. Front and back rows must visibly alternate stepping feet; side rows must visibly stride. Camera slightly above like a classic 2D RPG, no perspective change between frames. No cell borders, no labels, no numbers, no text, no background, no ground shadows. True alpha transparency. Exactly four rows, six columns, 24 characters. Do not replace the walk with repeated static standing poses.

背景去除提示词：

Remove the entire pale background from this exact sprite sheet. This is background extraction ONLY. Preserve all 24 dragon girl sprites pixel for pixel, their white hair and white clothing, the 6-column 4-row layout and 1536x1024 dimensions. Deliver actual clean cutouts on FULLY TRANSPARENT background, PNG alpha exactly zero outside sprites, NOT a white or light-gray backdrop, NOT a partly transparent white rectangle, NOT a checkerboard painted in the image. Keep only character pixels with opaque interiors. No shadows, no added scenery, no pose changes, no rearrangement, no extra content. Entire space between all characters must be fully transparent.

## 游戏内替换验收

仓库、Codex 整备通道和序章均实例化同一龙娘组件，默认朝下待机。仓库脚底仍在原排序位置 (110,140)，整备通道保留原视觉脚底位置；序章保留原角色高度。交互 Area2D、工作台和碰撞不变。窗口截图：`warehouse_replaced.png`。

整备通道 34 项、仓库布局 63 项、仓库碰撞 48 项通过。合成检查 40 项中有 6 项失败，替换前的旧静态角色场景同样复现这 6 项失败（涉及既有保底武器/材料夹具），并非此次视觉替换新增。

序章检查 134 项中 1 项失败（完整教程不写入练习装备的存档断言）；以旧静态角色覆盖服务绘制做对照后，同一断言仍失败（对照共 135 项）。本次替换未新增该失败。`git diff --check` 通过；未进行移动端验收。

## 步频与跟随修正

按实机反馈，将走路动画基准从 8 fps 降至 4 fps，并按真实位移速度调节播放倍率；低速靠近时脚步也放慢。跟随控制改为按距离差平缓减速，避免追到阈值反复起步/停步、重置第一帧。相同 3 秒通道试走中，走路/待机切换从 17 次降至 3 次（起步、转向、停下），正常步行能连续推进到后续帧。新增慢速步频检查后动画专项为 24 项。可运行 `godot --path . --script res://tools/inspect_codex_walk.gd` 复查；该脚本使用独立存档并自动结束。

用户随后要求与主角同频：已取消独立的减半/按移速调频，同行动画直接读取主角行走片段的帧率和播放倍率。原先平滑跟随、避免走停重置的修正继续保留；上段独立 4 fps 调整已被本次同频方案取代。动画专项 24 项覆盖主角播放倍率变化与慢移速下保持同频，同行回归 45 项通过。
