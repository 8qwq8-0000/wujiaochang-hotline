# Tests

双战斗区域：`godot --headless --path . --script res://tests/integration/dual_area_check.gd`，覆盖真实通道碰撞、清场解锁、按进入激活第二区、全层目标累计、生命/热量/装备保留、各区增益失效、一次性补给和最终出口限制。

射击输入与方向：`godot --headless --path . --script res://tests/integration/shooting_input_check.gd`，覆盖 HUD 点击透传、上下左右子弹方向与实际物理帧移动，防止向上子弹碰到发射者自身而消失。

撤离结算：`godot --headless --path . --script res://tests/integration/extraction_check.gd`，覆盖真实出口选择、未清场/死亡拒绝、继续层状态保留、暂停恢复、装备与背包带出、重复结算、返回仓库及带装备再次出击。使用独立测试存档，不修改玩家存档。

仓库储物箱：`godot --headless --path . --script res://tests/integration/warehouse_check.gd`，覆盖项目仓库入口、真实 E 键与鼠标存取、暂停恢复、装备槽物品同步、满包/绑定拒绝、实例属性保留、保存失败回滚、全新实例读档、场景重建、出击与撤离返回，以及损坏存档保护。使用独立测试存档。

黑匣与死亡保护：`godot --headless --path . --script res://tests/integration/blackbox_check.gd`，覆盖独立格、保险核心实例与唯一性、背包入口、暂停换装、满包交换、伤害结算期间禁止切换、旧状态迁移、保存失败回滚、死亡重试、回仓、核心丢失、已触发核心保护及 R 放弃行动。使用独立测试存档。

背包拖放：`godot --headless --path . --script res://tests/integration/inventory_drag_check.gd`，用真实鼠标事件触发原生 drag/drop，验证主副武器、机动与黑匣交换、空位、满包、背包排序、无效目标、拖出取消、关闭时取消、异物/过期实例拒绝，以及写入失败时保留实例与冷却。

放置 `test_*.gd` 测试脚本。优先覆盖：

- 组件词条继承与最高值合并
- 背包容量和固定装备槽
- 撤离、死亡、黑匣和保险核心结算
- 存档升级与往返读取
- 房间抽取的重复限制

当前已加入：

- `test_combat_core.gd`：阵营倍率、整数伤害、120° 完美格挡与背击绕过；
- `test_mobility.gd`：步行与三种机动套件的能力边界；
- `test_floor_assembler.gd`：手工房间池的加权抽取边界。
- `test_player_scene.gd`：玩家场景节点契约、默认装备、断路保险换装不刷新，以及天赋核心协议/天赋/接管次数持久化。
- `test_weapon_scenes.gd`：四件武器的场景契约、最近邻显示，以及新武器模板不会自动进入掉落池。
- `test_projectile_scene.gd`：射弹占位贴图、最近邻缩放、碰撞半径，以及方向和阵营色同步。
- `test_combat_music.gd`：主场景的两首普通战斗曲、两首 BOSS 阶段曲及阶段切换接口。
- `test_combat_audio.gd`：战斗、武器、机动和热线音效资源映射，以及玩家空间移动音频挂点。
- `test_combat_notice_queue.gd`：三档优先级、三条预算、同类消息合并与旧消息接口兼容。
- `test_afterimage_vfx.gd`：机动残影复制当前帧／镜像状态、对象池上限和按来源清理。
- `test_enemy_navigation.gd`：敌人软避让参数与无导航网格时的安全退避回退。
- `test_enemy_tactical_brain.gd`：近战协同包抄、远程撤退／横移／射击、重型预测拦截与决策节流。
- `test_enemy_combat_upgrade.gd`：敌人角色参数、独立 AI 难度开关和暂停设置场景契约。

可从 Godot AI 测试面板运行全部 `test_*.gd`，也可在编辑器中打开主场景后执行测试。

重开流程另有独立集成检查（不通过 MCP 单元测试面板运行）：

```sh
godot --headless --path . --script res://tests/integration/restart_room_check.gd
```

