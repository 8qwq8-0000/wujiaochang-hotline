# macOS v0.1.0 通用预览版

2026-10-25，基于 `v0.1.0` / `84228cb` 的游戏内容补充 macOS 导出。

## 本地配置

- Godot 4.7.2，macOS 通用导出模板（arm64 + x86_64）。本机模板位于 `4.7.2.stable.mono/macos.zip`，标准版模板目录中的 `macos.zip` 链接到该文件；本项目没有 C# 业务脚本。
- `project.godot` 启用 `rendering/textures/vram_compression/import_etc2_astc`，满足 arm64/universal 导出检查。
- 本仓库通过 `.git/info/exclude` 忽略本地 `export_presets.cfg`。本次在该文件新增 `macOS` 预设，不更改 Windows 预设。
- 导出全部资源，额外包含 `*.json,*.csv`。排除 `docs/*,tests/*,tools/*,addons/L10nM4st3r-todomanager/*,addons/godot-git-plugin/*`。必须保留 `assets/fonts`，否则缺失字体会连带引发脚本加载错误。
- Bundle ID：`com.wujiaochanghotline.game`；版本：`0.1.0`；架构：`universal`；内置临时签名：`codesign/codesign=1`；不启用公证。
- 输出：`builds/macos/wujiaochang-hotline-macos-universal-v0.1.0.zip`。

```sh
godot --headless --path . --export-release macOS
```

导出后在 ZIP 根目录补入 `macOS-使用说明.txt`，生成同名 `.sha256` 校验文件。输出目录已被 Git 忽略。

## 验证结果

- 从最终游戏应用包解压运行；`lipo -archs` 确认包含 `x86_64 arm64`。
- `codesign --verify --deep --strict` 通过。
- 经 macOS 正常启动应用，Apple 芯片 Mac 上主菜单、设置页中文显示正常，点击“继续游戏”进入仓库正常，图形界面日志没有资源加载错误。
- 无界面启动 120 帧退出：没有启动资源加载或脚本解析错误，但退出仍有 4 个 ObjectDB 实例泄漏及 2 个资源仍在使用的警告/错误；不视作完全无警告。
- 未验证 Intel Mac、其他 Mac 或完整战斗流程。
- 内置模板声明最低版本为 Intel macOS 11、Apple 芯片 macOS 13；未在这些最低系统上测试。
- 未使用 Apple Developer ID 签名，未公证。其他电脑首次打开可能被 Gatekeeper 阻止，使用说明引导到“系统设置 > 隐私与安全性”确认来源后允许打开。

没有提交或推送本地配置改动，也没有移动现有版本标签。

最终 ZIP SHA-256：`350392f345a557d97c1e754b0f0dbe7915c200879b3b66facb2aaade7c27ba2a`。

## 发布

已将 Mac ZIP 与 `.sha256` 附件加入现有 `v0.1.0` Release，并更新平台说明。GitHub 返回 ZIP 为 `uploaded`，大小 `244620717` 字节，服务端 SHA-256 与本地一致。最终使用仅作用于上传进程的 en0 直连，上传约 45 秒；未更改日常 Clash 配置。临时上传代理进程和包含节点配置的临时目录已清理。
