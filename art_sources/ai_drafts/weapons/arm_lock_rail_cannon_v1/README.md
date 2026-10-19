# 腕锁电磁炮

2026-10-19 根据用户后续决定重新制作电磁炮，仅提供美术预览，不加入物品池、不实现持续伤害。Codex 内置 ImageGen，以同伴的 40×16 手枪和 48×20 霰弹枪为风格参考。透明原图 source.png；Godot Image 裁去透明边缘、Lanczos 重采样并居中导出 assets/art/weapons/placeholder/arm_lock_rail_cannon.png（48×16），场景单倍缩放。

提示词：one electromagnetic ARM-LOCK CANNON matching two reference pixel weapon sprites; orthographic side view pointing right; left circular silver-gray wrist collar; dark gunmetal receiver, off-white angular armor, small cyan recessed coil, thick twin-rail barrel; no pistol grip, trigger guard, shoulder stock, scope, hands; limited 14-16-color chunky hard-edge pixel-art style; no tiny realistic detail, labels, backdrop or effects; transparent RGBA; cuff and muzzle share horizontal axis.

腕锁沿用 PlayerWristSocket 和 ProceduralCoating2D。光柱复用之前已生成素材的游戏尺寸版本，亮起 0.24 秒、淡出 0.08 秒。展示场景：scenes/debug/weapon_art_showcase.tscn。
