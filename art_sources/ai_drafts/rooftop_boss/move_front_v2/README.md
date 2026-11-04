# 女神正面轻微移动动画 v2

2026-11-04，使用内置 ImageGen，参考 ../standing_v1/rooftop_goddess_standing_v1.png 编辑生成。按用户反馈大幅减少飘动。只做正面移动，无侧背面及技能，尚未接入游戏。

提示词要求：4列2行共8帧；原造型、比例与轮廓基本不变，身体光环双手及幼鲸固定；取消明显上下浮动、长发外张、裙摆掀起与大幅摆尾，仅发梢、衣摆与尾尖轻微移动，目标384×512画布上1–2像素幅度；真正透明背景，无技能动作。

保留生成原图 move_source_sheet_4x2.png。以光环中心和顶部统一帧锚点后，导出frames/与move_aligned_sheet_4x2.png。每帧180ms，8帧循环。move_preview.gif为深色预览，move_transparent.webp保留半透明，GIF二值透明仅供预览，游戏素材采用PNG。AI生成存在局部细节波动，属于动画草稿。
