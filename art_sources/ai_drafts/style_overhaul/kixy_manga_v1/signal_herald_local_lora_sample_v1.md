# 传令兵：本地画风 LoRA 样图 v1

- 图片：`signal_herald_local_lora_sample_v1.png`，768 × 1152。
- 生成：本地 Z-Image Turbo FP8 + `kixy_manga_style_v1.safetensors`，触发词 `kixymanga`，LoRA 强度 0.85。
- 参数：8 步，CFG 1.0，`res_multistep` / `simple`，shift 3.0，seed 202611032337。
- 可复现工作流：`D:\ai-lora\workflows\kixy_manga_signal_herald_final_lora_v1_api.json`。
- 角色参照：`art_sources/ai_drafts/enemies/signal_herald_v3/approved_concept.png`。

## 观察

画风呈现了暖纸色、松动墨线、局部排线、淡紫色城市轮廓和橙色点色。旗帜、广播波纹、深蓝制服和挎包可辨。

此图仅作画风方向样图：头部变成露出人脸的军帽，原设定的封闭式头盔、面甲和厚实分段护甲没有保住；通信背包也被简化。暂不作为游戏内角色定稿或批量改造基准。

针对这些问题准备了 `D:\ai-lora\workflows\kixy_manga_signal_herald_final_lora_v2_api.json`（LoRA 强度 0.72、明确封闭头盔等结构）。首次提交遇到 Windows 虚拟内存不足；重启 ComfyUI 后重试又在文本编码器加载阶段发生原生访问冲突，没有生成第二张。
