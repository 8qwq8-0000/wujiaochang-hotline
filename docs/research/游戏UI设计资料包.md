# 《五角场热线》游戏 UI 设计资料包

> 调研日期：2026-10-21  
> 适用版本：Godot 4.7、Windows 键鼠、640×360 逻辑画布  
> 项目基线：`docs/design/赛博朋克UI视觉基线.md`  
> 目的：为战斗 HUD、背包、仓库、合成、人格整备、设置与结算页提供可执行的视觉和交互参考。

## 1. 先看结论

本项目不适合照搬“紫粉霓虹 + 大量透明玻璃”的通用赛博朋克 UI。更合适的方向是：

- **信息结构参考《Hades》**：战斗中只保留立即影响决策的内容，奖励与选择界面一次只回答一个问题。
- **工作区参考《Control》**：装备、模块和详情保持明确的“列表／槽位／详情”层级，但压缩为本项目的 2×3 背包与固定装备槽。
- **终端气质参考《SIGNALIS》与《The Final Station》**：像素字体、工业终端、受控的 CRT 故障和单色主界面。
- **清晰度参考《Into the Breach》**：先让玩家看懂行动后果，再谈装饰；状态图标、预警和反馈必须形成闭环。
- **可访问性以 Xbox Accessibility Guidelines 为验收下限**：文字、焦点、对比度、非颜色通道和动态效果都要可检查。
- **Godot 落地继续走 Theme + 类型变体 + 自绘 Control**：现有 `CyberUITheme`、`TerminalPanel`、`SegmentMeter`、`CRTOverlay` 路线正确，不需要采购整套 UI 美术。

最值得立即做的不是继续加纹理，而是：统一非主菜单页面的视觉语言、补全键盘焦点、验证战斗画面上的动态对比度，并让背包／合成／仓库共用同一套信息结构。

## 2. 参考库：用于找图，不用于直接搬素材

