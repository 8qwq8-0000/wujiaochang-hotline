# Kenney CC0 音效候选库

获取日期：2026-10-21

用途：为现有自制战斗音效提供材质、瞬态和科幻效果叠层。这里保存原始下载包和完整解压内容；尚未接入游戏运行时。

## 来源与校验

| 素材包 | 官方页面 | 网页标称资产数 | 压缩包内音频条目 | SHA-256 |
|---|---|---:|---:|---|
| Impact Sounds 1.0 | https://kenney.nl/assets/impact-sounds | 130 | 130 | `029D734AF1582474EDF3A694D1B0CEBC97C1C152F2F39FA34D4C2BAFC5DE77F8` |
| RPG Audio 1.0 | https://kenney.nl/assets/rpg-audio | 50 | 52（含预览等附加音频） | `6DBEAF8544DA958D8F2ADCB4A4A4B76C1ADE34A05F8AB9EDCCD327DA7375F38B` |
| Sci-Fi Sounds 1.0 | https://kenney.nl/assets/sci-fi-sounds | 70 | 73（含预览等附加音频） | `119340F351A5098AD814F78719438C0DA355A9CE8A4C8A3AF6A8D48AA3D49E04` |
| Digital Audio 1.0 | https://kenney.nl/assets/digital-audio | 60 | 63（含预览等附加音频） | `24E6CE28B76A6D8C89CFF4D331E0965FF5C3DE8A73C612028E9D363CC64E4F06` |

每个解压目录都保留了原始 `License.txt`。许可证为 Creative Commons Zero 1.0（CC0-1.0），允许个人及商业项目使用，署名不是强制要求。

## 首轮试听候选

- 普通敌人受击：`impactPunch_heavy_*`、`impactPunch_medium_*`、`impactSoft_heavy_*`。
- 普通格挡：`impactMetal_light_*`、`impactPlate_light_*`。
- 完美格挡：`impactMetal_heavy_*`、`impactPlate_heavy_*`，与自制高频瞬态叠加。
- 金属或硬表面：`impactMetal_*`、`impactMining_*`、`impactTin_*`。
- 刀刃动作：`knifeSlice*`、`drawKnife*`。
- 电击与能量：`zap*`、`forceField_*`、`laserSmall_*`。
- 爆炸与击杀低频：`explosionCrunch_*`、`lowFrequency_explosion_*`。

## 使用约束

1. 不直接用素材库声音替换现有自制主体声；优先作为低音、材质或瞬态叠层。
2. 只有经过试听、裁切、响度处理并确认用途的少量成品，才复制到 `assets/audio/sfx/`。
3. 复制到运行时目录时，在文件名或配套清单中记录原始包名和原始文件名，保证来源可追溯。
4. 原始压缩包、解压目录及许可证保持不改动。

## Sonniss 状态

Sonniss GDC 2026 包未下载。官方仅提供总计约 7.47 GB 的五个分卷，当前环境访问主下载遭 Cloudflare 拒绝，Google Drive 官方镜像也无法连接。不得使用第三方转载包替代官方来源。
