class_name ControlPrompts
extends RefCounted

# Keep desktop copy intact; describe the actual touch controls on native phones.
# Longer phrases precede key tokens because aiming/closing differ by device.
const TOUCH_PHRASES := [
	["WASD 移动，鼠标战斗，Space 机动，Tab 背包", "摇杆移动 · 攻击键射击 · 突进 · 背包配装"],
	["WASD 移动   E 交互   Tab 配装   Esc 设置", "摇杆移动   交互键使用   背包键配装   暂停键设置"],
	["按住方向再按空格", "推动左侧摇杆，再轻点「突进」"],
	["WASD＋空格突进", "推动摇杆＋轻点「突进」"],
	["鼠标朝着来弹，快打中你时按右键", "快被子弹击中时轻点「盾反」，也可拖动盾反键指定方向"],
	["鼠标朝向来弹 · 命中前按右键", "来弹命中前轻点「盾反」，可拖动指定方向"],
	["鼠标瞄准，点左键开火", "点按「攻击」会自动瞄准敌人；向外拖动攻击摇杆可手动瞄准并持续开火"],
	["点击左键射击", "点按攻击自动瞄准，拖动攻击摇杆手动开火"],
	["按 Tab 打开背包 · 点击手枪或拖到武器槽 · Tab 关闭", "轻点「背包」打开 · 点按手枪装备 · 右上角关闭"],
	["装好再按 Tab 回来", "装好后轻点右上角「关闭」回来"],
	["合好按 Esc 回来", "合好后轻点右上角「返回」回来"],
	["关闭 [Esc]", "关闭 ×"], ["关闭 [Tab]", "关闭 ×"], ["返回 [Esc]", "返回"],
	["按 Esc 返回", "轻点「返回」"], ["按 Esc", "轻点「返回」"],
	["按 Tab", "轻点「背包」"], ["按 E", "轻点「交互」"],
	["按右键", "轻点「盾反」"], ["按空格", "轻点「突进」"],
	["[E]", "[交互]"], ["E /", "交互 /"], ["E 领取", "交互键领取"], ["E 交互", "交互键使用"],
	["WASD", "左侧摇杆"], ["鼠标瞄准", "拖动攻击摇杆瞄准"], ["鼠标", "攻击摇杆"],
	["右键", "盾反键"], ["左键", "攻击键"], ["空格", "突进键"], ["Space", "突进键"],
	["Tab 关闭", "右上角关闭"], ["Tab", "背包键"], ["Esc 设置", "暂停键设置"],
	["Esc", "返回按钮"], ["Enter", "轻触屏幕"], ["Q 切", "换枪键切"], ["[Q]", "[换枪]"],
	["[R]", "[重新开始]"], ["按 R", "打开暂停菜单重新开始"],
]


static func adapt(value: String, touch: Variant = null) -> String:
	var uses_touch: bool = OS.has_feature("mobile") if touch == null else bool(touch)
	if not uses_touch:
		return value
	for pair in TOUCH_PHRASES:
		value = value.replace(pair[0], pair[1])
	return value


static func apply_to_control(node: Variant) -> void:
	if not is_instance_valid(node) or not OS.has_feature("mobile"):
		return
	if node is Label or node is Button or node is RichTextLabel:
		node.text = adapt(node.text)
	if node is Control:
		node.tooltip_text = adapt(node.tooltip_text)