| 资料库 | 适合查什么 | 本项目建议检索词／分类 | 注意 |
|---|---|---|---|
| [Game UI Database](https://www.gameuidatabase.com/) | 按屏幕、元素、颜色、风格筛选已发行游戏 UI | HUD、Inventory、Settings、Sci-Fi、Pixel、CRT | 截图仅供分析，不能当可复用素材 |
| [Interface In Game](https://interfaceingame.com/screenshots/) | 按游戏或 UI 元素查看截图、动效片段 | In game、Inventory、Overlay、Settings、Tutorial | 优先看视频，静态图无法说明状态切换节奏 |
| [PlayCraft](https://playcraft.space/) | 带设计说明的界面案例与模式拆解 | HUD、Battle、Base Management | 适合分析“为什么这样组织”，不只看美术 |
| [Godot UI 文档入口](https://docs.godotengine.org/en/stable/tutorials/ui/index.html) | Control、Container、Theme、焦点和字体的实现方法 | Theme、Containers、Keyboard Focus、Fonts | 实现时优先查 stable 文档 |

推荐收集方法：每个待做页面只选 **3 个案例**，并分别记录“信息层级、交互顺序、反馈时机”；不要建立只有氛围图、没有设计结论的情绪板。

## 3. 最值得拆解的游戏案例

### 3.1 《Hades》：俯视角高速战斗 HUD 与奖励选择

参考：[Hades UI 页面](https://interfaceingame.com/games/hades/)

重点看：

- 战斗画面中心区域很干净，生命与资源固定在边缘，临时信息在需要时出现。
- 奖励、商店、武器和天赋页面每次都突出一个主要选择，不让所有信息争夺注意力。
- 不同神祇／奖励有独立人格色，但基础交互结构不变。

对应本项目：四角 HUD 和“人格专属色只用于头像、名牌、能力反馈”的规则应保留；人格色不能替代危险红、警告黄和成功色。

### 3.2 《Control》：模块、配装与详情层级

参考：[Control UI 页面](https://interfaceingame.com/games/control/)

重点看：

- 武器形态、个人模块、材料等复杂系统保持一致的栏目和选中态。
- 列表负责浏览，详情区负责解释，动作入口始终靠近当前对象。
- 画面视觉语言高度统一，但系统过多时导航层级也会变深。

对应本项目：背包、仓库与合成统一为“对象列表／当前槽位／诊断详情／可执行动作”四层；不要用漂浮 Tooltip 承载必要信息。项目规模较小，不应照搬多级页签。

### 3.3 《SIGNALIS》：工业终端、CRT 与六格背包

延伸阅读：[Glancing Signalis：界面与沉浸](https://steventus.substack.com/p/glancing-signalis-part-1-immersion)、[六格背包的实际体验讨论](https://gamefaqs.gamespot.com/pc/287149-signalis/reviews/179103)

重点看：

- 固定、有限的背包容量本身就是资源决策，而不是单纯 UI 限制。
- CRT、故障和单色界面服务于世界观，但关键文字仍保持稳定。
- 状态、地图、无线电和物品检查都像同一台设备的不同程序。

对应本项目：现有 2×3 普通背包与独立黑匣很适合终端化表达。应让“受保护／不占六格／保险是否生效”在槽位外观和详情文本上同时出现，避免只靠颜色。

### 3.4 《The Final Station》：低分辨率像素界面

参考：[The Final Station UI 页面](https://interfaceingame.com/games/the-final-station/)

重点看：

- 小画布中通过大块留白、短标签和稳定面板位置减少拥挤。
- 对话、便签、商店、库存与暂停页保持相同像素密度。
- 装饰线很少，重要信息不被细碎边框淹没。

对应本项目：640×360 下不要把每个区域都框成独立小面板；优先用间距和对齐分组，边框只表示真正的交互边界。

### 3.5 《Into the Breach》：UI 驱动的战斗可读性

参考：[GDC 2019 设计复盘 PDF](https://media.gdcvault.com/gdc2019/presentations/Into%20the%20Breach%20Postmortem%20Final.pdf)

重点看：

- 设计过程把“行动结果能否被预测”放在视觉表现之前。
- 敌人意图、受影响对象和结算顺序形成完整的信息链。
- 图标和高亮是战斗规则的一部分，不是后期装饰。

对应本项目：完美格挡、过热、导电连锁、炸弹箱范围和敌人蓄力都应在行动前显示“将发生什么”，行动后显示“实际发生了什么”。

### 3.6 《Halo Infinite》：设置页、焦点与输入提示

参考：[Halo Infinite UI 页面](https://interfaceingame.com/games/halo-infinite/)

重点看：

- 设置、控制图和确认弹层的栏目命名稳定。
- 当前焦点、不可用项和危险操作的差异足够明显。
- 同一功能在键鼠和手柄下能保持一致的语义结构。

对应本项目：当前只验收键鼠，但仍应保证仅用键盘可以完整操作菜单；键位提示必须从 InputMap 读取，不在文案中写死。

### 3.7 《Cyberpunk 2077》：只参考系统化生产，不照搬视觉密度

参考：[GDC：User Interface in Cyberpunk 2077](https://gdcvault.com/play/1034167/User-Interface-in-Cyberpunk-2077)

值得学习的是组件化、性能预算和大量 UI 实例的生产管线。其视觉密度、三维空间 UI 和大型项目工具链超过本项目需要，不应作为首版完成度标准。

### 3.8 《Citizen Sleeper》：信息 UI 与人格通讯

参考：[Game Design Roundtable 第 316 期](https://thegamedesignroundtable.com/episode/316-citizen-sleeper-with-gareth-damian-martin/)（约 39:13 开始讨论 Information UI Design）

重点看：如何用栏目、轨道、文本和少量人物形象构成完整科幻世界，而不是依赖昂贵动画。对应本项目，可用于人格整备处和“接线员｜人格”通讯，但战斗提示应比叙事界面更短、更直接。

## 4. 设计与可访问性资料

### 4.1 必查清单

| 主题 | 资料 | 对本项目的直接要求 |
|---|---|---|
| 文字 | [Xbox XAG 101：Text display](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/101) | 关键文字不能因 CRT、描边或背景变化失去可读性；设置应影响所有关键页面 |
| 对比度 | [Xbox XAG 102：Contrast](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/102) | 战斗 HUD 要在最亮和最暗场景中实测；图标、准星、血条也属于关键元素 |
| 非颜色通道 | [Xbox XAG 103：Additional channels](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/103) | 危险／警告／成功除颜色外，还要有标题、形状、分段或文本 |
| 导航 | [Xbox XAG 112：UI navigation](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/112) | 页面结构和确认／返回行为保持一致，焦点移动必须可预测 |
| 焦点 | [Xbox XAG 113：UI focus handling](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/113) | 当前焦点不能只用轻微辉光；使用 `>`、2 px 边框和明度变化的组合 |
| 上下文 | [Xbox XAG 114：UI context](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/114) | 执行动作前说明结果，特别是覆盖存档、丢弃、合成和离开整备处 |
| 动效 | [Xbox XAG 117：Visual distractions and motion](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/117) | CRT 扫描线和事件故障要可降低或关闭；不持续抖动 |

### 4.2 当前色板的对比度快速检查

以下为不计半透明叠加时，与背景 `#04100D`／面板实色 `#071A16` 的 WCAG 相对对比度：

| 颜色 | 对背景 | 对面板 | 结论 |
|---|---:|---:|---|
| 主色 `#72FF9A` | 15.19:1 | 14.11:1 | 可用于正文和关键控件 |
| 暗色 `#286B45` | 3.02:1 | 2.81:1 | 仅用于装饰刻度／边框，不用于 12 px 文字 |
| 高亮 `#D8FFE2` | 17.81:1 | 16.54:1 | 适合焦点和成功状态 |
| 警告 `#FFC857` | 12.58:1 | 11.68:1 | 适合警告文字和仪表 |
| 危险 `#FF4055` | 5.64:1 | 5.24:1 | 满足普通文字最低对比，但仍要配图形／标题 |
| 弱化 `#7FA890` | 7.29:1 | 6.77:1 | 可用于说明文字；降低透明度后需要重新测试 |

注意：`font_disabled_color = MUTED × 0.48 alpha` 叠在半透明面板上时可能过暗。禁用态可以降低饱和度，但仍应让玩家读出“这是什么、为什么不可用”。

## 5. Godot 4 落地资料

| 主题 | 官方资料 | 项目应用 |
|---|---|---|
| Theme 与级联 | [Introduction to GUI skinning](https://docs.godotengine.org/en/stable/tutorials/ui/gui_skinning.html) | 全局字体、颜色和控件状态集中进 `CyberUITheme` |
| 类型变体 | [Theme type variations](https://docs.godotengine.org/en/stable/tutorials/ui/gui_theme_type_variations.html) | 使用 Warning／Danger／Muted／Primary 等语义变体，少做页面级临时 override |
| Theme 编辑器 | [Using the theme editor](https://docs.godotengine.org/en/stable/tutorials/ui/gui_using_theme_editor.html) | 建一个组件预览场景，同时检查 normal／hover／pressed／focus／disabled |
| Container 布局 | [Using Containers](https://docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html) | 工作区用容器管理，不靠大量硬编码坐标 |
| 分辨率 | [Multiple resolutions](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html) | 640×360 是官方列出的像素风常用基线；项目需决定 `canvas_items` 是否符合“整数像素”目标 |
| Control 与焦点 | [Control 类文档](https://docs.godotengine.org/en/stable/classes/class_control.html) | 配置 `focus_neighbor_*`、`focus_next`、`focus_previous` 和初始 `grab_focus()` |
| 辅助信息 | [Godot screen reader integration](https://docs.godotengine.org/en/stable/tutorials/ui/creating_applications.html#screen-reader-integration) | 为关键 Control 增加 `accessibility_name`／`accessibility_description`，保持逻辑阅读顺序 |

工程现状对照：

- 已有统一 Theme、语义色、终端面板、分段仪表和 CRT Overlay，基础方向正确。
- `project.godot` 当前为 640×360、`canvas_items`、`expand`。如果目标是严格像素整数缩放，应专项对比 `viewport + keep + integer`；如果更重视子像素运动与宽屏扩展，则保留现状并检查字体、1 px 边框在 1366×768 等非整数倍率下是否发虚。
- 当前 UI 脚本／场景中未检索到显式 `focus_neighbor_*` 或 `accessibility_*` 配置，这是比继续加视觉装饰更优先的工程项。
- `inventory_panel.gd`、`warehouse_panel.gd`、`synthesis_panel.gd` 仍有各自的临时配色与尺寸逻辑，建议逐步迁移到同一主题和语义组件。

## 6. 可用素材与许可

本项目的 UI 基线是不依赖外部面板美术，因此以下资源只作为原型或缺失图标的备用，不建议整包套皮：

| 资源 | 许可 | 用法建议 |
|---|---|---|
| [Kenney UI Pack](https://kenney.nl/assets/ui-pack) | CC0-1.0 | 快速验证按钮、滑杆和九宫格尺寸；正式版建议换回自绘终端组件 |
| [Tabler Icons](https://github.com/tabler/tabler-icons) | MIT | 仅挑少量通用语义图标并像素化重绘；引入时固定版本并登记许可证 |
| [Ark Pixel Font](https://github.com/TakWolf/ark-pixel-font) | OFL-1.1 | 工程已使用；继续保留许可证文本并检查中文字形覆盖 |

任何外部截图、游戏 Logo、角色图或 UI 成品都只能用于内部参考，不能切图进入游戏。新引入资源要同步登记到 `docs/legal/素材来源与许可.md`。

## 7. 面向当前版本的页面规范

### 战斗 HUD

- 中央 50% 左右区域只保留准星、目标角标和极短的命中／格挡反馈。
- 常驻信息只放“现在会影响战斗决策”的耐久、热量、当前武器、机动和警戒。
- 提示队列最多 3 条；同类合并；接管通讯打断普通提示，但不遮准星。
- 每个危险事件都包含预警、发生、结束三态，至少使用两种通道（颜色 + 形状／文字／声音）。

### 背包、仓库与合成

- 左侧浏览对象，中部展示装备／材料关系，右侧固定显示详情和结果。
- 选中、拿起、可放置、不可放置、交换、危险操作必须是不同状态。
- 品质、词条、黑匣保护和兼容性不能只靠颜色。
- 合成前展示输入、保留／丢失内容和最终结果；确认后给出可逆或不可逆的明确反馈。

### 人格整备与通讯

- 人格色只作为局部识别，不改变通用按钮和危险语义。
- 通讯卡片标题保持“接线员｜人格”，正文限制为单句；需要玩家选择时切换到完整工作区。
- 隐藏关系与增长条件不显示；玩家能操作的授权、等级、天赋和离开损失必须显示。

### 设置、暂停与破坏性操作

- 页面第一焦点明确；Esc 始终返回上一级或关闭最上层界面。
- CRT 提供关闭／低／标准，关闭后完全去除扫描线、噪点和故障。
- 新存档覆盖、丢弃装备、确认合成等使用结果导向文案，例如“创建新存档并备份当前进度”，不要只写“确定吗”。

## 8. 首轮评审清单

每个页面在合入前至少完成以下检查：

1. 截取空闲、悬停／焦点、操作中、成功、失败／危险五种状态。
2. 在最亮战斗场景和最暗场景中各录制 20 秒，而不是只看透明背景上的静态 UI。
3. 只用键盘完成进入、操作、确认、取消和返回。
4. 临时转为灰度，确认品质、危险和焦点仍可区分。
5. 将 CRT 关闭，确认信息层级仍成立；若关闭后界面失去结构，说明装饰承担了不该承担的功能。
6. 以 1280×720、1920×1080 和一个非整数倍率窗口检查字体与 1 px 边框。
7. 对照本页实际任务，删除没有支持决策的装饰标签、重复数值和长期动画。

## 9. 推荐阅读顺序（约 2 小时）

1. 15 分钟：重读项目《赛博朋克 UI 视觉基线》。
2. 25 分钟：浏览 Hades 的 Fight／Inventory／Settings 和 Control 的 Loadout／Mods。
3. 20 分钟：阅读 SIGNALIS 界面分析，明确 CRT 和六格背包各自在服务什么。
4. 25 分钟：看 Into the Breach 复盘中的 UI-guided design 部分。
5. 20 分钟：阅读 XAG 101、102、112、113 的目标与实现建议。
6. 15 分钟：对照 `cyber_ui_showcase.tscn`，只记录三个最影响玩家判断的问题，进入下一轮实现。
