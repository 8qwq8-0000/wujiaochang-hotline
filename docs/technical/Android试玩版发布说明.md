# Android 试玩版发布

`Android Preview APK` 预设使用 Godot 预编译 Android 模板直接打包，没有额外原生插件，因此不需要生成 Gradle 工程。此模式不覆盖模板的 min/target SDK，实际要求以 APK 清单检查结果为准。原 Android Debug APK 预设保留。发布包排除未引用的备用字体、`_ref_media` 和广告原图，保留中文界面实际使用的三份字体，不删除仓库素材。试玩版为非 Debug 构建，沿用 Godot 4.7.2 预编译模板的 Android 7 / API 24 起，目标 API 36，包含 ARMv7 和 ARM64，应用标识为 `com.wujiaochang.hotline`。

## 构建

```sh
python3 tools/build_android.py
```

需要 Godot 4.7.2 的 Android release 模板、JDK 21，以及 Godot 编辑器设置中配置的 Android SDK（默认 `~/Library/Android/sdk`）下的 platform-tools 和 build-tools 36.0.0。可通过脚本的 `--sdk` / `--java-home` 指定检查路径，但 SDK 路径同时需要与 Godot 编辑器设置保持一致。

输出为 `build/android/wujiaochang-hotline-android-v0.1.1-mobile-preview.1.apk` 和同名 `.apk.sha256`。脚本在输出后执行 ZIP 完整性检查与 apksigner 签名校验。APK 可直接下载到 Android 手机安装，不要求手机安装 Godot 或登录开发者账户。

## 签名与后续覆盖更新

首次构建会在本机 `~/.codex/app-signing/wujiaochang-hotline/` 创建长期使用的 release 私钥及本地凭据 JSON，文件权限为 600；后续构建复用同一签名。务必自行备份该目录。私钥、密码和凭据不提交 Git，不上传 Release，公开附件只有安装包与校验文件。丢失密钥会影响后续同签名覆盖更新。

## 发布与验证边界

以包含当前源码的提交创建独立安卓预览标签，不替换旧桌面版附件。Release 附带 APK、SHA-256 与简短安装说明。签名校验、包结构及共享逻辑检查不能替代 Android 真机测试；没有安卓设备实际试玩时，明确标为预览版并说明尚未真机验证。

## 本次静态校验

实际 APK 清单确认：包名正确，versionCode 2，最低 API 24、目标 API 36，包含 ARM64/ARMv7，未启用 debuggable，申请的运行权限只有震动。APK Signature Scheme v2/v3 验证、ZIP CRC 完整性和 16 KB ZIP 对齐检查通过。Android 工具仍报告预编译模板中未被主图标引用的 themed_icon XML 资源告警；主启动图标引用的 icon 资源及自适应 icon.xml 均存在。

本次共享检查：手机文案 52 项、触屏对话 13 项、背包 14 项、序章 135 项及 96 项单元检查通过；摇杆检查无失败。未连接安卓设备，没有声称完成 Android 原生启动、实玩或性能验证。Godot 退出时仍有既存资源/ObjectDB/RID 释放告警。
