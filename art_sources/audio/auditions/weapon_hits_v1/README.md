# 武器命中音效试听包 v1

生成日期：2026-10-22

状态：试听选择已完成；正式变体已输出到 `assets/audio/sfx/combat/weapon_hits/`。

最终选择：制式手枪 A、热能散射器 C、腕锁激光炮 A。

## 共同设计

- 以项目自制 `assets/audio/sfx/combat/player_hit.wav` 作为短促主体层。
- 使用 `art_sources/audio/third_party/kenney/` 中的 CC0 音效作为冲击、金属、能量和低频层。
- 输出格式统一为 44.1 kHz、16-bit、单声道 WAV。
- 手枪约 0.45 秒，散射器约 0.55 秒，激光炮约 0.70 秒。
- 峰值不超过约 -1 dBFS；试听文件的响度仅用于横向比较，接入游戏时仍需按武器发射声重新混音。

## 候选说明

| 文件 | 设计方向 | 主要素材层 |
|---|---|---|
| `pistol_A_dry_punch_metal.wav` | 干脆、直接、带轻金属尾音 | 自制主体 + 中型拳击 + 轻金属 |
| `pistol_B_tight_plate.wav` | 更硬、更短、更机械 | 自制主体 + 中金属 + 轻钢板 |
| `pistol_C_cyber_snap.wav` | 较鲜明的赛博电击感 | 自制主体 + 中型拳击 + 短电击 |
| `scattergun_A_heavy_body_metal.wav` | 厚重的身体冲击 | 自制主体 + 重拳击 + 中金属 |
| `scattergun_B_soft_crunch.wav` | 宽、碎、带爆裂质感 | 自制主体 + 重软体冲击 + 脆裂爆炸 |
| `scattergun_C_thermal_blast.wav` | 热能武器感更强 | 自制主体 + 重拳击 + 低频爆炸 + 金属 |
| `rail_A_laser_metal_bass.wav` | 清晰激光头与金属落点 | 自制主体 + 大型激光 + 重金属 + 低频 |
| `rail_B_force_plate_crunch.wav` | 护盾/力场式重击 | 自制主体 + 力场 + 重钢板 + 脆裂爆炸 |
| `rail_C_zap_bass_metal.wav` | 电弧与持续低频更突出 | 自制主体 + 电击 + 低频爆炸 + 重金属 |

## 下一步

每种武器选择一个方向后，再围绕该方向制作 3–5 个同族变体。接入游戏时，主体声保持居中，敌人材质薄层改为在受击位置播放；散射器命中使用约 35 毫秒的聚合窗口。
