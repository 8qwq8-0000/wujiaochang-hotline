# Tests

警戒炮台：`sentry_turret_check.gd` 验证八方向跟踪和双排射击、遮挡及清场摧毁；`sentry_placement_check.gd` 检查四张地图每区至少一台及占地、避障、寻路。运行方式为 `godot --headless --path . --script res://tests/integration/文件名`。

人格战斗状态栏：`godot --headless --path . --script res://tests/integration/persona_status_hud_check.gd`，覆盖人格等级、猎痕锁定、限时效果到期、反馈数值、威胁解析、死亡清理和通讯展开/收起避让。添加 `-- --capture-persona-status` 并去掉 `--headless` 可生成三种人格及通讯展开截图。

新增普通地图：`freight_atrium_check.gd` 检查货运中庭的十二扇门、中央近路及侧区寻路；`dual_track_depot_check.gd` 检查双轨货运站的三条换线口、两侧长射击线、真实横穿和 328 px 实际射击。均使用 `godot --headless --path . --script res://tests/integration/文件名` 运行。`room_layouts_check.gd` 检查正式四种地图的选择、双区域连接及首区/末区位置。

盾兵屏障：`godot --headless --path . --script res://tests/integration/enemy_barrier_skill_check.gd`，覆盖施放动画、展开时机、正面及高速挡弹、背后受伤、到期恢复、冷却、硬直与死亡清理、四方向判定和 AI 触发。

双战斗区域：`godot --headless --path . --script res://tests/integration/dual_area_check.gd`，覆盖真实通道碰撞、清场解锁、按进入激活第二区、全层目标累计、生命/热量/装备保留、各区增益失效、一次性补给和最终出口限制。

射击输入与方向：`godot --headless --path . --script res://tests/integration/shooting_input_check.gd`，覆盖 HUD 点击透传、上下左右子弹方向与实际物理帧移动，防止向上子弹碰到发射者自身而消失。

撤离结算：`godot --headless --path . --script res://tests/integration/extraction_check.gd`，覆盖真实出口选择、未清场/死亡拒绝、继续层状态保留、暂停恢复、装备与背包带出、重复结算、返回仓库及带装备再次出击。使用独立测试存档，不修改玩家存档。

仓库储物箱：`godot --headless --path . --script res://tests/integration/warehouse_check.gd`，覆盖项目仓库入口、真实 E 键与鼠标存取、暂停恢复、装备槽物品同步、满包/绑定拒绝、实例属性保留、保存失败回滚、全新实例读档、场景重建、出击与撤离返回，以及损坏存档保护。使用独立测试存档。

黑匣与死亡保护：`godot --headless --path . --script res://tests/integration/blackbox_check.gd`，覆盖独立格、保险核心实例与唯一性、背包入口、暂停换装、满包交换、伤害结算期间禁止切换、旧状态迁移、保存失败回滚、死亡重试、回仓、核心丢失、已触发核心保护及 R 放弃行动。使用独立测试存档。

背包拖放：旧 `inventory_drag_check.gd` 保留 v1.4 主副武器/机动回归记录，不再作为 v1.5 义体槽验收证据。现行义体装备、卸下、黑匣拒绝与生命周期由 `cyberware_check.gd` 覆盖。

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

Week 1 队友房间已作为正式“仓库出击”和“继续下一层”场景启用。专项检查：`godot --headless --path . --script res://tests/integration/week1_room_check.gd`，覆盖 F6 单独运行与 Main 容器加载、实际敌人数同步、真实 E 拾取、敌人掉落、清场换装、撤离出口和 R 重开；不应输出 SKIP。仓库与撤离检查另验证正式路径确实加载该场景。

背包全图暂停检查：`godot --headless --path . --script res://tests/integration/inventory_pause_check.gd`，覆盖敌人/子弹/热量/冷却停止，界面操作、Tab/Esc、死亡、暂停中重开和场景退出恢复。

双武器携带与切换：`godot --headless --path . --script res://tests/integration/weapon_switch_check.gd`，覆盖主/副目标槽、Q/滚轮、空槽跳过、冷却/热量保留、满包替换及战斗/暂停/死亡限制。

双空槽重新装备：`godot --headless --path . --script res://tests/integration/weapon_slot_refill_check.gd`，覆盖主副武器都卸下后，把两件武器分别拖到主、副槽，目标槽不会相互覆盖。

首次武器自动装副槽：`godot --headless --path . --script res://tests/integration/first_weapon_pickup_check.gd`，覆盖战斗中拾取、满包、副槽占用、仅首次触发、当前武器保留、立即使用和重复拾取保护。

装备不占格与开局配置：旧 `backpack_weapon_capacity_check.gd` 保留 v1.4 机动槽记录；v1.5 义体槽的独立装备与局内生命周期改由 `cyberware_check.gd` 覆盖。

