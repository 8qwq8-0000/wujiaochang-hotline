# 死亡喷血动画草稿 v1

2026-10-23，按“先做动画，然后切帧”制作第一阶段可播放预览。尚未导出独立序列帧、图集，未接入敌人死亡或修改现有战斗逻辑。

使用 Godot 原生像素绘制与确定性喷射轨迹制作，不调用远程付费动画服务。动画表现为向最后受击方向喷出三束深红血流、断裂成血滴并落地；当前展示朝右方向。15 FPS 的喷射表现叠加在30 FPS录屏上，预览总长约2.4秒，包含命中前停顿和落地展示。预览使用项目现有近战敌人和仓库地面作为比例、色彩参照；敌人淡出仅是预览辅助，不代表新增死亡动作。

- `blood_spray_preview.gd`：可复现的原生动画源。
- `preview.gif`：循环预览。
- `preview.mp4`：完整视频。

复现：

```sh
godot --path . --windowed --resolution 1280x720 --fixed-fps 30 --write-movie /tmp/death_blood_spray_v1.avi --quit-after 73 --script res://art_sources/animation_drafts/death_blood_spray_v1/blood_spray_preview.gd
```

已在Godot窗口渲染后检查喷射峰值、血滴扩散和落地阶段。FFmpeg转为GIF/MP4；GIF 960×540、37帧、约2.47秒。后续根据用户反馈调整，再导出统一画布和锚点的透明效果序列。

## 已确认后的16向版本

用户确认预览并要求按致命伤方向选择动画。完整实现见 `directional/` 与 `assets/art/effects/death_blood_spray_v1/README.md`。现在已切帧并接入死亡事件；上文“未切帧、未接入”仅描述最初朝右预览阶段。
