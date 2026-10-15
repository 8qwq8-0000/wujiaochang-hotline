# 音效接入表

所有新增音效均在 2026-10-15 统一转为 44.1 kHz、16-bit、mono WAV，峰值不高于 -3 dB。

| 文件 | 原文件名 | 当前用途 |
|---|---|---|
| `combat/player_hit.wav` | `受击.wav` | 伤害结算 |
| `combat/pistol_fire.wav` | `手枪音效.wav` | 制式手枪开火 |
| `combat/enemy_death.wav` | `敌人死亡.wav` | 敌人死亡位置 |
| `combat/guard_block.wav` | `格挡声.wav` | 普通格挡与完美格挡 |
| `combat/melee_swing.wav` | `近战挥击.wav` | 初始警棍与掉落警棍挥击 |
| `items/loot_pickup.wav` | `拾取掉落物.wav` | 成功拾取反馈 |
| `mobility/flight_loop.wav` | `飞行.wav` | 飞行套件移动循环 |
| `enemies/reinforcement_approach.wav` | `走动声.wav` | 敌人首次被惊扰后的增援接近提示 |
| `../ui/hotline_dial_01.wav` | `拨号声.wav` | 接线员拨号变体 1 |
| `../ui/hotline_dial_02.wav` | `拨号声2.wav` | 接线员拨号变体 2 |
| `../ui/hotline_connect.wav` | `热线接通音效.wav` | 接线员接通确认 |

热线音效已注册到 `AudioCueManager.play_hotline_dial()` 与 `play_hotline_connect()`；现阶段没有正式接线员时间线，因此不在开局自动播放。

增援接近提示由敌人首次进入警戒时触发，并设有 3 秒防刷屏。当前版本尚未实现真正的增援生成，只接入了与警戒事件一致的听觉预告；后续增援生成器可继续复用同一事件。

这些原始文件由项目成员放入仓库，但来源、作者、生成工具及商用许可尚未登记。许可确认前仅限私有开发占位，不得进入公开构建。
