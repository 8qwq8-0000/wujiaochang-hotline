# 发布回归入口

发布测试先运行自动检查，再进行人工整局和目标设备验收。快速集用于每次提交，候选集用于准备各平台发布包；两者的固定入口与历史排除原因见 [`release_manifest.json`](release_manifest.json)。候选集目前聚焦核心流程、两种结局、存档、回路与手机共用逻辑，**不是全部集成脚本已通过的证明**。新增或修复功能时，应将有意义的检查纳入对应档位。过时夹具不能静默计入通过数。

```sh
python tools/run_release_checks.py fast --godot <Godot-4.7.2-可执行文件>
python tools/run_release_checks.py candidate --godot <Godot-4.7.2-可执行文件>
```

也可通过 `GODOT_BIN` 指定引擎；`--list` 只列清单。每个入口单独运行，结果与完整日志写入被 Git 忽略的 `build/test-reports/`，JSON 报告含提交号、执行时间和失败项。持续检查在提交或合并请求时运行快速集；候选集可手动触发。退出时已有资源清理诊断不能替代退出码和断言结果，也不算已修复。

团队测试包中，F8 控制台保留按钮并支持 `help`、`jump`、`give`、`build`、`seed`、`clear`、`win`、`status`、`capture`、`report`、`replay`；输入 `help <指令>` 查看参数，上下键调用历史，Tab 补全指令。`seed` 作用于下一次跳关。`capture` 与 `report` 输出到隔离的 `user://test-reports/`，报告包含平台、引擎、当前状态和指令记录；在新测试会话输入 `replay <报告文件名.json>` 可重放其中成功执行的场景与构筑指令。手机测试包用触屏按钮打开；正式发布包不创建测试控制台。

自动检查全绿后，测试成员从新档自然游玩，覆盖教学、仓库、撤离、死亡、跨层、两种结局和重启读档。F8 只用于复现问题。未参与开发的同学独立试玩，记录卡住步骤和求助。每个平台用实际安装包在代表设备上核查画面、声音、触控或键鼠、稳定性和性能；问题修复后重跑受影响自动检查及人工路径。四个平台可分别通过、分别发布，不能以开发环境结果替代平台验收。

每次平台验收记录提交号、安装包、设备与系统、执行人、测试日期、完整游玩结果、首次试玩卡点、性能观察、缺陷编号和复验结果。候选集报告必须对应同一提交；正式包还需现场确认 F8 与手机测试入口不可用。核心流程、存档或性能缺陷未关闭的平台保持待发布，其他平台可以继续独立验收。自动化只能证明脚本覆盖的行为，真实手感与设备表现须由测试成员签收。

`release_build_gate_check.gd` 用于检查 `GameSettings` 是否按构建特性创建测试控制台。编辑器侧已运行通过；正式包的执行方式和结果要在后续实际构建时验证。本轮按约定不生成正式包。

手机操作文案：`mobile_control_prompts_check.gd` 检查电脑操作词转换、桌面原文保留、重复适配稳定性和手机点按/拖动射击说明。

手机背包布局：`mobile_inventory_panel_check.gd` 在窄横屏实际窗口中检查关闭按钮、安全区、完整底部丢弃区、装备区滑动、避免滑动误换装、原生长按拖弃及 Tab 兼容。

手机对话继续：`godot --headless --path . --script res://tests/integration/mobile_dialogue_check.gd` 使用原生触屏事件检查序章开场、教学通讯、Codex、到仓库提示和储物引导；覆盖松手、第二手指与触屏生成的模拟鼠标去重，避免一次轻触跳过多句。

iOS 适配：`godot --headless --path . --script res://tests/integration/ios_mobile_check.gd` 检查原生导出预设、左右横屏、Retina 安全区与 iPad 边距；`mobile_controls_check.gd` 继续覆盖共享触控行为。`python3 tools/build_ios.py --check` 检查本机环境，`--build device` / `--build simulator` 可编译未签名产物。安装和验证范围见 `docs/technical/iOS手机端适配实施说明.md`。

通关记录、结局档案与敌人图鉴：`godot --headless --path . --script res://tests/integration/warehouse_archive_check.gd`，覆盖旧档兼容、画面外及墙体遮挡不解锁、实际敌人/炮台/Boss 遭遇、跨实例保存、失败回滚、测试模式隔离、四页签、通关记录与结局进度分离和未解锁信息隐藏、Esc 关闭恢复。窗口模式添加 `-- --capture` 可输出通关记录、结局、人格与敌人页截图到 `/tmp/hotline-archive-*.png`。旧存档未记录历史遭遇，首次更新后需重新遇敌解锁。

