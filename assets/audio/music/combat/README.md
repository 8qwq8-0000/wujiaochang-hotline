# 战斗音乐

| 文件 | 游戏用途 | 原文件名 | 时长 |
|---|---|---|---|
| `combat_regular_01.ogg` | 普通战斗轮播 1 | `战斗曲1.wav` | 199.715 秒 |
| `combat_regular_02.ogg` | 普通战斗轮播 2 | `战斗曲2.wav` | 196.743 秒 |
| `combat_boss_phase_01.ogg` | BOSS 第一阶段 | `BOSS曲阶段一.wav` | 76.185 秒 |
| `combat_boss_phase_02.ogg` | BOSS 第二阶段 | `BOSS战斗曲阶段二.wav` | 195.721 秒 |

2026-10-15 使用 FFmpeg 转为 44.1 kHz、stereo OGG Vorbis，并将峰值统一留在约 -7 dB，符合《素材制作基线》的长音乐规范。普通战斗由 `CombatMusicController` 自动轮播；BOSS 房间在阶段变化时调用 `start_boss_phase(1)` 或 `start_boss_phase(2)`，战斗结束调用 `end_boss_music()`。

四个原始文件由项目成员放入仓库，但来源、作者、生成工具及商用许可尚未登记。开发期可作内部占位；许可确认前不得用于公开构建。