Week 1 房间已接入当前玩法接口；`week1_room_check.gd` 的 SKIP 不计为通过。

房间切换：`godot --headless --path . --script res://tests/integration/room_transition_check.gd`，覆盖背包与装备快照、实例编号、首次拾取资格，以及旧房间掉落／子弹清理。

单元检查：`godot --headless --path . --script res://tests/run_unit_checks.gd`。

敌人警戒：`godot --headless --path . --script res://tests/integration/enemy_alert_check.gd`，覆盖视野角度/距离/墙体、声音半径/遮挡/暂停、受击、目标记忆、附近同伴传播与防止递归、场景隔离和真实枪击事件。实施与参数见 `docs/technical/敌人警戒实施说明.md`。

敌人巡逻：`godot --headless --path . --script res://tests/integration/enemy_patrol_check.gd`，覆盖出生点附近往返、端点停留、暂停、警戒中断与返回、墙体阻挡、关闭巡逻和死亡。

敌人导航压力检查：`godot --headless --path . --script res://tests/integration/enemy_navigation_check.gd`，在原型房间用 16 名敌人覆盖软避让、绕开墙体／掩体，以及不持续完全重叠。

敌人战术决策：`godot --headless --path . --script res://tests/integration/enemy_tactics_check.gd`，覆盖成对近战选择不同包抄点、远程冷却期横移，以及重型敌人对可见移动目标的有限预测拦截。

敌人战斗升级：`godot --headless --path . --script res://tests/integration/enemy_combat_upgrade_check.gd`，覆盖摄像机尺寸视野、两档警戒共享、预蓄力、狙击手脚步调查和重型延迟自爆。

暂停设置：`godot --headless --path . --script res://tests/integration/settings_menu_check.gd`，覆盖 Esc 暂停、视频/音频控件、HUD 缩放、降低闪烁、最近通讯页，以及两项互不绑定的 AI 测试开关。

赛博终端 UI 样板：`godot --headless --path . --script res://tests/integration/cyber_ui_showcase_check.gd`，覆盖统一主题、切角面板、分段仪表、三条消息、设置工作区和三级 CRT 效果。

战斗 HUD 与表现：`godot --headless --path . --script res://tests/integration/presentation_systems_check.gd`，覆盖左上最小状态区、AI 全息通讯、右上暂停、右下半透明武器、隐藏旧提示队列，以及关闭伤害数字。

战斗 AI 通讯：`godot --headless --path . --script res://tests/integration/combat_comms_check.gd`，覆盖首次展开接通音、关键消息中断、普通消息单条待播、同类合并、自动收缩、两行拆分和最近十条历史。

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
godot --headless --path . --script res://tests/integration/bomb_runtime_check.gd
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

覆盖同次放电共享预算/去重、新导电不自触发、实际区域玩家归属、每区域配电箱数量、增益回调互斥；实际接触开门、射击破门与后续放行、双侧冲刺、门后击倒范围与遮挡、暂停及恢复。自动门检查还覆盖破门子弹消耗、双向和横向门射击、碎片去重，以及无伤害/暂停射击不破门。fuel_environment_check/fuel_sandbox_check 已改为验证警棍和枪击直接引爆，原浸油反应另由 oil_status_check 保留验证。

启动与角色确认：`godot --headless --path . --script res://tests/integration/start_menu_check.gd`，26 项检查覆盖透明立绘、无存档、真实鼠标选择角色、取消无副作用、继续保留装备实例、重开前原文件备份、损坏存档恢复、写入失败回滚及实际进入仓库。使用独立测试存档；去掉 `--headless` 还会在 `/tmp/hotline-start-*.png` 保存界面截图。

固有突进：`godot --headless --path . --script res://tests/integration/dash_check.gd` 覆盖方向优先级、锁向、约 84 px 位移、命中去重、攻击打断、冷却、低物理频率路径扫描、撞墙与隔墙；`dash_invulnerability_check.gd` 覆盖 0.15 秒无敌及独立无敌来源。旧机动品质检查仅保留历史记录，不再作为现行验收。

义体系统：`godot --headless --path . --script res://tests/integration/cyberware_check.gd` 覆盖专用槽、黑匣拒绝、四模块复合上限、追踪/爆炸弹丸快照、直击叠加范围伤害、持续射击兼容边界、突进脱锁、击破散热的归属/限频/过热恢复、热阈震荡的范围/无伤/防换装刷新和行动生命周期。

房间构型：`godot --headless --path . --script res://tests/integration/room_layouts_check.gd`，128 项检查覆盖正式 B/C 构型池、同层去重、种子复现、楼层重抽、跨区导航，以及全部 8 种房型的出生点/道具/出口可达和实际敌人绕墙追踪。去掉 `--headless` 会在 `/tmp/hotline-room-*.png` 输出实际构型截图。