# Tests

第二结局神像单挑与入场剧情：`godot --headless --path . --script res://tests/integration/channel_boss_duel_check.gd`。覆盖真实Enter推进、暂停、核心接入与诅咒解除、实际子弹命中、三招伤害及安全边界、突进穿波、死亡清理、楼顶重入和完整二结局结算，59项检查通过。窗口模式追加`-- --capture`保存正式房间截图；自动化夹具生命不代表正式平衡。F8面板新增“二结局Boss”直接试玩，仍采用内存存档隔离。

剧情序章：`godot --headless --fixed-fps 60 --path . --script res://tests/integration/prologue_check.gd`，使用独立存档检查开场无枪与纯对话、突进击杀、正式敌人 AI 与弹速对照及盾反实际击杀、手枪掉落、Tab 背包装备、取消强制热量练习、实战热量提醒不暂停且不重复、自然散热恢复、通信暂停玩家/敌人/子弹/热量、真实鼠标点击正文/场景/面板继续、正式 HUD 的生命/热量同步与右下角武器显示及最大缩放避让、入口增益先领后开战与自动开门、约 1.5 秒阶段缓冲与仓库传送缓冲、手枪波次和环境箱、三件战利品、Codex 对话解锁合成、小 Boss 区独立炸药箱/散热增益箱与真实使用、自动传送进入仓库、底部通信引向保险箱与死亡丢失/箱内保留说明、关闭通信后恢复操作，以及跳过与存档隔离。窗口模式追加 `-- --capture` 可输出序章截图。详见[实施说明](../docs/technical/剧情序章与基础教学实施说明.md)。

> 本页列出专项入口与历次覆盖说明，不代表所有脚本在当前版本均已通过。旧 `component_progression_check.gd` 仍访问机动 API；`cyberware_check.gd` 混有已废弃的独立义体槽、普通义体合成和即时射击断言，暂作历史夹具。`inventory_check.gd`、`issued_pistol_check.gd`、`synthesis_npc_check.gd` 和 `loot_synthesis_loop_check.gd` 覆盖当前战斗暂停换装、旧武器拾取迁移、装备升级与跨层回仓合成。当前回路与锻造师义体合成请使用 `circuit_attack_phase1_check.gd`、`cyberware_circuit_runtime_check.gd` 和 `codex_service_passage_check.gd`。历史断言数量保留原记录；Windows 与退出资源诊断等限制不因此取消。

警戒炮台：`sentry_turret_check.gd` 验证八方向跟踪和双排射击、遮挡及清场摧毁；`sentry_placement_check.gd` 检查四张地图每区至少一台及占地、避障、寻路。运行方式为 `godot --headless --path . --script res://tests/integration/文件名`。

人格战斗状态栏：`godot --headless --path . --script res://tests/integration/persona_status_hud_check.gd`，覆盖人格等级、猎痕锁定、限时效果到期、反馈数值、威胁解析、死亡清理和通讯展开/收起避让。添加 `-- --capture-persona-status` 并去掉 `--headless` 可生成三种人格及通讯展开截图。

新增普通地图：`freight_atrium_check.gd` 检查货运中庭的十二扇门、中央近路及侧区寻路；`dual_track_depot_check.gd` 检查双轨货运站的三条换线口、两侧长射击线、真实横穿和 328 px 实际射击。均使用 `godot --headless --path . --script res://tests/integration/文件名` 运行。`room_layouts_check.gd` 检查正式四种地图的选择、双区域连接及首区/末区位置。

盾兵屏障：`godot --headless --path . --script res://tests/integration/enemy_barrier_skill_check.gd`，覆盖施放动画、展开时机、正面及高速挡弹、背后受伤、到期恢复、冷却、硬直与死亡清理、四方向判定和 AI 触发。

双战斗区域：`godot --headless --path . --script res://tests/integration/dual_area_check.gd`，覆盖真实通道碰撞、清场解锁、按进入激活第二区、全层目标累计、生命/热量/装备保留、各区增益失效、一次性补给和最终出口限制。

