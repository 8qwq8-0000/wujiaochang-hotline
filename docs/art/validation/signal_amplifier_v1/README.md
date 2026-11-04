# 信号增幅者与掉落平衡（2026-10-29）

> 本目录保存早期外观预览，现已由 `../signal_herald_v3/` 的举旗传令兵替换。当前第二层起每个普通战斗区域均有一只。

信号增幅者使用现有远程兵四方向 SpriteFrames，叠加紫色重着色、程序绘制的接收背包、天线摆动、广播脉冲和死亡断链动画；没有新增外部生成素材。`animation_preview.gif` 是 Godot 实机渲染的动作预览。

- 第二层最后一个区域、第三层每个区域各替换一只后排远程兵，总敌人数不变。
- 自身基础生命 3（沿用楼层生命加成），移速 45，攻击间隔 2.8 秒，抬手 0.55 秒。
- 活着时使同区域其他近战、远程、盾兵移速乘 1.3，攻击间隔乘 0.7，受到伤害乘 0.6。增幅者之间不互相强化，多个来源不叠加，不强化场景炮塔。
- 受强化者的攻击抬手不变。减伤累计小数余量，五次 1 点伤害合计扣 3 点生命；击破最后一个信号源后立即解除。
- 第二、三层近战基础移速分别为 110、120；叠加信号后为 143、156。
- 霰弹枪、激光炮各自的随机装备掉落权重从原来的 1/11 调为 3/42，约 9.09% → 7.14%。这是已经触发装备掉落后的条件概率，总掉落率和品质概率不变。

复现预览：`godot --path . --script tools/preview_signal_amplifier.gd`，需图形环境，输出 65 帧到 `/tmp/hotline-signal-animation/`。

验证入口：`tests/integration/enemy_signal_check.gd`、`tests/integration/floor_difficulty_check.gd`、`tests/integration/enemy_animation_check.gd` 和 `tests/run_unit_checks.gd`。自动检查与动画预览不代表已经完成整局平衡试玩。