覆盖 R 键输入、忽略按键重复、连续触发合并，以及战斗中、死亡后、清场后的三次重开；检查玩家/敌人/热量/出口重置与旧子弹清理。

组件和敌人检查也可独立运行：

```sh
godot --headless --path . --script res://tests/integration/inventory_check.gd
godot --headless --path . --script res://tests/integration/enemy_loot_check.gd
godot --headless --path . --script res://tests/integration/playthrough_check.gd
```

队友房间合并并应用接入补丁后，再运行 `tests/integration/week1_room_check.gd`；缺少房间时输出 SKIP。接入方法见 `docs/technical/组件背包与掉落实施说明.md`。

背包全图暂停检查：`godot --headless --path . --script res://tests/integration/inventory_pause_check.gd`，覆盖敌人/子弹/热量/冷却停止，界面操作、Tab/Esc、死亡、暂停中重开和场景退出恢复。

双武器携带与切换：`godot --headless --path . --script res://tests/integration/weapon_switch_check.gd`，覆盖主/副目标槽、Q/滚轮、空槽跳过、冷却/热量保留、满包替换及战斗/暂停/死亡限制。

双空槽重新装备：`godot --headless --path . --script res://tests/integration/weapon_slot_refill_check.gd`，覆盖主副武器都卸下后，把两件武器分别拖到主、副槽，目标槽不会相互覆盖。

首次武器自动装副槽：`godot --headless --path . --script res://tests/integration/first_weapon_pickup_check.gd`，覆盖战斗中拾取、满包、副槽占用、仅首次触发、当前武器保留、立即使用和重复拾取保护。

装备不占格与开局配置：`godot --headless --path . --script res://tests/integration/backpack_weapon_capacity_check.gd`，覆盖初始 0/6、独立主副武器与机动槽、满包拒绝卸下、满包安全替换、卸下后占格和实例不重复。

集成分支：`integration/week1` 暂不接入 last1118 的关卡；`week1_room_check.gd` 的 SKIP 不计为通过。

房间切换：`godot --headless --path . --script res://tests/integration/room_transition_check.gd`，覆盖背包与装备快照、实例编号、首次拾取资格，以及旧房间掉落／子弹清理。

单元检查：`godot --headless --path . --script res://tests/run_unit_checks.gd`。

敌人警戒：`godot --headless --path . --script res://tests/integration/enemy_alert_check.gd`，覆盖视野角度/距离/墙体、声音半径/遮挡/暂停、受击、目标记忆、附近同伴传播与防止递归、场景隔离和真实枪击事件。实施与参数见 `docs/technical/敌人警戒实施说明.md`。

敌人巡逻：`godot --headless --path . --script res://tests/integration/enemy_patrol_check.gd`，覆盖出生点附近往返、端点停留、暂停、警戒中断与返回、墙体阻挡、关闭巡逻和死亡。

敌人导航压力检查：`godot --headless --path . --script res://tests/integration/enemy_navigation_check.gd`，在原型房间用 16 名敌人覆盖软避让、绕开墙体／掩体，以及不持续完全重叠。

敌人战术决策：`godot --headless --path . --script res://tests/integration/enemy_tactics_check.gd`，覆盖成对近战选择不同包抄点、远程冷却期横移，以及重型敌人对可见移动目标的有限预测拦截。

敌人战斗升级：`godot --headless --path . --script res://tests/integration/enemy_combat_upgrade_check.gd`，覆盖摄像机尺寸视野、两档警戒共享、预蓄力、狙击手脚步调查和重型延迟自爆。

暂停设置：`godot --headless --path . --script res://tests/integration/settings_menu_check.gd`，覆盖 Esc 暂停、视频/音频控件，以及两项互不绑定的 AI 测试开关。

赛博终端 UI 样板：`godot --headless --path . --script res://tests/integration/cyber_ui_showcase_check.gd`，覆盖统一主题、切角面板、分段仪表、三条消息、设置工作区和三级 CRT 效果。

战斗提示与机动残影：`godot --headless --path . --script res://tests/integration/presentation_systems_check.gd`，覆盖暂停时提示寿命冻结但仍可入队、恢复后的过期，以及步行不出残影、套件能力残影池与按来源清理。