射击输入与方向：`godot --headless --path . --script res://tests/integration/shooting_input_check.gd`，覆盖 HUD 点击透传、上下左右子弹方向与实际物理帧移动，防止向上子弹碰到发射者自身而消失。

撤离结算：`godot --headless --path . --script res://tests/integration/extraction_check.gd`，覆盖真实出口选择、未清场/死亡拒绝、继续层状态保留、暂停恢复、装备与背包带出、重复结算、返回仓库及带装备再次出击。使用独立测试存档，不修改玩家存档。

仓库储物箱：`godot --headless --path . --script res://tests/integration/warehouse_check.gd`，覆盖项目仓库入口、真实 E 键与鼠标存取、暂停恢复、装备槽物品同步、满包/绑定拒绝、实例属性保留、保存失败回滚、全新实例读档、场景重建、出击与撤离返回，以及损坏存档保护。使用独立测试存档。

黑匣与死亡保护：`godot --headless --path . --script res://tests/integration/blackbox_check.gd`，覆盖独立格、保险核心实例与唯一性、背包入口、暂停换装、满包交换、伤害结算期间禁止切换、旧状态迁移、保存失败回滚、死亡重试、回仓、核心丢失、已触发核心保护及 R 放弃行动。使用独立测试存档。

背包拖放：旧 `inventory_drag_check.gd` 保留 v1.4 主副武器/机动回归记录，不再作为当前义体回路验收证据。现行义体入库与回路配置由 `cyberware_circuit_runtime_check.gd` 和 `cyberware_circuit_ui_check.gd` 覆盖。

旧 `inventory_check.gd`、`weapon_switch_check.gd`、`first_weapon_pickup_check.gd` 仍按已取消的战斗换装限制和旧背包容量断言，已在候选清单中排除；当前换装与拾取应以现行单元检查、自然游玩和后续重写夹具验收。

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
godot --headless --path . --script res://tests/integration/enemy_loot_check.gd
```

Week 1 队友房间已作为正式“仓库出击”和“继续下一层”场景启用。专项检查：`godot --headless --path . --script res://tests/integration/week1_room_check.gd`，覆盖 F6 单独运行与 Main 容器加载、实际敌人数同步、真实 E 拾取、敌人掉落、清场换装、撤离出口和 R 重开；不应输出 SKIP。仓库与撤离检查另验证正式路径确实加载该场景。

背包全图暂停检查：`godot --headless --path . --script res://tests/integration/inventory_pause_check.gd`，覆盖敌人/子弹/热量/冷却停止，界面操作、Tab/Esc、死亡、暂停中重开和场景退出恢复。

双武器携带与切换：`godot --headless --path . --script res://tests/integration/weapon_switch_check.gd`，覆盖主/副目标槽、Q/滚轮、空槽跳过、冷却/热量保留、满包替换及战斗/暂停/死亡限制。

双空槽重新装备：`godot --headless --path . --script res://tests/integration/weapon_slot_refill_check.gd`，覆盖主副武器都卸下后，把两件武器分别拖到主、副槽，目标槽不会相互覆盖。

首次武器自动装副槽：`godot --headless --path . --script res://tests/integration/first_weapon_pickup_check.gd`，覆盖战斗中拾取、满包、副槽占用、仅首次触发、当前武器保留、立即使用和重复拾取保护。

装备不占格与开局配置：旧 `backpack_weapon_capacity_check.gd` 保留 v1.4 机动槽记录；当前义体直入回路库及开局安装由 `cyberware_circuit_runtime_check.gd` 覆盖。

Week 1 房间已接入当前玩法接口；`week1_room_check.gd` 的 SKIP 不计为通过。

房间切换：`godot --headless --path . --script res://tests/integration/room_transition_check.gd`，覆盖背包与装备快照、实例编号、首次拾取资格，以及旧房间掉落／子弹清理。

`enemy_drop_navigation_check.gd` 检查导航未同步时延迟放置掉落、重复回调不重复发奖、装备与义体间距、正常拾取，以及换层销毁时取消等待。

单元检查：`godot --headless --path . --script res://tests/run_unit_checks.gd`。可追加 `-- --suite=test_cyberware_circuit` 只加载义体回路专项，便于在其他未提交测试暂时不可解析时隔离验证；该参数不替代最终全量回归。

