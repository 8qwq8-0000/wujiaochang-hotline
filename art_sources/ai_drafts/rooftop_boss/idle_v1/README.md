# 楼顶女神基础待机动画 v1

2026-11-04，内置 ImageGen 编辑生成。仅正面悬浮待机，不含技能动画，尚未接入游戏。

参考：../standing_v1/rooftop_goddess_standing_v1.png

生成要求：保持现有女神身份、蒙眼、蓝色长发、白金长袍、机械光环、单条鲸尾与怀中幼鲸；4列2行共8帧，统一比例与锚点；轻微悬浮、发梢衣摆与尾部缓慢摆动；透明背景；不转身、不施法、不攻击。

保留生成原图 idle_sheet_4x2.png；frames/ 为 384×512 原始透明切帧。预览使用往返循环，14个播放帧，每帧160ms。idle_preview.gif 使用深色背景；idle_transparent.webp 保留半透明；idle_transparent.gif 为兼容预览使用二值透明，游戏应采用 PNG。AI 连续帧有局部细节波动，属于动画草稿。
