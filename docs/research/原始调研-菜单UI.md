# Godot 4 菜单 / UI 开源方案调研（搜打撤 roguelite · 中文 UI · Windows 桌面）

> 调研方式：web_search + web_fetch，直接抓取 GitHub REST API、Godot Asset Library API、仓库 README / 文件树 / release notes / ATTRIBUTION / 翻译 CSV 原文。
> 时间基线：Godot 4.7 为当前 stable（2026-06 发布，官方仍 full support；4.8 预计 2026 Q4，尚在 master）。
> 凡未能验证者一律标注「未验证」，不臆造 star / 许可 / URL。

---

## 0. 三条最重要的结论（先看这个）

1. **中文渲染：所有候选库都不带 CJK 字体，必须自备。**
   - Godot 默认项目字体是 **Open Sans SemiBold**，无中文字形（官方文档 *Using Fonts*）。
   - 官方文档同时说明：*"The engine automatically uses system fonts as fallback fonts, which makes it possible to display CJK characters and emoji without having to load a custom font."* —— 也就是说 Windows 上中文**大概率能显示**（靠系统兜底），但字形/字重随机器变化，且 SystemFont 不进 PCK，无法保证一致。
   - gohud 的 README 直接把坑写明了：*"Bring a font for your languages… Thai, Arabic, Hebrew, Hindi and CJK need glyph coverage from your own theme font; a Latin-only font draws them as empty boxes and raises no error."*（拉丁字体渲染中文 = 空白框，且**不报错**，极难 debug。）
   - **建议**：把 **Noto Sans SC**（google/fonts `ofl/notosanssc`，SIL OFL 1.1，已抓到 OFL.txt 原文；版权声明为 Adobe + Reserved Font Name 'Source'，即思源黑体衍生）或 **Source Han Sans SC**（adobe-fonts/source-han-sans，README 明写 SIL OFL 1.1）设为项目默认字体：`Project Settings > GUI > Theme > Default Font` + 主题的 Default Font；再在字体导入的 *Advanced… > Fallbacks* 挂第二套。选 **SubsetOTF/CN** 或 `NotoSansSC-VF`（可变字重）体积更小。
   - **导出必查**：字体必须进 PCK（不要只依赖系统兜底），否则换一台机器就是满屏方块。

2. **Maaack 系模板是最稳的骨架，但中文/字体/翻译都要自己补。**
   - 三个仓库的 README 都写着 *For Godot 4.7 (4.4+ compatible)*，**v1.6.0 起最低 Godot 4.4**（v1.6.0 release notes：*"This release breaks compatibility with Godot 4.3."*）。
   - 实测全仓库文件树**没有任何 `.ttf/.otf/.woff`**（用 jsdelivr 全量文件列表 grep 验证）；`ATTRIBUTION.md` 只列 logo（Godot logo CC BY 4.0、Git logo GPL-2.0、Godot engine MIT、VS Code MIT）；自带翻译表 `menus_translations.csv` **只有 `en` 和 `fr` 两列，没有中文**。

3. **设置是否真落盘，已逐项验证：**
   - Maaack Options Menus → 写 **`user://player_config.cfg`**（文档原文：*"Validate the values being stored in your local player_config.cfg file"*，示例 `[InputSettings] MouseSensitivity=1.05`）。
   - godot-forge Settings Menu Lite → `GameSettings.save_settings()` 写 **`user://settings.cfg`**。
   - gohud / 多数主题包 → **不提供设置持久化**。

---

## 1. 候选总表