义体回路运行：`godot --headless --path . --script res://tests/integration/cyberware_circuit_runtime_check.gd`，覆盖真实 `F` 启动输入、主动/事件/定时请求与优先级、能量预付和连续回复、智能/爆炸修正消费、武器主动调用、防递归、镜像赛博格挡、击杀热沉、节律计时，以及待执行请求的运行状态往返。

义体回路编辑器与 HUD：`godot --headless --path . --script res://tests/integration/cyberware_circuit_ui_check.gd`，在 640×360 检查 `C` 暂停编辑、`E/F` 按键保留、独立库存、4 槽重排、实际顺序/净门槛预览、右下能量与三类队列、显式执行箭头，以及执行中编辑不改变当前轮快照。

义体构筑试验场：`godot --headless --path . --script res://tests/integration/cyberware_circuit_lab_check.gd`，覆盖测试模式入口、9 件义体各 4 份、默认主动武器链、无限靶、固定敌人、近战敌人和三类复位。`test_mode_check.gd` 另覆盖真实仓库往返、构筑保留及正式存档隔离。

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

战斗音效检查：`godot --headless --path . --script res://tests/integration/combat_audio_check.gd`，保留旧飞行套件音频资源映射回归，并确认现行基础步行不会误用“增援接近”音效；该资源映射不表示飞行套件仍在正式运行时启用。

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
```

覆盖实际计时伤害、刷新不叠加、暂停与保险清状态、桶破坏互斥、油区/爆炸/火区、墙体/范围/容器隔离、伤害接口引燃和区域过期。



环境结算完善与自动门：

```sh
godot --headless --path . --script res://tests/integration/environment_electric_check.gd
godot --headless --path . --script res://tests/integration/automatic_door_check.gd
```

覆盖同次放电共享预算/去重、新导电不自触发、实际区域玩家归属、每区域配电箱数量、增益回调互斥；实际接触开门、射击破门与后续放行、双侧冲刺、门后击倒范围与遮挡、暂停及恢复。自动门检查还覆盖破门子弹消耗、双向和横向门射击、碎片去重，以及无伤害/暂停射击不破门。fuel_environment_check 已改为验证警棍和枪击直接引爆，原浸油反应另由 oil_status_check 保留验证。

启动与角色确认：`godot --headless --path . --script res://tests/integration/start_menu_check.gd`，当前 42 项检查覆盖透明立绘、无存档、默认制式手枪、真实鼠标选择角色、取消无副作用、继续保留装备实例、重开前原文件备份、损坏存档恢复、写入失败回滚及实际进入仓库。使用独立测试存档；去掉 `--headless` 还会在临时目录保存界面截图。

固有突进：`godot --headless --path . --script res://tests/integration/dash_check.gd` 覆盖方向优先级、锁向、约 84 px 位移、命中去重、攻击打断、冷却、低物理频率路径扫描、撞墙与隔墙；`dash_invulnerability_check.gd` 覆盖 0.15 秒无敌及独立无敌来源。旧机动品质检查仅保留历史记录，不再作为现行验收。

义体系统：`godot --headless --path . --script res://tests/integration/circuit_attack_phase1_check.gd` 覆盖开火进入回路、回路结束后攻击、同轮加成、事件启动器合成与存档、命中事件、回放及 32 次攻击上限。`circuit_energy_phase2_check.gd` 覆盖 40 能量每秒回复、启动器单独付费、逐槽扣能、中止、动量跳转、轴突折扣和旧 ID 读档迁移。`cyberware_circuit_runtime_check.gd` 覆盖回路构造与运行，`cyberware_circuit_ui_check.gd` 覆盖编辑界面。旧 `cyberware_check.gd` 仍保留其他义体行为的历史检查，混有与新版规则冲突的失败断言，不能作为当前验收入口。`power_box_check.gd` 另覆盖每台终端随机发放一件义体、重复进入不复制奖励和战斗回路编辑入口。

房间构型：`godot --headless --path . --script res://tests/integration/room_layouts_check.gd`，128 项检查覆盖正式 B/C 构型池、同层去重、种子复现、楼层重抽、跨区导航，以及全部 8 种房型的出生点/道具/出口可达和实际敌人绕墙追踪。去掉 `--headless` 会在 `/tmp/hotline-room-*.png` 输出实际构型截图。

互通房间：`godot --headless --path . --script res://tests/integration/interlinked_rooms_check.gd`，48 项真实物理检查覆盖 B/C 六名敌人配置、全部 19 处门的实际穿越，以及观察窗挡人、通视与实际弹丸伤害。去掉 `--headless` 输出 `/tmp/hotline-bc-*.png` 实机截图。


