extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	var samples := [
		"WASD＋空格突进 · 避开攻击并撞向敌人", "空格 / 突进撞击敌人",
		"鼠标朝向来弹 · 命中前按右键，将子弹弹回击杀敌人",
		"按 Tab 打开背包 · 点击手枪或拖到武器槽 · Tab 关闭",
		"鼠标瞄准，点左键开火", "靠近 Codex 按 E 对话     WASD 移动 · Tab 配装",
		"[E] 存取装备", "E / 领取攻速增益", "合好按 Esc 回来",
		"已丢到脚边。关闭背包后按 E 拾回", "WASD 移动，鼠标战斗，Space 机动，Tab 背包",
		"WASD 移动   E 交互   Tab 配装   Esc 设置", "关闭 [Esc]", "返回 [Esc]",
		"按住方向再按空格", "装好再按 Tab 回来", "还有未选择的天赋，按 Esc 返回",
	]
	for sample in samples:
		var mobile := ControlPrompts.adapt(sample, true)
		var has_desktop_key := false
		for key in ["Tab", "Esc", "Enter", "WASD", "Space", "按 E", "[E]", "鼠标", "左键", "右键", "空格"]:
			if mobile.contains(key):
				has_desktop_key = true
		check(not has_desktop_key, "touch prompt contains no keyboard instruction: " + mobile)
		check(ControlPrompts.adapt(sample, false) == sample, "desktop wording remains unchanged")
		check(ControlPrompts.adapt(mobile, true) == mobile, "adapting an already adapted prompt is stable")
	check(ControlPrompts.adapt("鼠标瞄准，点左键开火", true).contains("自动瞄准") and ControlPrompts.adapt("鼠标瞄准，点左键开火", true).contains("手动瞄准"), "mobile shooting explains both tap auto-aim and drag manual aiming")
	print("Mobile control prompts checks: %d; failures: %d" % [checks, failures])
	root.get_node("GameSettings").quit_game(0 if failures == 0 else 1)
