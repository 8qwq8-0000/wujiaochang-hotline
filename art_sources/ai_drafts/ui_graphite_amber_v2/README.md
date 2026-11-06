# 石墨琥珀界面第二稿

状态：已接入战斗 HUD、义体编辑器和设置页。AI 通话界面未改动。

## 素材

- `durability_gem_filled_v2.png`：暖白琥珀晶体，方形轮廓，亮度集中在晶体内部。
- `durability_gem_empty_v2.png`：同一轮廓的暗态晶体。
- `heat_fin_hot_v2.png`、`heat_fin_cold_v2.png`：热量槽的亮态与暗态窄片。
- `shared_os_frame_v2.png`：透明中心的系统界面边框。
- `energy_bus_backbone_v1.png`、`cyberware_socket_bezel_v1.png`：可重复排布的义体导轨和槽位。
- `durability_base_v1.png`：耐久块背后的细机械线，不构成背景板。

## 设计规则

- 战斗界面耐久保留分格，每格用独立晶体表示。热量用十片窄片表示。
- 耐久与义体序列取消整块黑色半透明背景。义体槽位中心距为 46 像素，槽位宽 44 像素。
- 导轨素材可以按四、五、六槽重复伸展。当前游戏逻辑仍是四槽。
- 设置页采用透明边框、场景压暗、左侧导航与右侧选项，没有面板矩形底色。
- 义体拖动与补位动效已接入游戏，采用弹簧回弹和槽位碰撞。卸下义体后，其余模块会自动补位。

## 预览

预览文件在 `docs/art/validation/ui_graphite_amber_v1/`：

- `combat_v2_1280_720.png`、`combat_v2_1920_1080.png`
- `settings_v2_1280_720.png`、`settings_v2_1920_1080.png`
- `sequence_v2_4_5_6_1280_720.png`
- `cyberware_reflow_v2.gif`
- `runtime_combat_v2_1280_720.png`、`runtime_settings_v2_1280_720.png`、`runtime_circuit_editor_v2_1280_720.png`
- `runtime_circuit_reflow_v2_1280_720.png`：实际运行中的补位画面。

预览脚本在 `tools/ui_preview_project/preview_v2.gd` 和 `preview_motion.gd`。生成素材时参考了成熟游戏中能量晶体的材质表达，但形状、切面与配色均为本项目重新设计。