楼顶大肥鱼 Boss：

```sh
godot --headless --path . --script res://tests/integration/rooftop_boss_check.gd
godot --headless --path . --script res://tests/integration/boss_patterns_check.gd
godot --headless --path . --script res://tests/integration/wing_guards_check.gd
```

分别覆盖一阶段左／右翼卫 20／15 点生命、苏醒转场、二阶段合翼卫 35 点与鲸神逐 7 点联动、最后直接击败鲸神；六档落雷、透视地板格、暂停冻结、透明落雷贴图生命周期，以及四段随从攻击动画每段 8 帧的资源加载和运行播放。贴墙掉落与拾取另见 `death_drop_check.gd`。

贴身射击：`godot --headless --path . --script res://tests/integration/point_blank_shooting_check.gd`，使用真实玩家武器握点、枪口与子弹回调，覆盖制式手枪、散射器、轨道炮表现模板的八方向贴身命中、自身忽略及近距离墙体阻挡。轨道炮仅作为武器模板构造测试，不代表已加入正式装备池。

激光炮正式掉落：`godot --headless --path . --script res://tests/integration/rail_cannon_loot_check.gd`，覆盖随机掉落、品质词条、实例序列化、实际拾取、副槽装备切换、炮身特效节点、射击伤害与热量；贴身命中检查使用正式激光炮资源。

长条范围激光：`godot --headless --path . --script res://tests/integration/laser_beam_check.gd`，覆盖 1000×48 范围内多目标同时受伤、每发仅结算一次、范围外及自身免伤、墙体阻挡、显示与伤害长度一致、无普通子弹及光束回收，以及光束引爆油桶、墙后和范围外油桶保护；激光正面、边缘与近距离破门，破门解除碰撞，墙后及光束范围外的门保持关闭。

人格永久档案：`godot --headless --path . --script res://tests/integration/persona_archive_check.gd`，覆盖普通结算收录人格与三级语义泄漏、下一局人格清零、临时档案载荷剥离、完整胜利记录与重复结算拒绝。

完整通关与遗产酒谱：`godot --headless --path . --script res://tests/integration/victory_flow_check.gd`，覆盖第三层转入生产楼顶、胜利入口唯一铸造、回仓、酒谱显示和最后人格瓶型。
盾兵飞行屏障与远程配合：`godot --headless --path . --script res://tests/integration/shield_support_check.gd`，61 项覆盖四方向、独立移动、墙体、干净身体、初始冷却、提前一秒跑位及友伤。带窗口追加 `-- --capture` 输出四方向截图。

`bomb_runtime_check.gd` 验证元素反应关闭时，真实枪弹仍能引爆炸弹箱、生成动画和碎片，并产生爆炸及持续火区伤害；普通油区仍遵守元素反应开关。窗口验证可使用 `godot --path . --windowed --script res://tests/integration/bomb_runtime_check.gd -- --capture`。

逐层难度：`godot --headless --path . --script res://tests/integration/floor_difficulty_check.gd`。普通战斗第 1/2/3 层每区生成 6/7/8 只小怪，每只最大生命在原型基础上增加 0/1/2；覆盖四种地图、三个固定种子、新增出生点可达性、共享原型隔离和清场计数。

墙边窄道追击：`godot --headless --fixed-fps 60 --path . --script res://tests/integration/enemy_corner_passage_check.gd`。复现错位公寓随机箱子和左墙间的 36 px 窄道，检查短路可达、近战/盾兵实际攻击玩家及前排死亡后后排通过。导航烘焙采用 12 px 留边，匹配敌人 11 px 碰撞半径并保留 1 px 裕量。

仓库道具碰撞与遮挡：`godot --headless --path . --script res://tests/integration/warehouse_collision_check.gd`，覆盖储物箱、货架、工作台、合成师、档案终端、杂物箱和两处入口的实体底座、落地排序点、双向通道及交互可达性。非 headless 追加 `-- --capture` 可检查各道具前后站位截图。
Codex 通道整备：`godot --headless --path . --script res://tests/integration/codex_service_passage_check.gd`。23 项检查覆盖第二层继续后的独立通道、E 对话与中止恢复、解锁和重复整备、满包装备升级、义体复合、永久仓库存档隔离，以及第三层状态继承和正常人格整备。窗口模式追加 `-- --capture` 生成通道、对话、工坊、出口截图。

