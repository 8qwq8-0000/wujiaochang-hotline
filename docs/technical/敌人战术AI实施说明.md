# 敌人战术 AI 实施说明

> 状态：已实现并通过自动检查
>
> 日期：2026-10-15

## 1. 架构

`EnemyTacticalBrain` 是纯 `RefCounted` 决策器，不移动节点、不查询物理世界，也不生成攻击。它接收 `EnemyController` 提供的战斗快照并返回一个战术意图：

- `APPROACH`：直接沿导航接近；
- `FLANK_LEFT / FLANK_RIGHT`：从玩家两侧接近；
- `HOLD_AND_ATTACK`：停止换位并进入既有攻击前摇；
- `RETREAT`：远程敌人贴身时后撤或沿掩体侧移；
- `STRAFE_LEFT / STRAFE_RIGHT`：远程武器冷却期间保持距离横移；
- `INTERCEPT`：重型敌人有限预测可见目标的位置。

`EnemyController` 继续拥有：视野、听觉、最后已知位置、导航、RVO、卡住恢复、攻击、硬直、伤害和死亡。这避免出现两套系统同时控制速度或攻击状态。

## 2. 决策规则

### 近战施压者

- 单独行动时直接追击；
- 96 px 内存在另一名已警戒同伴，且距离大于攻击距离的 1.75 倍时，按稳定左右侧选择包抄点；
- 包抄点取玩家周围导航面上的弧形候选；
- 候选不可达时安全回退为直接追击；
- 进入攻击距离立即切回原有攻击前摇。

### 视线射手

- 小于攻击距离的 62% 时立即撤退；
- 后方被墙或掩体占用时，依次扩大到 `±90°` 的侧向候选；
- 在射程内且武器冷却未完成时，沿玩家周围横移；
- 横移候选必须可导航并继续保持对玩家的视线；
- 冷却完成后立即停止换位并进入射击前摇。

### 重型锚点

- 射程外追击玩家当前可见移动方向上的预测点；
- 默认预测 0.25 秒；
- 预测位移最多 48 px，避免高速机动导致不自然的大幅超前；
- 进入攻击距离立即使用原有重击前摇和击退。

## 3. 稳定性与性能

- 默认决策间隔为 0.15 秒，重型为 0.2 秒；
- 攻击窗口和贴身撤退属于紧急边界，不等待下一次普通决策；
- 战术目标缓存 0.3 秒，玩家移动超过 8 px 或目标抵达后才重新选择；
- 同伴查询限制在同一战斗房间和 96 px 邻域；
- 寻路、RVO 与卡住恢复继续复用现有实现；
- `EnemyProfile.tactical_enabled` 可对单个敌人关闭战术层，恢复原有直接逻辑。

## 4. 数据参数

`EnemyProfile` 新增：

| 参数 | 默认值 | 说明 |
|---|---:|---|
| `tactical_enabled` | `true` | 是否启用战术决策 |
| `decision_interval` | 0.15 s | 普通决策刷新间隔 |
| `flank_radius` | 48 px | 近战侧袭目标半径 |
| `flank_angle_degrees` | 42° | 包抄旋转角 |
| `strafe_angle_degrees` | 20° | 远程横移旋转角 |
| `target_prediction_seconds` | 0.2 s | 目标预测时间 |

当前资源覆盖：近战包抄半径 44 px、角度 48°；远程横移角 18°；重型决策间隔 0.2 秒、预测 0.25 秒。

## 5. 自动检查

```text
godot --headless --path . --script res://tests/run_unit_checks.gd
godot --headless --path . --script res://tests/integration/enemy_tactics_check.gd
godot --headless --path . --script res://tests/integration/enemy_navigation_check.gd
godot --headless --path . --script res://tests/integration/enemy_loot_check.gd
godot --headless --path . --script res://tests/integration/enemy_patrol_check.gd
godot --headless --path . --script res://tests/integration/spawned_patrol_check.gd
godot --headless --path . --script res://tests/integration/enemy_alert_check.gd
godot --headless --path . --script res://tests/integration/enemy_combat_upgrade_check.gd
godot --headless --path . --script res://tests/integration/playthrough_check.gd
```

结果：40/40 单元测试通过，上述敌人／流程集成检查全部为 0 失败，完整通关循环连续通过 3 次。

覆盖内容：纯决策规则、0.15 秒决策稳定、相反方向包抄点、远程横移射界、重型有限预测、贴身撤退、墙体绕行、16 敌人软避让、警戒传播、出生巡逻和原有攻击前摇。

## 6. 感知与群体警戒升级

- 三类敌人使用以自身为中心的 `640 × 360` 检测包络、`120°` 视锥和墙体射线；窗口分辨率不会扩大基础感知范围。
- 真实目视确认后才共享玩家最后确认位置。标准警戒只通知发现者周围 `320 px` 的同房间敌人，高压警戒通知同房间全部敌人。
- 共享位置最多每 `0.5 s` 更新一次，并要求玩家相对上次广播移动至少 `48 px`；不会跨房间传播。
- 枪声使用通用噪声事件，各敌人按距离与遮挡独立前往调查，不能直接触发全员共享警戒。
- 敌人抵达最后噪声位置后搜索 `1.5 s`。受到伤害只让受击者锁定来源，不凭空通知同伴。

## 7. 预蓄力、角色强化与自爆

- 目视获取玩家时立即为第一次攻击预蓄力；完成后进入有效距离且仍有视线便直接出手。
- 丢失视线、硬直或离开房间会取消预蓄力。测试开关“连续蓄力”开启后，后续攻击也可在冷却期预蓄力。
- 近战施压者战斗移动速度为 `125 px/s`，攻击前摇 `0.3 s`、冷却 `0.65 s`；巡逻仍保持约 `47.5 px/s`。
- 重型锚点普通攻击击退为 `220`；死亡后等待 `0.45 s` 自爆。自爆半径与攻击距离同为 `34 px`，伤害 `1`、击退 `260`，受墙体遮挡，可误伤敌人并触发连锁，直到爆炸结算后才计入击杀、掉落和清场。
- 自爆额外发出 `300 px` 通用噪声，并用程序绘制闪烁与扩散环，不新增美术素材。

## 8. 狙击手脚步调查

- 显示名称改为“狙击手”，内部角色 ID 与资源路径保持兼容。
- 只有狙击手订阅移动噪声，阈值为 `80 px`：步行 `90`、四足 `140`、轮式 `180`、机动能力爆发 `220`，飞行常规移动静音。
- 常规移动每 `0.35 s` 发出一次脉冲；狙击手最多每 `0.4 s` 更新调查点。脚步只会引发调查，必须实际看见玩家才进入警戒并共享位置。

## 9. 设置与测试期调参

- `GameSettingsController` 将“高压难度”和“连续蓄力”拆成互不绑定的开关，默认都关闭，并复用 Maaack `PlayerConfig/AppSettings` 保存。设置页的“难度”分区明确说明标准模式为 `320 px` 响应、高压模式为同房间全员响应；连续蓄力留在独立的“AI 测试”分区。
- Esc 暂停菜单提供继续、设置；背包或撤离界面打开时 Esc 优先关闭当前界面。
- 分辨率支持 `1280×720`、`1600×900`、`1920×1080`、`2560×1440` 与全屏；显示改动需要在 `10 s` 内确认，否则恢复。
- 音频页提供 Master、Music、SFX 三路音量与全部静音。
- 专项检查 `settings_menu_check.gd` 验证暂停所有权、三路音频控件和两个独立 AI 开关。