正式出生巡逻检查：`godot --headless --path . --script res://tests/integration/spawned_patrol_check.gd`，通过 Main 的真实生成器检查出生坐标、墙体平行轨迹，以及带偏移房间的世界坐标。

武器场景检查：`godot --headless --path . --script res://tests/integration/weapon_scene_check.gd`，覆盖初始挂载、快捷切换、单实例表现、枪口发射、墙面收回、纯表现状态隔离和缺失场景回退。实施与模板见 `docs/technical/武器场景实施说明.md`。

战斗音乐检查：`godot --headless --path . --script res://tests/integration/combat_music_check.gd`，覆盖强制敌人触发普通战斗轮播、BOSS 两阶段切换、BOSS 音乐不被普通清场信号打断，以及战斗结束停播。

战斗音效检查：`godot --headless --path . --script res://tests/integration/combat_audio_check.gd`，覆盖飞行套件移动循环，以及基础步行不会误用“增援接近”音效。

导电、配电箱与试玩场景：

```sh
godot --headless --path . --script res://tests/integration/status_reaction_check.gd
godot --headless --path . --script res://tests/integration/power_box_check.gd
godot --headless --path . --script res://tests/integration/electric_sandbox_check.gd
```

覆盖真实子弹状态传递、伤害与反应限制、墙体/阵营/范围/容器隔离、E 领取与攻击互斥、房间增益、倒计时与电弧暂停/回收，以及标靶清场。

浸油、燃烧与燃料桶：

```sh
godot --headless --path . --script res://tests/integration/oil_status_check.gd
godot --headless --path . --script res://tests/integration/fuel_environment_check.gd
godot --headless --path . --script res://tests/integration/fuel_sandbox_check.gd
```

覆盖实际计时伤害、刷新不叠加、暂停与保险清状态、桶破坏互斥、油区/爆炸/火区、墙体/范围/容器隔离、伤害接口引燃、试验场鼠标点击点燃、普通近战打桶、R 重置和区域过期。

仓库与试验场往返：`godot --headless --path . --script res://tests/integration/trial_entry_check.gd`，使用独立存档验证保存失败留在仓库、真实 E 进入、普通初始装备、配电箱与桶、R 重置、死亡后鼠标点击返回及存档隔离。

试验场储物箱：`godot --headless --path . --script res://tests/integration/trial_chest_check.gd`，覆盖正式原型清单、真实 E 和鼠标取用、自动补货与实例编号、容量/绑定/保险唯一、配装和存回、暂停恢复、R 重置与存档隔离；往返检查另验证取物后返回正式仓库。

环境结算完善与自动门：

```sh
godot --headless --path . --script res://tests/integration/environment_electric_check.gd
godot --headless --path . --script res://tests/integration/automatic_door_check.gd
```

覆盖同次放电共享预算/去重、新导电不自触发、实际区域玩家归属、每区域配电箱数量、增益回调互斥；实际接触开门、挡弹/放行、双侧冲刺、门后击倒范围与遮挡、暂停及恢复。fuel_environment_check/fuel_sandbox_check 已改为验证警棍和枪击直接引爆，原浸油反应另由 oil_status_check 保留验证。

启动与角色确认：`godot --headless --path . --script res://tests/integration/start_menu_check.gd`，26 项检查覆盖透明立绘、无存档、真实鼠标选择角色、取消无副作用、继续保留装备实例、重开前原文件备份、损坏存档恢复、写入失败回滚及实际进入仓库。使用独立测试存档；去掉 `--headless` 还会在 `/tmp/hotline-start-*.png` 保存界面截图。

机动品质与背包丢弃：`godot --headless --path . --script res://tests/integration/mobility_and_discard_check.gd`，30 项检查覆盖品质冲撞伤害/冷却、资源克隆、合成预览、真实右键菜单、同实例丢弃与拾回、存档失败回滚。`dual_area_check.gd` 现包含 40 项检查，进入第二房间后回路永久封闭，包括真实反向移动碰撞验证。
