# 战斗音效实现

更新日期：2026-10-22

运行时 WAV 由项目自制音效与 Kenney CC0 素材离线混合，避免战斗中实时叠轨。可使用以下命令重新生成本轮新增资源：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_combat_audio.ps1
```

生成脚本需要 FFmpeg；默认查找 `c:\ffmpeg\bin\ffmpeg.exe`，也可通过 `-Ffmpeg` 指定路径。输出统一为 48 kHz、16-bit、单声道 WAV，并预留至少约 0.8 dB 峰值余量。

## 运行时分组

- `weapon_fire/`：制式手枪、热能散射器、腕锁激光炮各 4 个洗牌变体；保留自制 `pistol_fire.wav` 作为共同机械底层。
- `weapon_hits/`：三种武器的居中命中主体，以及按敌人重量区分的空间金属层。
- `defense/`：4 个共用格挡金属主体；完美格挡额外叠加 3 个居中能量层，并按连续成功提升至最多 5 档。
- `kills/`：3 个居中击杀确认音；重甲敌人额外播放 2 个空间低频重量层。
- `player/`：4 个非人声受伤变体、2 个重伤低频层，以及危险血量的一次警示和稀疏心跳。

`CombatAccent` 总线承载完美格挡、轨道炮释放、击杀确认和重甲死亡等关键信号。关键事件会在 80 ms 内将 `SFX` 与 `Music` 短暂压低 2.5 dB，提示音自身不受影响。

原始包、许可证、下载地址和 SHA-256 记录位于 `art_sources/audio/third_party/kenney/`。Kenney 素材采用 `CC0-1.0`，无需署名；仍保留许可证用于审计。
