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
