# 频道归还 Boss 游戏内动画预览

2026-11-04。使用原楼顶房间、原玩家控制器，预览女神移动/施法及三组攻击特效。独立启动脚本移除原场景的结局控制器、神像、守卫和出口，不修改正式关卡文件；正式一、二结局流程尚未接入这些技能。

启动：

```sh
godot --path /Users/yangjiayao/Desktop/wujiaochang-hotline --windowed --resolution 1280x720 --script res://tools/play_channel_boss.gd
```

WASD移动；1回声落点、2光环裁断、3护子震波；空格开关自动轮播；P暂停；Esc关闭窗口。此预览无伤害与胜负判定，不扣血；WarehouseStore开启内存测试会话，不保存正式行动进度。玩家可自由移动观察，射击不会伤害预览角色。

附加 `-- --capture` 自动截取三组技能后继续轮播，窗口保持打开。截图为真实1280×720 Godot窗口渲染：echo.png、halo.png、protect.png。

已运行 `godot --headless --path /Users/yangjiayao/Desktop/wujiaochang-hotline --script res://tools/play_channel_boss.gd -- --check`，三组技能序列、64张纹理载入、效果清理、内存存档隔离通过。窗口三组截图完成，无脚本运行错误。headless退出仍有项目既有ObjectDB与资源释放诊断。

当前仅验证视觉和操控预览，尚未进行伤害范围、连续战斗平衡、通关或移动端验收。