| # | 名称（仓库） | 类别 | 许可 | Godot | 活跃度（实测） | 交付形态 | 覆盖本项目屏幕 | 中文/字体 | 主要坑 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | [Maaack/Godot-Menus-Template](https://github.com/Maaack/Godot-Menus-Template) | 整包菜单 | **MIT** | 4.7（4.4+） | 485★，v1.7.1 (2026-09-10) | 模板 **或** 插件 | 1、2、3、7 | 需自加字体；翻译表仅 en/fr | AssetLib 版本滞后；示例主题是英文排版 |
| 2 | [Maaack/Godot-Game-Template](https://github.com/Maaack/Godot-Game-Template) | 整包菜单+示例游戏 | **MIT** | 4.7（4.4+） | 1690★，v1.7.0 (2026-09) | 模板 或 插件 | 1、2、3、6(胜负)、7 | 同上 | 自带存档系统官方标注"不安全/易变" |
| 3 | [Maaack/Godot-Minimal-Game-Template](https://github.com/Maaack/Godot-Minimal-Game-Template) | 轻量整包 | **MIT** | 4.7（4.4+） | 43★，pushed 2026-09-09 | 模板 | 1、2、3、7 | 同上 | 功能最少 |
| 4 | [Maaack/Godot-Options-Menus](https://github.com/Maaack/Godot-Options-Menus) | 设置+按键重绑定 | **MIT** | 4.7（4.4+） | 34★，v1.6.0 (2026-08-31) | 插件 | **3**（+2 的选项窗） | 同上 | AssetLib 显示 1.4.7（滞后） |
| 5 | [Maaack/Godot-Input-Remapping](https://github.com/Maaack/Godot-Input-Remapping) | 仅输入重映射 | **MIT** | 4.3+/4.x | 18★，last commit 2026-09 | 插件 | 3（重绑定部分） | 同上 | AssetLib 元数据 4.3 |
| 6 | [godot-forge/settings-menu-lite-godot](https://github.com/godot-forge/settings-menu-lite-godot) | 设置（真落盘） | **MIT** | 4.4 | 0★，2026-06-22 | 插件 + autoload | 3（部分） | 无中文，需自加 | 免费版**无按键重绑定、无分总线、无 Tab**（PRO 付费） |
| 7 | [TheoLomeuBraga/lazy_menu_2](https://github.com/TheoLomeuBraga/lazy_menu_2) | 设置/重绑定生成器 | **MIT** | 4.4 | 6★，pushed 2025-09-18 | 插件（Builder） | 3 | 有 localization 支持 | 生成式，改样式要重生成；文档薄 |
| 8 | [Keolai/godot-pause-menu](https://github.com/Keolai/godot-pause-menu) | 暂停菜单 | ⚠ **GPLv3**（AssetLib 标注）/ 仓库 license=null | 4.5 | 3★，pushed 2025-11-01 | 整项目 | 2 | — | **许可矛盾 + copyleft，不建议用** |
| 9 | [peter-kish/gloot](https://github.com/peter-kish/gloot) | 背包/格子数据层 | **MIT** | 4.4+，3.0.2 已适配 **4.7** | 982★，v3.0.2 (2026-07-05) | 插件（addons/） | **5** | 无字体需求，文案仍需 CJK 字体 | 自带 UI 只是"测试用基础控件"，皮肤要自己做 |
| 10 | [don-tnowe/godot-wyvernbox-inventory](https://github.com/don-tnowe/godot-wyvernbox-inventory) | 背包/装备/合成/商店 | **MIT** | Godot 3 **和** 4 | 163★，pushed 2026-01-27 | 插件（拖拽预制场景） | **5**（最开箱） | 示例字体是第三方 Abaddon（CC BY 3.0，仅 example） | 皮肤改造成本高；4.7 兼容未验证 |
| 11 | [godot-forge/grid-inventory-lite-godot](https://github.com/godot-forge/grid-inventory-lite-godot) | 极简格子背包 | **MIT** | 4.4 | **0★**，单次提交 2026-06-21 | 插件 | 5（仅显示/拖拽） | 无 | 无堆叠/无存档/无 tooltip（PRO 付费） |
| 12 | [expressobits/inventory-system](https://github.com/expressobits/inventory-system) | 全功能背包 | **MIT** | 4.4 | 738★，pushed 2026-02-20 | main=C++ 插件，addon=编译版 | 5 | 无 | 需 GDExtension 构建链，学生易踩雷 |
| 13 | [don-tnowe/godot-extra-controls](https://github.com/don-tnowe/godot-extra-controls) | 拖放/GUI 零件 | **MIT** | 4.x | 192★，pushed 2026-01-27 | 插件 | 5（辅助） | 无 | 只是零件，不是成品背包 |
| 14 | [thruthesky/gohud](https://github.com/thruthesky/gohud) | HUD+主题+控件全套 | **MIT**（图标 Tabler MIT；字体 OFL 1.1） | **4.7+**（<4.5 直接解析失败） | **2★**（shields 实测），last commit ≈2026-10 上旬，Asset Store v1.3.0 (2026-10-06) | 插件 `addons/gohud/` | 2、4、5(UI)、6、7、8 | 自带 21 语言含 **zh / zh_TW**（41 条字符串）；**不带 CJK 字体** | 极新、星数少；移动优先；无设置持久化 |
| 15 | [wadlo/Themey](https://github.com/wadlo/Themey) | 皮肤包 | 图形 **CC0**（src/material 为 Apache-2.0）+ 代码 **MIT** | 4.x | 40★，pushed 2025-02-09 | 每个主题 1 个 `.tres` + 图片 | 全局外观 | 无字体 | 只有 2 套（Clashy / Spacey）；更新停 2025-02 |
| 16 | [Inspiaaa/ThemeGen](https://github.com/Inspiaaa/ThemeGen) | 主题生成（代码） | **MIT** | 4.x | 264★，pushed 2026-05-02 | 插件 | 全局外观 | 需自己指定 CJK 字体 | 需要写 GDScript 描述设计系统 |
| 17 | [kuma-gee/godot-css-theme](https://github.com/kuma-gee/godot-css-theme) | CSS→Theme | **MIT** | 4.1+ | 151★，pushed 2026-07-21 | 插件 | 全局外观 | 需自己指定 CJK 字体 | CSS 子集，需懂映射 |
| 18 | [Kenney UI Pack](https://kenney.nl/assets/ui-pack) | 占位美术 | **CC0** | 通用 | 430 文件，2.0 重制 | PNG/矢量素材 | 全局外观 | 不含字体 | 要自己做 StyleBoxTexture 九宫格 |
| 19 | [hi-godot/cyberpunk-hud-demo](https://github.com/hi-godot/cyberpunk-hud-demo) | HUD 参考实现 | ⚠ **无 LICENSE（默认保留所有权利）** | 4.4 | 18★，pushed 2026-04-26 | 整项目 demo | 4（可借鉴） | 无 | **不可直接复制代码**，只能学做法 |
| 20 | [passivestar/godot-minimal-theme](https://github.com/passivestar/godot-minimal-theme) | ⚠ 编辑器皮肤 | MIT | 编辑器 | 3771★ | 编辑器主题 | **不适用游戏 UI** | — | 容易误认，不能用于游戏内 UI |
| 21 | [vishu/godot_health_bar_2d](https://github.com/vi4hu/godot_health_bar_2d) | ⚠ 血条 | MIT | **Godot 3.5** | AssetLib 1611，2023 | Godot 3 插件 | **不适用 4.x** | — | `TextureProgress` 已改名 `TextureProgressBar` |
| 22 | [razziefox/metal-hud-gd](https://github.com/razziefox/metal-hud-gd) | ⚠ 性能 HUD | MIT | 4.3+ | 1★，2024-08 | 插件 | **不适用**（Apple Metal 帧率 HUD） | — | 名字误导 |

**Asset Library / Asset Store 链接**
- Maaack Menus Template：AssetLib 模板 [3790](https://godotengine.org/asset-library/asset/3790)、插件 [2899](https://godotengine.org/asset-library/asset/2899)；Asset Store [template](https://store.godotengine.org/asset/maaack/maaacks-menus-template/)、[addon](https://store.godotengine.org/asset/maaack/maaacks-menus-template-addon/)
- Maaack Game Template：AssetLib [2703](https://godotengine.org/asset-library/asset/2703) / [2709](https://godotengine.org/asset-library/asset/2709)
- Maaack Minimal Game Template：AssetLib [4657](https://godotengine.org/asset-library/asset/4657)
- Maaack Options Menus：AssetLib [3058](https://godotengine.org/asset-library/asset/3058)、Asset Store [link](https://store.godotengine.org/asset/maaack/maaacks-options-menus/)
- Maaack Input Remapping：AssetLib [4051](https://godotengine.org/asset-library/asset/4051)
- GLoot：AssetLib [1368](https://godotengine.org/asset-library/asset/1368)（列表 v3.0.1 / godot 4.4，**滞后于 GitHub v3.0.2**）
- Wyvernbox：AssetLib [1919](https://godotengine.org/asset-library/asset/1919)
- Grid Inventory Lite：AssetLib [5285](https://godotengine.org/asset-library/asset/5285)
- Settings Menu Lite（godot-forge）：AssetLib [5290](https://godotengine.org/asset-library/asset/5290)
- Lazy Menu 2：AssetLib [4310](https://godotengine.org/asset-library/asset/4310)
- Pause Menu（Keolai）：AssetLib [4446](https://godotengine.org/asset-library/asset/4446)（GPLv3）
- ThemeGen：AssetLib [3299](https://godotengine.org/asset-library/asset/3299)
- Godot CSS Theme：AssetLib [1038](https://godotengine.org/asset-library/asset/1038)
- Basic Settings Menu：AssetLib [3701](https://godotengine.org/asset-library/asset/3701)
- gohud：Godot Asset Store [asset/withcenter/gohud](https://store.godotengine.org/asset/withcenter/gohud/)
- Simple Main Menu（sinnate）：AssetLib [1985](https://godotengine.org/asset-library/asset/1985)

---

## 2. 逐项细节（交付物 = 实测文件/类名）

### 2.1 Maaack/Godot-Menus-Template（整包骨架，**首选**）
- URL：<https://github.com/Maaack/Godot-Menus-Template> ｜ 许可：MIT（仓库根 `LICENSE.txt`，GitHub API `license.spdx_id = MIT`）
- 兼容：README 首行 *For Godot 4.7 (4.4+ compatible)*；v1.6.0 起最低 4.4
- 活跃度：485★ / 10 fork / 0 open issues；最新 release **v1.7.1（2026-09-10）**，`pushed_at 2026-09-10`；作者 Maaack 同时维护 6 个子插件（suite 仍活跃）
- **给了什么（仓库文件树实测）**
  - `addons/maaacks_menus_template/base/nodes/menus/main_menu/main_menu.tscn` + `main_menu.gd`
  - `base/nodes/menus/options_menu/audio/audio_options_menu.tscn`、`.../video/video_options_menu.tscn`、`.../input/{input_options_menu.tscn, input_actions_list.gd, input_actions_tree.gd, key_assignment_window.tscn, input_icon_mapper.gd}`
  - `base/nodes/menus/options_menu/option_control/{option_control, slider_option_control, toggle_option_control, list_option_control, vector_2_list_option_control}.tscn` + `paginated_tab_container.gd`
  - `base/nodes/opening/opening.tscn`（开场淡入 → 再加载主菜单）
  - `base/nodes/utilities/{pause_menu_controller.gd, capture_focus.gd, input_helper.gd, file_lister.gd}`
  - `base/nodes/windows/{window_panel, popup_window_panel, popup_window_scene_container, confirmation_popup_window_panel}.tscn`
  - `base/nodes/labels/credits_label.gd`（**自动读 `ATTRIBUTION.md` 生成滚动 credits**）、`plugin_version_label.gd`、`config_name_label.gd`
  - `base/nodes/input_hint/input_hint.tscn`（键位提示）
  - `base/translations/menus_translations.csv`（**仅 en / fr**，实测内容）
  - `resources/themes/{expedition, gravity, grow, lab, lore, steal_this_theme}.tres`（6 套示例主题）
  - 示例层 `scenes/`：`menus/main_menu/main_menu_with_animations.tscn`、`windows/{pause_menu.tscn, pause_menu_options_window.tscn, main_menu_credits_window.tscn, main_menu_options_window.tscn}`、`credits/{scrolling_credits, end_credits}.tscn`、`menus/options_menu/{master_options_menu_with_tabs.tscn, mini_options_menu.tscn, audio/…, video/…, input/…}`
  - 附带独立插件：`addons/{maaacks_scene_loader, maaacks_music_controller, maaacks_ui_sound_controller, plugin_updater, clean_copy_examples}`
- **安装方式（两种）**
  1. 新项目：Project Manager → Asset Store → 搜 "Maaack's Menus Template" → Download → Install & Edit；
  2. 现有项目：Asset Store 装 **Addon** 版 → 装到 `addons/` → 重启项目 → Project Settings > Plugins 启用 → 首次启用弹 **Setup Wizard**，或 `Project > Tools > Run Maaack's Menus Template Setup...` → 向导会把示例场景从 `addons/` 拷到项目根（可编辑）。
- **不做什么**：HUD、背包、奖励提示、业务存档、中文、CJK 字体。
- **对本项目的覆盖**：屏 1（主菜单 + credits 全有）、屏 2（暂停菜单框架 + 选项窗）、屏 3（设置骨架 + 音频/视频/输入页）、屏 7（`scene_loader` + loading screen，含 shader 预热示例）；屏 6 只能用 `confirmation_popup_window_panel` 改。
- **坑**
  - `pause_menu.tscn` 是 `PopupWindowPanel` 且 `pauses_game = true`，会记录并恢复焦点——如果你自己又做一个暂停层会双暂停；
  - 示例主题按英文排版，中文按钮宽度/字号要重调（建议 `Label` 开 `autowrap_mode`）；
  - 16:9 下默认满屏可用（文档称覆盖 4K → 640×360），但中文长句要复测；
  - credits 从 `ATTRIBUTION.md` 生成 → 中文 credits 需直接改这个文件。

### 2.2 Maaack/Godot-Game-Template（要示例游戏/胜负流程时选它）
- <https://github.com/Maaack/Godot-Game-Template> ｜ MIT ｜ 1690★ / 107 fork / 14 open issues ｜ v1.7.0（2026-09-09/10）
- 内容 = 2.1 的全部 + 示例游戏场景 + `LevelLoader` / `LevelManager` / `level_and_state_manager.gd` + 文档 `GameSaving.md`
- **存档实测**：`GlobalState`（静态类）持资源文件并 `GlobalState.save()`；`GameState`（单次流程：当前关、最高关、关卡状态）、`LevelState`（单关状态）；存到玩家本地 user 目录。官方警告原文：*"The save system relies on resource files, which are vulnerable to having malicious scripts injected into them… Do not use this for cloud saving."*，并标注 *"subject to change"*。
- 覆盖：屏 1/2/3/7 + **屏 6 的 win/lose/level-select 示范**（`screenshot-6-level-won/lost/level-select`）
- 坑：**不要把它的资源式存档当业务存档**，搜打撤的物品数据建议自己写 JSON/`ConfigFile`；其余同 2.1。

### 2.3 Maaack/Godot-Options-Menus（**设置 + 按键重绑定 + 真落盘**）
- <https://github.com/Maaack/Godot-Options-Menus> ｜ MIT ｜ 34★ ｜ v1.6.0（2026-08-31），pushed 2026-09-03 ｜ 1 open issue
- **给了什么**：`base/nodes/config/app_settings.gd`（7.3KB）、`player_config.gd`、`start_up/start_up.tscn`（启动时读回配置）；`options_menu/{audio, video, input}` 三套页面；`option_control/*` 五种控件模板；`input_actions_list.gd`(14.7KB) 与 `input_actions_tree.gd`(9.6KB) 负责按键列表/树；`key_assignment_window.tscn` 弹出"按键中…"窗口
- **持久化（已验证）**：写 **`user://player_config.cfg`**；运行时读：`PlayerConfig.get_config(AppSettings.INPUT_SECTION, "MouseSensitivity", 1.0)`；文档给了文件样例 `[InputSettings] MouseSensitivity=1.05`
- **按键重绑定**：内建，含"已占用"冲突提示（翻译键 `Already Assigned` / `{key} already assigned to {action}.`）、`Add/Remove/Reset`、焦点式键盘操作
- **不做什么**：不改 HUD；音频只有 Master / Music / SFX 三条总线；无中文
- **安装**：Asset Store / AssetLib → `addons/maaacks_options_menus`（+ 可选 `plugin_updater`）→ 启用 → `Project > Tools > Run Maaack's Options Menus Setup...`
- 覆盖：**屏 3 基本全包**（音量、分辨率/窗口模式、按键重绑定）；可作为屏 2 的"选项"子窗
- 坑：AssetLib 仍显示 1.4.7（滞后）；4.3 及以下不支持；中文文案要自己加列。

### 2.4 Maaack/Godot-Input-Remapping（只要重绑定）
- <https://github.com/Maaack/Godot-Input-Remapping> ｜ MIT ｜ 18★ ｜ AssetLib 4051 v1.4.2，重定向 2026-09；AssetLib 元数据停 4.3
- "Plugin for input remapping and persistent settings" —— 单独摘出来可以避免整包 Options Menus。

### 2.5 godot-forge/settings-menu-lite-godot（最小可用设置页，真落盘）
- <https://github.com/godot-forge/settings-menu-lite-godot> ｜ MIT ｜ **0★** ｜ AssetLib 5290（godot 4.4，2026-06-22）｜ 单次提交
- 产出：`addons/settings_menu/settings_menu.tscn` + **`GameSettings` autoload**；API `GameSettings.set_master_volume(0.5)` / `set_fullscreen(true)` / **`save_settings()` → `user://settings.cfg`**，下次启动自动加载并应用；面板有 `closed` 信号
- 免费版覆盖：**主音量、全屏、VSync、窗口分辨率**
- 免费版**缺**：Music/SFX 分总线、**按键重绑定**、Tab 式（Video/Audio/Controls）UI、本地化标签 —— 全在付费 PRO
- 结论：对"屏 3"三个需求只满足音频+视窗；**按键重绑定必须另配**（Maaack Input Remapping 或自己接 InputMap）。

### 2.6 TheoLomeuBraga/lazy_menu_2
- <https://github.com/TheoLomeuBraga/lazy_menu_2> ｜ MIT ｜ 6★ ｜ pushed 2025-09-18 ｜ AssetLib 4310 v1.0.1（godot 4.4）
- 用法：新建 `LazySettingsBuilder` / `LazyRebindBuilder` / `LazyConsoleBuilder` 节点 → 配置 → 在 2D 编辑器点 Build 生成菜单 → 自己写脚本接行为；README 支持 localization；并提醒设 `application/config/custom_user_dir_name`
- 坑：生成式（改视觉要重生成）、星少、未验证 4.7；是否落盘 未验证。

### 2.7 暂停菜单（结论：不要用现成 GPL 那个）
- ⚠ **Keolai/godot-pause-menu**：AssetLib 4446 标 **GPLv3**（`"cost":"GPLv3"`），但 GitHub API 返回 `license: null`（仓库未识别到 LICENSE 文件）—— **许可自相矛盾 + copyleft**，3★，godot 4.5，整项目模板。**不建议**。
- ✅ 替代：直接用 Maaack 的 `pause_menu.tscn`（MIT，`PopupWindowPanel` + `pauses_game` + 焦点恢复 + `PauseMenuController` 绑 `ui_cancel`），只需再往里面加一个「行动手册」Tab。

### 2.8 peter-kish/gloot（背包**数据层**首选）
- <https://github.com/peter-kish/gloot> ｜ MIT ｜ **982★** / 46 fork ｜ 最新 release **v3.0.2（2026-07-05）**，notes 第一条即 *"Update to Godot 4.7"*
- README 声明 *"version 4.4 and newer"*；v3.0 不兼容 v2.x（旧版在 `v2.x` 分支）
- **类与方法（README 实测）**：`InventoryItem`（物品堆）、`Prototree`（JSON 资源定义原型，支持 `inherits` 继承）、`Inventory`、约束 `GridConstraint`（二维格子，物品属性 `size: Vector2i` / `rotated` / `positive_rotation`）、`WeightConstraint`、`ItemCountConstraint`、`ItemSlot`（单槽，适合"黑匣子"）、UI 控件 `CtrlInventory`（ItemList）、`CtrlInventoryCapacity`（进度条）、`CtrlInventoryGrid`（2D 格子）、`CtrlItemSlot`；**所有类都有 `serialize()` / `deserialize()`** → 可直接进你们的存档
- **安装**：AssetLib 搜 "GLoot"，导入时**只勾 `addons` 目录**；或 clone 后把 `addons/gloot` 拷入项目；Project Settings > Plugins 启用
- **对本项目的覆盖**：屏 5 —— 24 格仓库 = `Inventory + GridConstraint(24)`；6 格背包 = 第二个 Inventory；1 个黑匣子 = `ItemSlot`；物品词条/属性用 Prototree（`damage`、`weight`、自定义字段）
- **不做什么**：三个 Tab 的界面结构（仓库/装配/合成 要自己搭 `TabContainer`）、合成/配方系统、tooltip 外观、拖拽手势的动画与音效、本地化
- 坑：README 自述 UI 控件是 *"some basic UI elements ready for earlier development phases and testing"* → **美术/皮肤要自己包**；格子尺寸、16:9 布局、拖拽高亮要自己调。

### 2.9 don-tnowe/godot-wyvernbox-inventory（最"开箱"的背包，皮肤改造大）
- <https://github.com/don-tnowe/godot-wyvernbox-inventory> ｜ MIT ｜ 163★ ｜ pushed 2026-01-27 ｜ AssetLib 1919 v1.3.14（godot 4.0）
- 描述为 *"Action RPG-focused inventory system for Godot 3 and 4"*（4.x 可用）
- **给了什么**：`addons/wyvernbox_prefabs` 里可直接拖进场景的 `InventoryView` / `InventoryTooltip` / `GrabbedItemStackView`（鼠标拖拽）+ `ItemType` 资源；Inventory 类型：Basic / **Grid（物品占矩形格）** / Restricted（只能放带特定 flag 的物品，如装备/弹药）/ Currency；内建 `InventoryVendor`（商店）、`ItemConversion`（**合成/配方**，支持随机产物与 ItemGenerator）、`ItemPattern`（过滤/匹配，如不同燃料效率）、`ShopManager`；手势：Shift 单击快转、双击同类收集、右键拆一/拆半；自定义 Inspector 表 + Item Browser 弹窗
- **对本项目的覆盖**：屏 5 最完整（格子 + 装备位 + **合成** + tooltip）
- 坑：它给的是"能看的成品皮肤"，换成你们风格的工作量 > gloot；示例内字体是第三方 **Abaddon（CC BY 3.0，仅 example 内，需替换）**；4.7 兼容 未验证。

### 2.10 godot-forge/grid-inventory-lite-godot（只当速成方案）
- MIT ｜ **0★** ｜ 建库与提交都只有 2026-06-21 一次 ｜ AssetLib 5285 v1.0.0（godot 4.4）
- `addons/grid_inventory`：`Inventory.new(20)`（槽位数）、`InvItem`（name/color）、`InventoryUI` 控件（`set_inventory()`）、`inventory_changed` 信号、拖拽移动/交换；带 demo
- 免费版**没有**：堆叠与自动合并、数量显示、tooltip、`count_of/has_item`、**一键存读档**（全在付费 PRO）
- 结论：能撑起"24 格 + 6 格 + 1 格"的显示与拖拽，但堆叠/存档/提示要自己写，**不建议当主力**。

### 2.11 expressobits/inventory-system（功能多但工程复杂）
- MIT ｜ 738★ ｜ pushed 2026-02-20 ｜ AssetLib 1650（godot 4.4）｜ 517MB 仓库
- 分支：`main` = **C++ 插件**（需 cmake/ninja 构建）、`addon` = AssetLib 用的编译版、`csharp` = C# 移植
- 功能：Item Stack、UI 逻辑分离、Hotbar、**Craft**、Loot、Categories、装备栏、RE4 风格格子、item editor、多人；**其 grid 部分基于 gloot**
- 资源来自 kenney.nl（CC0）
- 坑：GDExtension 构建链对 3 人 7 周项目是额外风险；**若要它，请走 gloot 路线**。

### 2.12 thruthesky/gohud（HUD+主题+控件的"一站式"新库，值得评估）
- 仓库 <https://github.com/thruthesky/gohud>；Asset Store：<https://store.godotengine.org/asset/withcenter/gohud/>；文档 <https://thruthesky.github.io/gohud/>
- 许可：**MIT**（代码 + 生成美术 + 84 默认图标 + 187 游戏图标 + 1000 图标库；其中 1,171 图标路径数据来自 **Tabler Icons, MIT**）；Cinzel / Roboto 字体 **SIL OFL 1.1**（`THIRD_PARTY_NOTICES.md`）
- 版本/兼容：Asset Store v1.3.0（2026-10-06/07），**最低 Godot 4.7**，最高 4.7.x；README：*"Requires Godot 4.7 or newer… engines before 4.5 fail while parsing"*；纯 GDScript，无 GDExtension，无必需 autoload
- 活跃度：**shields.io 实测 2★**；last commit ≈"last thursday"（2026-10 上旬）→ 极新，长期维护未知；Asset Store 页面标注 *"This Item Uses AI"*（作者声明：架构与核心实现为人写，测试与 SVG 图标由 AI 生成）
- **给了什么（86 个类，按需取用）**
  - HUD：`GoHudAnchor`（9 个方位 + 横竖屏切换）、**`GoBar`（HP/MP/XP，`GoBar.segments` 分段条 ← 直接对应 3 段耐久 & HEAT 条）**、`GoSlot`（图标+数量+冷却+快捷键提示）、`GoSlotGrid`（背包格子）、`GoRadar`、`GoDonut`、`GoRewardCalendar`
  - 反馈/提示：**`GoNotice` / `GoSnackbar` / `GoBanner` / `GoPromptCard`**（← 屏 8 的"高效清剿奖励/完美清剿奖励/精准反制奖励"浮层，`GoSnackbar` 明确"never swallow input"）、`GoCoachMark`（聚光灯教学）
  - 弹窗/窗口：`GoDialogs`（`await` 式 `alert/confirm/prompt/choice` ← 屏 6"撤离 vs 继续"、结算确认，`destructive=true` 画危险按钮）、`GoSurface`、`GoSheet`、`GoDrawer`、`GoPopover`、`GoContextMenu`（Esc/Android Back 只关最上层）
  - 结构/导航：**`GoTabView`**（← 仓库/装配/合成 三 Tab）、`GoScaffold`、`GoAppBar`、`GoNavBar`、`GoTopBar`/`GoBottomBar`/`GoLeftSideBar`/`GoSideBar`、`GoGrid`、`GoChoiceColumn`
  - 表单：`GoForm`、`GoField`、`GoInputGroup`、`GoCombobox`、`GoSearchBar`、`GoRangeSlider`、`GoChoiceColumn`、**`GoKbd`（键帽直接从 InputMap 读真实绑定 → 改键后提示自动更新 ← 行动手册页神器）**
  - 进度/加载：`GoProgress`、`GoSpinner`、`GoLoadingIndicator`、`GoBadge`；列表：`GoListView`（只建可见行）、`GoRefresh`、`GoReorderList`、`GoZoomView`、`GoSwipeRow`
  - 主题：**14 套预设**（default / scifi / medieval / material / arcade / comic / kids × dark·light），一行 `GoUi.use_preset(GoThemePresets.SCIFI_DARK)` 同时换主题+皮肤+图标；主题用 JSON 数据驱动（`tools/new_theme.py` 生成，含 WCAG 对比度自检）；单一 `GoConfig` 资源配置全部（含 `container_alpha`、圆角、间距、断点）
  - i18n：自带 **41 条 UI 字符串的 21 种语言翻译，含简体中文 `zh` 与繁体 `zh_TW`**，自动加载；可用 `GoUi.config.text_overrides = {&"confirm": "确定"}` 或 `text_keys` 覆盖
- **不做什么（关键）**
  - **没有"音量/分辨率/按键重绑定"的现成设置页**：有拼装件（`GoForm`/`GoRangeSlider`/`GoChoiceColumn`），但重绑定要自己接 `InputMap`，**持久化也没有** → 屏 3 仍建议用 Maaack Options Menus 或 settings-menu-lite 的 `GameSettings`（`user://settings.cfg`）
  - **不带 CJK 字体**：只带 Cinzel + Roboto，README 明确警告 CJK 需自带字体（拉丁字体只会画空框且不报错）
  - 移动优先（48dp、safe area、虚拟键盘），桌面 16:9 需自己复测（其测试规模含 1280×800）
  - 无音频（`GoFeedback.sound_handler` 由你接自己的音频系统）
  - 未提供"暂停游戏/Esc 处理"的成品暂停菜单（`GoSurface` 只保证关最上层窗口）
- 覆盖屏幕（界面外壳层面）：**2（暂停窗 + 行动手册可用 GoTabView+GoKbd）、4（GoBar.segments / GoSlot / GoNotice / GoHudAnchor）、5 的 UI 部分（GoSlotGrid + GoTabView）、6（GoDialogs.choose/confirm + GoBar）、7（GoLoadingIndicator/GoProgress）、8（GoNotice/GoSnackbar/GoPromptCard）**

### 2.13 皮肤/主题
- **wadlo/Themey**（40★，pushed 2025-02-09）：许可分层 —— 图形 **CC0**（`src/material` 内为 Apache-2.0）、代码与其它文件 **MIT**；产出：每个主题目录 = 1 个 `.tres` + 全部图片；已知 **Clashy（3D 风格矢量 UI）** 与 **Spacey（现代简洁+轻科幻）**；README 要求把 `themes/` 放项目根（如 `res://themes/clashy`）。坑：只有两套、更新停在 2025-02、`.tres` 里的字体槽要换成 CJK 字体。
- **Inspiaaa/ThemeGen**（264★ MIT，pushed 2026-05-02，AssetLib 3299 v1.4.0）：*"Programmatically create themes using GDScript"*，语义色 + 尺寸 → 整套 Theme（按钮/StyleBox/图标色），适合做自己的设计系统；不提供字体资源。
- **kuma-gee/godot-css-theme**（151★ MIT，pushed 2026-07-21，AssetLib 1038 v4.0）：CSS → Godot Theme，团队里会 CSS 的人可以直接出皮。
- **Kenney UI Pack**（CC0，430 文件，页面已确认 *"License: Creative Commons CC0"*）：占位美术 + 九宫格面板/按钮贴图首选；另见 UI Pack - Sci-Fi、Fantasy UI Borders。需自己做 `StyleBoxTexture` 边距。
- ⚠ **passivestar/godot-minimal-theme（3,771★ MIT）是 Godot 编辑器皮肤，不是游戏内 UI 主题**，对本项目不可用。
- 另外 Maaack 模板自带 `resources/themes/{expedition,gravity,grow,lab,lore,steal_this_theme}.tres` 与 Options Menus 的"主题选择器"截图，可当第二套皮肤来源。

### 2.14 HUD 参考（不能直接用）
- **hi-godot/cyberpunk-hud-demo**（18★，Godot 4.4，pushed 2026-04-26）：⚠ **GitHub API `license: null`，仓库无 LICENSE → 默认保留所有权利，不可复制代码**。做法值得学：三个渐进版本 `hud_v1/v2/v3.tscn` + `cyberpunk_hud.gd`（`CanvasLayer`），**全部用矢量 `_draw()` 程序化绘制**雷达扫描、圆形冷却表、准星、波形、扫描线 CRT、低血脉冲；`HudLoader` 切版本。→ 团队可以照这个思路"零美术资产"做 HUD。
- ⚠ **vishu/godot_health_bar_2d（AssetLib 1611）**：MIT，但 AssetLib `godot_version = 3.5`（Godot 3.x 插件，extends `TextureProgress`）→ **4.x 不能直接用**。
- ⚠ **razziefox/metal-hud-gd**：Apple Metal 性能 HUD（帧率/GPU），与游戏 HUD 无关。

### 2.15 没找到的：toast / 通知类
- Asset Library API `filter=notification` → 0 条；`filter=toast` → 0 条。
- 结论：**屏 8 的奖励浮字没有现成 addon**。可选项：自己写一个 autoload（`CanvasLayer` + `VBoxContainer` + `Tween` + 队列去重，约 80 行），或用 gohud 的 `GoNotice`/`GoSnackbar`/`GoPromptCard`。

---

## 3. 8 个界面 × 覆盖矩阵

| 设计文档界面 | 现成覆盖 | 仍需手搓 |
|---|---|---|
| ① 主菜单/标题 + credits | Maaack Menus Template（`main_menu.tscn`、`main_menu_with_animations.tscn`、`credits_label.gd` 读 ATTRIBUTION.md、`end_credits.tscn`） | 中文文案、标题美术、把本调研的第三方许可写进 ATTRIBUTION |
| ② 暂停菜单（Esc）+ 行动手册 Tab | Maaack `pause_menu.tscn` + `PauseMenuController`；Tab 与键帽用 gohud `GoTabView`/`GoKbd` 或 `input_hint.tscn` | **行动手册整页插画/图文排版**（`TextureRect` + `ScrollContainer`）、暂停时输入屏蔽与焦点 |
| ③ 设置：音量 / 分辨率窗口模式 / 按键重绑定 | **Maaack Options Menus（三项全包 + `user://player_config.cfg` 落盘）**；轻量替代 = settings-menu-lite（`user://settings.cfg`，但无重绑定） | 中文标签、把设置接进你们自己的设置存储（或共享同一 cfg） |
| ④ HUD：3 段耐久 / HEAT + 过热锁定 / PERFECT / 撤离提示 | 控件层：gohud `GoBar.segments`、`GoSlot`、`GoNotice`、`GoHudAnchor`（或手写 `ProgressBar`） | **全部游戏逻辑**：分段耐久规则、HEAT 累积/散热/锁定态（禁用开火+变色+音效）、PERFECT 判定与弹窗动画、撤离提示的输入与焦点 |
| ⑤ 仓库/装配/合成 三 Tab 格子 UI（24/6/1） | 数据层 **gloot**（`Inventory`+`GridConstraint`+`ItemSlot`+`serialize`）或 **Wyvernbox**（更开箱，含合成/装备/商店）；Tab 用 `TabContainer` 或 gohud `GoTabView`；格子控件 `CtrlInventoryGrid` / `InventoryView` / `GoSlotGrid` | **装配/合成的业务逻辑**（配方、词条、属性对比、拖拽规则与提示）、槽位美术、tooltip 皮肤、24/6/1 的布局与 16:9 适配 |
| ⑥ 楼层结算 + 撤离 vs 继续 + 结算结果（成功/死亡掉落） | Maaack 的 win/lose 示例 + `confirmation_popup_window_panel.tscn`；gohud `GoDialogs.choose/confirm` | **结算数据展示**（战利品列表、损失物品、奖励条目）、"撤离/继续"的流程与确认、失败掉落的规则文案 |
| ⑦ Loading / 场景切换 | Maaack `maaacks_scene_loader` + `loading_screen.tscn`（含 shader 预热示例）；gohud `GoLoadingIndicator`/`GoProgress` | 中文提示语、你们自己的进度语义（生成关卡/预热） |
| ⑧ 奖励浮字（高效清剿/完美清剿/精准反制） | gohud `GoNotice`/`GoSnackbar`/`GoPromptCard`（仅当采纳 gohud） | **触发规则 + 排队/合并/去重 + 动画 + 中文文案**（无现成 addon，需自写 ≈80~150 行 autoload） |

---

## 4. 最终推荐：两套可落地的 UI 栈

### 方案 A（推荐 · 稳）：Maaack 骨架 + gloot 数据层 + ThemeGen/思源字体
| 层 | 选型 | 一句话理由 |
|---|---|---|
| 菜单骨架 | **Maaack/Godot-Menus-Template**（MIT，485★，明示 4.7） | 主菜单/暂停/credits/loading/scene loader 一次到位，MIT 干净，向导式安装 15 分钟起步 |
| 设置 | **Maaack/Godot-Options-Menus**（MIT，34★，同作者同版本线） | 唯一同时满足"音量 + 分辨率/窗口模式 + 按键重绑定 + 真落盘 `user://player_config.cfg`"的免费方案 |
| 背包 | **peter-kish/gloot 3.0.2**（MIT，982★，已适配 4.7） | 数据层与 UI 分离、`GridConstraint` 正好是 24/6 格、`ItemSlot` 正好是黑匣子、`serialize()` 直接进存档 |
| 主题 | **Inspiaaa/ThemeGen**（MIT，264★）+ Maaack 自带 6 套 `.tres` 起步 | 用语义色统一整套控件样式，后续换配色只改一处 |
| 字体 | **Noto Sans SC / Source Han Sans SC**（SIL OFL 1.1，已验证） | 设为项目默认字体 + fallback，中文才稳定；导出务必包含 |
| 占位美术 | **Kenney UI Pack**（CC0） | 零许可风险，两天内出可玩界面 |
| HUD / 浮字 | 手写（参考 cyberpunk-hud-demo 的 `_draw()` 思路，**不复制其代码**） | 无许可风险的现成 HUD 套件；分段条/提示自写可控 |

### 方案 B（更统一 · 更激进）：gohud 当 UI 底座
- 底座：**gohud**（MIT，Godot 4.7+）—— 14 套预设 + `GoBar.segments`（耐久/HEAT）+ `GoNotice`（奖励浮字）+ `GoTabView`（三 Tab）+ `GoDialogs`（撤离/结算）+ `GoSlotGrid`（格子）+ `GoLoadingIndicator`（loading）+ `GoKbd`（行动手册键位）+ 自带中文翻译。
- 但设置持久化/重绑定仍要外挂 **Maaack Options Menus** 或 **settings-menu-lite**，字体仍要自备。
- 代价：**2★、2026-10 才 v1.3.0、移动优先、Asset Store 标注使用 AI**，长期维护与桌面布局需自己承担风险。→ 若团队只有 7 周且无人愿意当"UI 库维护者"，选 A。

### 必须从零手搓（两套方案都躲不掉）
1. 屏 2 的「行动手册」图文页；
2. 屏 4 的全部 HUD 逻辑（3 段耐久、HEAT/过热锁定、PERFECT popup、撤离提示输入）；
3. 屏 5 的装配/合成业务逻辑 + 槽位美术；
4. 屏 6 的结算数据与"撤离 vs 继续"流程；
5. 屏 8 的奖励触发规则与浮字队列；
6. **全部中文文案 + CJK 字体接入 + 导出回归**。

### 7 周排期建议
- **W1**：装 Maaack Menus + Options → 跑向导 → 接入 Noto Sans SC → 菜单/设置界面全部改中文 → 验证 `user://player_config.cfg` 真写入（Project > Open User Data Folder）。
- **W2**：三 Tab 骨架（`TabContainer`）+ gloot 数据模型（24/6/1 槽）+ 占位图标；暂停菜单 + 行动手册页。
- **W3**：HUD（3 段耐久、HEAT + 过热锁定、PERFECT、撤离提示）。
- **W4**：楼层结算 / 胜负屏 + 奖励浮字（autoload）。
- **W5**：loading/场景切换 + 存档（gloot `serialize()` → 你们自己的存档格式）。
- **W6**：换皮（ThemeGen + Kenney）、16:9 与 1280×720 / 1920×1080 回归。
- **W7**：Windows 导出 + **字体中文回归**（换机器测，绝不允许满屏方块）。

---

## 5. 许可风险清单（务必写进 credits）
- ⚠ **Keolai Pause Menu**：AssetLib 标 **GPLv3**，仓库无 LICENSE → **copyleft + 许可不明，避开**。
- ⚠ **cyberpunk-hud-demo**：无许可证 = 保留所有权利 → **只借鉴做法，不复制代码**。
- ✅ MIT：Maaack 全系、gloot、Wyvernbox、extra-controls、ThemeGen、CSS Theme、settings-menu-lite、lazy_menu_2、gohud（+ Tabler Icons MIT）。
- ✅ 字体 **OFL 1.1**（Noto Sans SC / Source Han Sans）：可随游戏分发，但**必须保留 OFL 文本**，且**不得用 "Source"/"Noto" 作为修改版字体名**（Reserved Font Name 条款）。
- ✅ **Kenney CC0**：无需署名（建议仍写进 credits）。
- ⚠ Maaack `ATTRIBUTION.md` 内的 **Git logo 是 GPL-2.0**（仅示范用图片，可直接删掉/替换）；Godot logo 为 **CC BY 4.0**（需署名）。
- 📌 建议直接用 Maaack 的 `credits_label.gd`（自动读 `ATTRIBUTION.md`）把上面各库许可列进去，中文 credits 同文件维护。

## 6. 明确「未验证」清单
- **Asset Library 版本号普遍滞后于 GitHub**：Maaack Menus（AssetLib 1.7.0 vs GitHub v1.7.1）、Options Menus（1.4.7 vs v1.6.0）、gloot（3.0.1 vs 3.0.2）→ 一律以 GitHub release 为准。
- **4.7 实机兼容性未验证**：Wyvernbox、lazy_menu_2、Simple Main Menu（sinnate，Apache-2.0，godot 4.2，最后更新 2024-07-22，6★）、Basic Settings Menu（mlm-games，MIT，AssetLib 3701，godot 4.1，2025-02-13，**是否落盘未验证**）、eXiForever 的 game-menu-kit-lite / settings-menu-lite（0★，2026-09-30 新建；kit 的 GitHub `license` 为 `NOASSERTION`，与其描述中的 MIT 不一致 → **许可未验证**）。
- **gohud 的 star 数（2）来自 shields.io**，GitHub API 因限流未复核；其"2,080 项 headless 测试通过"为 README 自述，未独立验证。
- **仅取元数据、未看源码**：Rubonnek/inventory-manager（AssetLib 3837，MIT，godot 4.2）、Cabbage0211 GBIS（4128）、Menkos InventoryForge（4645）、thunderplugins inventory-for-godot-4（4155）、ZhuElly Ellyality Inventory（4321）、Cianci InventoryToolkit（3578）、Yanel Main Menu Multi-Theme（4258）、tavurth godot-radial-menu（1885）、Miky Menu Transition System（3268）、MarkVelez godot-modular-settings-menu（3305）。
- **环境限制**：本会话 `pwsh` 因工作区 ACL 失败不可用（`SetNamedSecurityInfoW grantWrite(...)` 被拒），无法 clone 仓库或本地试跑；所有结论均基于 GitHub API / Asset Library API / jsdelivr 镜像的 README、文件树、release notes、翻译 CSV、许可原文。`raw.githubusercontent.com` 与 `cdn.jsdelivr.net` 直连被网络阻断，改用 `gcore.jsdelivr.net` / `fastly.jsdelivr.net` 镜像与 shields.io 取数。