人格战斗台词：`godot --headless --path . --script res://tests/integration/persona_dialogue_check.gd`，覆盖 48 条 CSV 数据加载、12 类事件、关系阶段向下回退、冷却与优先级，以及切换人格时先退场后接入的发言顺序。

装备图标验收：`tools/preview_equipment_icons.gd` 展示八类物品；`tools/preview_equipment_runtime.gd` 使用实际背包和地面掉落显示。素材来源和完整生成提示词见 `assets/art/items/equipment_v1/README.md`、`art_sources/ai_drafts/equipment_icons_v1/manifest.json`。

Codex 通道安全寄存与小血瓶：`godot --headless --path . --script res://tests/integration/codex_supplies_check.gd`，33 项覆盖真实 E 打开寄存箱、只列出武器、已装备/背包武器永久寄存、既有安全配装去重、保存失败回滚与热量保留、防重复寄存、死亡后重新读档及回仓取出；桌上血瓶满血不消耗、恢复 1 格、使用后消失、同次行动重载不刷新与新行动补充。非 headless 追加 `-- --capture` 保存 `/tmp/codex-supplies-*.png`。

F8 快捷测试模式：`godot --headless --path . --script tests/integration/test_mode_check.gd`，覆盖默认关闭、设置不含测试入口、F8 开合面板不离开当前关卡、Esc 收起面板、普通/携带核心通道跳转、领取品质／容量／保险唯一限制、三人格全部天赋分支、非法天赋无部分修改、测试仓库与三层跳转、未激活区域清场、Boss 开场与护盾阶段快速通关、结算／新建档案隔离、主菜单直达 Boss、死亡后跳关恢复、退出后正式档案及存档字节完全一致，以及正常保存恢复。测试文件使用 `.godot/test-mode-check.json`，结束后删除。

第二结局“频道归还”：`godot --headless --path . --script res://tests/integration/channel_route_check.gd` 检查首轮通关解锁、第一层接入选择、撤离禁止、第二/三层无旧任务的正常通行与 Codex 补给、Boss 联动和三节点接管、结局保存及测试模式隔离；`godot --headless --path . --script res://tests/integration/channel_recovery_check.gd` 检查安全节点存档、正式主菜单恢复、死亡与放弃、楼顶/Codex 恢复及旧任务房存档迁回普通楼层。窗口运行前者并追加 `-- --channel-visual` 可输出 `/tmp/channel-route-preview/` 截图。详见[第二结局实施说明](../docs/technical/第二结局频道归还实施说明.md)。

二结局自动解锁提示：`godot --headless --path . --script res://tests/integration/channel_intro_check.gd`，覆盖首次回仓自动弹出、旧通关记录兼容、说明文字、暂停与恢复、确认保存失败重试、跨实例持久化、一次性提示、测试隔离及已完成二结局时不显示过时提醒。窗口运行追加 `-- --capture` 输出 `/tmp/hotline-channel-intro.png`。

二结局底部通信统一：`godot --headless --path . --script res://tests/integration/channel_dialogue_check.gd`，检查紧凑底部布局、长文分页、Enter/鼠标继续、最终页才显示选择、安全选项默认焦点、背景点击不误接入、任务回调时机、结局 Esc 跳过和暂停恢复。窗口运行追加 `-- --capture` 保存 `/tmp/channel-unified-choice.png` 与 `/tmp/channel-unified-feedback.png`。

隐藏区域与核心背包：`godot --headless --path . --script res://tests/integration/channel_hidden_shrine_check.gd`。当前覆盖 68 项：三次命中开门、受击动画与镜头不跳、独立区域淡入/淡出和往返、独立上方背景、两盾兵三狙击手与导航、左右拾取选择、满包拒绝、核心固定第一格和不可丢弃/移动/入黑匣、保存失败回滚与跨层恢复。窗口模式追加 `-- --capture` 生成 `/tmp/hidden-shrine-*.png`。

隐藏区域最新专项为 72 项：另覆盖右下方上楼门的清场解锁、未拾取核心仍可上楼、从新门前往第二层，以及减少掩体后的可达性。

暗门破裂动画后专项更新为 74 项，验证动画收尾和破口持久显示；窗口截图模式额外输出 `/tmp/hidden-shrine-break-frame-*.png`。

