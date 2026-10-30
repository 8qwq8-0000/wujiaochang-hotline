# iOS 手机端适配实施说明

## 已接入的能力

iOS 与 Android 共用 `MobileInput`、虚拟摇杆、多点触控动作键和战斗逻辑。原生 iOS 自带 `mobile` 特性，无需伪造 Android 标记。保持左右横屏、Compatibility 渲染器与移动纹理导入设置。触控按键布局将 Retina 物理像素中的安全区换算到游戏画布，避开两侧刘海和底部 Home 指示区域；iPad 顶部及底部安全区使用相同换算。后台暂停、音频静音、恢复及触摸释放继续复用移动端实现。

`export_presets.cfg` 新增 `iOS Xcode Project`：

- 输出：`build/ios/Hotline.xcodeproj` 与同目录游戏包。
- 支持 iPhone 和 iPad，最低 iOS 15，设备架构 ARM64。
- Bundle ID：`com.wujiaochang.hotline`，版本 `0.1.0`，构建号 `1`。
- 只生成 Xcode 工程，不自动签名、归档或上传。
- `0000000000` 是满足 Godot 工程生成要求的占位 Team，不是真实 Apple 团队，不能用于真机签名。实际 Team 在本地 Xcode 中选择，不提交个人证书或描述文件。
- 不申请摄像头、麦克风或相册权限。开发文档、美术源文件、测试、工具和构建目录不进入此预设的游戏包。

## 本机检查、导出和编译

在项目目录运行：

```sh
python3 tools/build_ios.py --check
python3 tools/build_ios.py --export
python3 tools/build_ios.py --build device
python3 tools/build_ios.py --build simulator
```

工具使用完整 Xcode 的 SDK；若未设置 `DEVELOPER_DIR`，优先使用 `/Applications/Xcode.app/Contents/Developer`，不修改系统全局 `xcode-select`。Godot 可用 `GODOT_BIN` 指定。要求安装与当前编辑器版本匹配的 `ios.zip` 导出模板。

`--build` 会先重新导出，再以关闭签名的方式编译。设备产物在 `build/ios/device/Build/Products/Debug-iphoneos/Hotline.app`；模拟器产物在 `build/ios/simulator/Build/Products/Debug-iphonesimulator/Hotline.app`。未签名设备产物不能直接安装到 iPhone，亦不是可分发 IPA。`build/` 会创建 `.gdignore`，防止生成物再次被当作游戏资源导入；这些产物不提交 Git。

模板的 XCFramework 元数据可能声称包含 ARM64 / x86_64 模拟器架构，但其中静态库实际只有 x86_64。工具在编译前通过 `lipo` 检查真实架构，优先使用主机原生架构；没有原生切片时明确报告使用交叉编译。x86_64 编译成功不能替代 Apple Silicon 原生模拟器运行验证。

## 安装到自己的 iPhone

1. 在 Xcode 的 Settings → Accounts 中登录自己的 Apple ID。
2. 打开生成的 `Hotline.xcodeproj`，选择 Hotline target 的 Signing & Capabilities。
3. 开启 Automatically manage signing，选择自己的 Team，替换占位团队。若当前 Bundle ID 无法使用，在这个本地工程里修改为自己团队可用的标识。
4. 选择已配对的 iPhone，按 Xcode 提示完成设备信任、开发者模式及签名配置，然后运行。
5. 真机验证左右横屏、安全区、多指同时移动/攻击/盾反、切后台与锁屏恢复、背包触控，以及连续战斗性能。

登录、信任和设备上的开发者模式由用户完成；不在文档或仓库记录 Apple ID 密码、证书私钥、真实 Team 或设备标识。重新从 Godot 导出会刷新生成工程，因此应再次检查本地签名选择。

## 验证记录（2026-10-30）

- Godot 4.7.2 / Xcode 27.2 / iOS SDK 27.2：已生成 Xcode 工程。
- iPhone ARM64 未签名 Debug 编译成功；x86_64 模拟器 Debug 编译成功。
- `ios_mobile_check.gd` 的 12 项导出配置和安全区检查通过；`mobile_controls_check.gd` 触控回归无失败。
- 此机已有的 `4.7.2.stable.mono/ios.zip` 用于本次本地编译验证，标准版本目录通过符号链接引用它；该环境操作不写入工程配置。模板的设备 ARM64 切片可编译，模拟器切片实际只有 x86_64。
- 用户登录 Xcode 后，使用个人开发团队自动创建签名证书与设备描述文件，ARM64 签名构建成功，`codesign --verify --deep --strict` 校验通过，并已通过 `devicectl` 安装到已配对 iPhone。真实团队只配置在被 Git 忽略的生成工程中。
- 首次启动被开发者信任策略拒绝；用户在手机上完成信任后，`devicectl` 成功启动游戏，并连续两次确认进程仍在运行。描述文件到期时间为 2026-11-06，届时需重新签名安装。
- 已完成真机安装及启动验证；未完成真机触控、完整通关或性能测试。未安装 iOS Simulator 运行时，没有声称完成模拟器运行验证。Godot 退出时仍有 ObjectDB / 资源释放警告。