互通房间：`godot --headless --path . --script res://tests/integration/interlinked_rooms_check.gd`，48 项真实物理检查覆盖 B/C 六名敌人配置、全部 19 处门的实际穿越，以及观察窗挡人、通视与实际弹丸伤害。去掉 `--headless` 输出 `/tmp/hotline-bc-*.png` 实机截图。


楼顶大肥鱼 Boss：

```sh
godot --headless --path . --script res://tests/integration/rooftop_boss_check.gd
godot --headless --path . --script res://tests/integration/boss_patterns_check.gd
godot --headless --path . --script res://tests/integration/boss_shortcut_check.gd
```

分别覆盖一阶段三名守卫合计三血、独立计数且不扣 Boss 血、保留推镜头和神像苏醒；二阶段三名三血守卫与 Boss 同时攻击、Boss 无敌、逐点联动损血、清完恰好留下 3/6 血、真实子弹命中与击杀；原本落点和十字激光、交点一次伤害、暂停／死亡取消；实际重开输入、仓库独立测试存档及往返。战斗界面不显示 Boss 连续血条或阶段标签，神像光环分段与 AI 通讯承担状态反馈。

贴身射击：`godot --headless --path . --script res://tests/integration/point_blank_shooting_check.gd`，使用真实玩家武器握点、枪口与子弹回调，覆盖制式手枪、散射器、轨道炮表现模板的八方向贴身命中、自身忽略及近距离墙体阻挡。轨道炮仅作为武器模板构造测试，不代表已加入正式装备池。

激光炮正式掉落：`godot --headless --path . --script res://tests/integration/rail_cannon_loot_check.gd`，覆盖随机掉落、品质词条、实例序列化、实际拾取、副槽装备切换、炮身特效节点、射击伤害与热量；贴身命中检查使用正式激光炮资源。

长条范围激光：`godot --headless --path . --script res://tests/integration/laser_beam_check.gd`，覆盖 1000×48 范围内多目标同时受伤、每发仅结算一次、范围外及自身免伤、墙体阻挡、显示与伤害长度一致、无普通子弹及光束回收，以及光束引爆油桶、墙后和范围外油桶保护。

人格永久档案：`godot --headless --path . --script res://tests/integration/persona_archive_check.gd`，覆盖普通结算收录人格与三级语义泄漏、下一局人格清零、临时档案载荷剥离、完整胜利记录与重复结算拒绝。

完整通关与遗产酒谱：`godot --headless --path . --script res://tests/integration/victory_flow_check.gd`，覆盖第三层转入生产楼顶、胜利入口唯一铸造、回仓、酒谱显示和最后人格瓶型。仓库 BOSS 测试捷径仍由 `boss_shortcut_check.gd` 验证，不会生成遗产记录。
盾兵飞行屏障与远程配合：`godot --headless --path . --script res://tests/integration/shield_support_check.gd`，61 项覆盖四方向、独立移动、墙体、干净身体、初始冷却、提前一秒跑位及友伤。带窗口追加 `-- --capture` 输出四方向截图。

盾反训练营：`godot --headless --path . --script tests/integration/parry_training_check.gd`，覆盖仓库入口、三只前方扇形机器人、顺序单发、血量与间隔滑块、固定弹速、死亡跳过、真实弹道反射、连续两次 PERFECT! 与断连、真实 R 重置及参数保留、暂停和正式存档隔离。非 headless 追加 `-- --capture` 可生成训练营截图。

`bomb_runtime_check.gd` 验证元素反应关闭时，真实枪弹仍能引爆炸弹箱、生成动画和碎片，并产生爆炸及持续火区伤害；普通油区仍遵守元素反应开关。窗口验证可使用 `godot --path . --windowed --script res://tests/integration/bomb_runtime_check.gd -- --capture`。

Codex 通道整备：`godot --headless --path . --script res://tests/integration/codex_service_passage_check.gd`。23 项检查覆盖第二层继续后的独立通道、E 对话与中止恢复、解锁和重复整备、满包装备升级、义体复合、永久仓库存档隔离，以及第三层状态继承和正常人格整备。窗口模式追加 `-- --capture` 生成通道、对话、工坊、出口截图。

人格战斗台词：`godot --headless --path . --script res://tests/integration/persona_dialogue_check.gd`，覆盖 48 条 CSV 数据加载、12 类事件、关系阶段向下回退、冷却与优先级，以及切换人格时先退场后接入的发言顺序。

装备图标验收：`tools/preview_equipment_icons.gd` 展示八类物品；`tools/preview_equipment_runtime.gd` 使用实际背包和地面掉落显示。素材来源和完整生成提示词见 `assets/art/items/equipment_v1/README.md`、`art_sources/ai_drafts/equipment_icons_v1/manifest.json`。
