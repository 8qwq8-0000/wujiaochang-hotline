# 第三方依赖

版本在接入后固定，不自动跟随上游分支。

| 依赖 | 固定版本 | 许可证 | 用途 | 工程目录 |
|---|---:|---|---|---|
| Dialogic | 工程既有版本 | MIT | NPC 与人质对话 | `addons/dialogic` |
| TileMapDual | 工程既有版本 | 以插件内许可证为准 | TileMap 编辑辅助 | `addons/TileMapDual` |
| godot_ai | 工程既有版本 | 以插件内许可证为准 | 开发期编辑器辅助 | `addons/godot_ai` |
| Maaack's Menus Template | 1.7.1 | MIT | 主菜单、暂停、设置、输入重映射 | `addons/maaacks_menus_template` |
| Maaack's Scene Loader | 1.7.0（随菜单包） | MIT | 异步场景切换 | `addons/maaacks_scene_loader` |
| Clean Copy Examples | 随菜单包 | MIT | 菜单设置向导依赖 | `addons/clean_copy_examples` |
| Plugin Updater | 0.5.1（不启用自动更新） | MIT | 菜单设置向导依赖 | `addons/plugin_updater` |
| GLoot | 3.0.2 | MIT | 背包、容量、装备槽 | `addons/gloot` |
| Godot Sound Manager | 2.6.2 | MIT | 音乐、音效与播放器池 | `addons/sound_manager` |
| SaveMadeEasy | 1.3 | MIT | 基地、仓库和解锁进度存档 | `addons/save_system` |

## 集成约束

- 不启用 Maaack Music Controller 和 UI Sound Controller，统一使用 Sound Manager。
- 不导入单独下载的 Scene Loader 0.23.4，避免与菜单包版本覆盖。
- SaveMadeEasy 1.3 默认关闭加密；若以后启用，必须替换示例密钥。
- GLoot 的组件词条、合成和黑匣规则由项目适配层实现。
- 第三方许可证副本统一放在 `docs/legal/third_party/`。

## 仅作为设计/算法参考，未复制进工程

2026-10-13 的战斗基础框架调研还参考了以下 MIT 项目，但当前仓库没有复制其源码、场景或素材，因此它们不是运行时依赖：

- https://github.com/nezvers/Godot-GameTemplate
- https://github.com/cluttered-code/godot-health-hitbox-hurtbox
- https://github.com/Criscarr26/smart-top-down
- https://github.com/37Rb/godot-overhead-car-2d
- https://github.com/DumpsterFireLabs/SuperStarFighter
- https://github.com/Minoqi/minos-damage-numbers-for-godot

若以后复制任何代码，必须先锁定 commit、补录许可证副本，并把本节条目移动到上方正式依赖表。
