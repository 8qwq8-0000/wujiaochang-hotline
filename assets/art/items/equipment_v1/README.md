# 防御装备与义体图标 v1

2026-10-23，使用内置 imagegen 分别生成八件透明工业科幻像素物品。统一左上受光、深灰金属外壳、功能色和可读轮廓，不使用文字、外框或背景。生成源图与每件完整提示词保存在 `art_sources/ai_drafts/equipment_icons_v1/manifest.json` 及同目录 PNG；未使用 CLI/API fallback。

| 文件 | 对应物品 | 轮廓与识别点 |
|---|---|---|
| armor.png | 缓冲装甲 | 肩甲、分层护板、青色缓冲核心与蓝液罐 |
| smart_fire.png | 智能火控 | 单目青色瞄准镜、接头 |
| explosive_magazine.png | 爆裂弹仓 | 三枚红橙弹筒、黑色弹匣 |
| tactical_coprocessor.png | 战术协处理器 | 方形针脚芯片、绿色核心 |
| optical_intruder.png | 光学入侵器 | 紫色棱镜、弧形光学器件 |
| kill_heat_sink.png | 击破散热器 | 铜底座、青色竖直散热鳍片 |
| heat_threshold_pulser.png | 热阈震荡器 | 橙色核心、环形震荡结构 |
| compound_cyberware.png | 复合义体 | 一体式底座、四个异色集成模块 |

无后缀文件是正式运行用的 32×32 透明 PNG，另保留 `_64.png` 展示版本。通过 `godot --headless --path . --script res://tools/import_equipment_icons.gd` 从完整源图裁去透明边距，以最近邻缩放并居中打包，不覆盖源图。PNG 无损导入、关闭 Mipmap；背包、拖动预览、仓库、合成台和掉落统一使用同一物品纹理。

`resources/items/components.json` 替换原来共用的 wheel.svg / armor.svg。义体合成设置独立复合图标，旧复合物品在 ensure 时更新；地面拾取按实例的 image 属性显示，支持复合图标，而非只按基础原型查图。旧 SVG 留作历史资源。

验收截图：`docs/art/validation/equipment_icons_v1/catalog.png`、`ground.png`、`inventory.png`。复现工具为 `tools/preview_equipment_icons.gd` 与 `tools/preview_equipment_runtime.gd`，均使用 Godot 实际渲染。

装甲蓝血 38 项、防御组件 40 项、仓库存取 61 项、Codex 通道 23 项和六种义体效果检查通过。既有 `component_progression_check.gd:149` 仍引用旧 mobility 接口，脚本解析失败，未记为通过；本次未修改该旧测试。部分运行退出仍有既有 ObjectDB / resources-in-use 诊断。

维护：本任务维护者，团队负责人待认领。来源为本项目内置 imagegen 生成输出，未在本次引入外部第三方素材；不作独立第三方授权声明。