龙娘四方向动画资源：`godot --headless --path . --script res://tests/integration/dragon_animation_check.gd`，24 项检查覆盖四方向切换、实际帧推进、停步朝向及脚底原点。窗口运行追加 `-- --preview` 持续预览，追加 `-- --capture` 输出 `/tmp/hotline-dragon-animation.png`。资源说明见 `docs/art/validation/dragon_gpt_v1/README.md`；尚未接入正式同行流程。

Codex 招募、单区域突袭与结局分流：`godot --headless --path . --script res://tests/integration/codex_escort_check.gd`，覆盖原对话、招募及回滚、三格生命与 1.2 秒保护、真实敌方子弹与友方穿透、只锁玩家、第三层单区域、龙娘到位后等待玩家靠近才暂停对话、右侧接受、延后准备、实际交互探测器重开、确认前不刷怪、确认后固定三波、长时间等待不超时、第三波结束不刷新第四波、隔墙持续追击、计时与清场双条件、死亡取消后续波次、保存恢复及两种楼顶分支。窗口运行追加 `-- --capture`，设备对话及战斗截图输出到 `/tmp/codex-escort-03-ready.png` 与 `/tmp/codex-escort-04-ambush.png`。

2026-11-04 主分支整合：98 个单元测试及 35 个专项入口通过；F8 121 项包含八种高级义体实际领取/图标/模块验证，频道通信 18 项包含原生触屏及模拟鼠标去重。完整结果和实际窗口检查见[整合记录](../docs/technical/本地变更与PR准备说明_2026-11-04.md)。


## 2026-11-11 退出资源清理验收

`python3 tools/check_shutdown.py` 在独立进程中验证菜单退出、战斗窗口关闭通知、暂停背包时关闭、加载期间关闭和 SceneLoader 后台加载后关闭；`--windowed` 同时检查真实图形渲染与音频驱动。窗口关闭通过派发与系统相同的通知验证，未使用系统鼠标点窗口关闭按钮。每次保留 `--verbose` 日志，任何 WARNING、ERROR、SCRIPT ERROR、ObjectDB 泄漏、残留资源或 RID 诊断都判为失败。

本次结果：115 个单元测试、48 个现行集成脚本均通过，退出无警告或报错；无窗口和窗口模式的 5 类退出各通过一次（10/10）。集成夹具统一调用正式 `GameSettings.quit_game()`，保留失败退出码，让音频服务在 SceneTree 销毁前完成回收。历史夹具不因本记录而变为当前版本验收入口。详细修复和限制见 `docs/technical/退出资源清理回归记录.md`。


## 2026-11-11 Boss 反馈与主分支整合复查

两种 Boss 战新增命中、护盾节段碎裂、蓄力/释放、觉醒/转阶段/死亡反馈，保留原有伤害、判定、招式顺序与释放时间。音效采用项目现有素材分层与调音；六个固定声部中保留两个关键声部，普通连击不会抢占破盾/转阶段声。镜头反馈继续遵守用户设置。

`godot --headless --path . --script res://tests/integration/boss_presentation_check.gd` 的 22 项检查覆盖真实命中和实际技能释放、连击合并、声音/图形预算、暂停冻结、瞬态到期与死亡回收。窗口模式加 `-- --capture` 会输出 `/tmp/hotline-boss-feedback-*.png`；截图夹具冻结展示帧，截图不用于代替实时玩法测试。

整合最新主分支后的本机结果：119 个单元测试通过，现行 63 个集成脚本通过，完整退出日志未出现运行/资源诊断；新增 Boss 检查包含在 63 个脚本中。退出探针扩展到两种 Boss 声画播放中关闭，无窗口和窗口各 7 项，14/14 干净退出。后续微调展示帧后另复跑两场 Boss 与反馈检查、单元测试。修复 Dialogic 编辑器两个 UndoRedo 对象的销毁；编辑器复查无 ObjectDB 或资源残留报告，但 verbose 日志仍有一个 Node StringName 残留，来源尚未定位，未计作游戏运行退出已通过的证据。

发布清单恢复了本轮修好的背包/合成/换枪用例，加入掉落寻路、完整战利品合成链、Boss 反馈和退出检查；发布运行器同时判定错误与退出资源诊断，CI 增加七种独立进程退出探针。本机结果不代表 Windows CI 或移动设备实机结果。
