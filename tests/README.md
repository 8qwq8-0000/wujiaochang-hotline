# Tests

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