官方导出要求：<https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html>

## 手机点击继续修复（2026-10-30）

对话场景直接处理原生 `InputEventScreenTouch`，不再依赖模拟鼠标充当 Enter。序章开场、教学通讯、Codex、到仓库提示和储物引导都支持轻触屏幕继续；移动端文案同步显示轻触提示。仅主触点按下推进，松手、取消、多余触点和模拟鼠标不重复推进；序章跳过按钮区域保留给原来的长按逻辑。此处理仅在相应对话打开时生效，不把普通战斗点击全局映射成 Enter。

`mobile_dialogue_check.gd` 13 项原生触屏检查通过，序章回归 135 项通过，共享摇杆回归无失败。修复版本已重新签名并通过原 Bundle ID 覆盖安装；手机实际轻触效果仍待用户确认。

## 手机背包修复（2026-10-30）

背包增加独立关闭按钮，手机轻触即可退出；不再依赖键盘 Tab。面板限制在系统安全区内，标题/关闭栏、说明和底部丢弃区固定显示，中间装备列表支持滑动。滑动会取消槽位点按及长按计时，避免误换装；静止长按仍进入原有装备拖放事务，原生触摸松手通过同一校验完成丢弃或交换，并取消后续重复的模拟鼠标投递。

`mobile_inventory_panel_check.gd` 的 13 项实际窗口检查通过，覆盖横屏布局、原生触控关闭、滑动不误换装、长按拖到完整丢弃区，以及桌面 Tab 兼容。合并后的修复版本已重新签名、通过原 Bundle ID 覆盖安装并成功启动；未卸载原应用或重置存档。手机实际交互效果仍待用户确认。

## 背包真机布局与操作文案复查

上一轮仅用桌面窗口验证布局，未覆盖 iOS 上控件最小尺寸与安全区变化。背包外框改为尺寸受限的普通 Panel，内部容器填满安全区，说明文本最多显示两行；打开时和可见期间持续按安全区校正尺寸，防止容器的内容最小尺寸把外框撑到屏幕以外。

手机提示统一由 `ControlPrompts` 适配：保留桌面原文，手机显示交互、背包、突进、盾反和攻击摇杆等实际操作。除序章对话外，也处理目标标记、场景静态标签、拾取提示、增益箱、仓库引导、合成反馈和战斗提示；射击文案区分点按自动瞄准与拖动手动射击。

显式调试入口 `scripts/debug/mobile_ui_probe.gd` 由 MobileInput 在 Debug 构建检测到 `user://mobile_ui_probe.request` 一次性请求文件时调用（桌面也可传 `--mobile-ui-probe` 用户参数）。使用内存隔离档案，记录真机 viewport、安全区、背包/关闭按钮/丢弃区边界及可见电脑按键文案，并输出游戏内截图；请求文件在执行前删除，不重置正式档案。正常启动不执行此入口。iOS 模板未按桌面方式响应 `--script` 启动参数，因此真机使用请求文件；检查结束后已正常重启应用。

### iPhone 原生验证结果

2026-10-30 在已配对 iPhone 上重新签名、覆盖安装后，通过隔离场景取回实际渲染截图和 JSON 布局报告：

- 窗口物理尺寸 2622×1206，游戏 viewport 782×360；安全区约为 `(61.47, 6, 659.05, 330.09)`。
- 背包外框 `(131, 6, 520, 330.09)`；关闭按钮 `(541, 16, 100, 36)`；丢弃区 `(141, 282, 500, 44)`，均完全在安全区内。
- 可见仓库和背包控件中的电脑按键文案残留为零。真机运行时的 E/Tab/鼠标射击示例转换结果均为手机按钮及攻击摇杆说明。
- 注入原生触控事件后，背包关闭验证通过。此检查不等于用户手指实玩或全流程性能验证。
- 隔离检查后已恢复正常启动。桌面回归中，手机文案 52 项、背包 14 项、触屏对话 13 项、序章 135 项通过。
