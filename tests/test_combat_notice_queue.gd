@tool
extends McpTestSuite


func suite_name() -> String:
	return "combat_notice_queue"


func test_priority_order_and_three_item_budget() -> void:
	var queue := track(CombatNoticeQueue.new()) as CombatNoticeQueue
	queue.tutorial_text = ""
	queue.max_visible = 3
	queue.push_notice(CombatNotice.new(&"low", "低", Color.WHITE, CombatNotice.Priority.LOW))
	queue.push_notice(CombatNotice.new(&"normal", "中", Color.WHITE, CombatNotice.Priority.NORMAL))
	queue.push_notice(CombatNotice.new(&"high", "高", Color.WHITE, CombatNotice.Priority.HIGH))
	queue.push_notice(CombatNotice.new(&"new_low", "新低", Color.WHITE, CombatNotice.Priority.LOW))
	var notices := queue.get_visible_notices()
	assert_eq(notices.size(), 3)
	assert_eq(notices[0]["id"], &"high")
	assert_eq(notices[1]["id"], &"normal")
	assert_eq(notices[2]["id"], &"new_low")


func test_matching_notice_merges_inside_window() -> void:
	var queue := track(CombatNoticeQueue.new()) as CombatNoticeQueue
	queue.tutorial_text = ""
	queue.push_notice(CombatNotice.new(&"pickup", "获得零件", Color.WHITE, CombatNotice.Priority.LOW, 0.75))
	queue._process(0.5)
	queue.push_notice(CombatNotice.new(&"pickup", "获得零件", Color.WHITE, CombatNotice.Priority.LOW, 0.75))
	var notices := queue.get_visible_notices()
	assert_eq(notices.size(), 1)
	assert_eq(notices[0]["count"], 2)
	assert_eq(notices[0]["text"], "获得零件 ×2")


func test_same_category_with_different_text_does_not_merge() -> void:
	var queue := track(CombatNoticeQueue.new()) as CombatNoticeQueue
	queue.tutorial_text = ""
	queue.push_notice(CombatNotice.new(&"full", "背包已满", Color.WHITE, CombatNotice.Priority.NORMAL, 0.75))
	queue.push_notice(CombatNotice.new(&"full", "战斗中不能换装", Color.WHITE, CombatNotice.Priority.NORMAL, 0.75))
	assert_eq(queue.get_visible_notices().size(), 2)


func test_real_notice_replaces_tutorial_but_legacy_stays_compatible() -> void:
	var queue := track(CombatNoticeQueue.new()) as CombatNoticeQueue
	queue.tutorial_text = "教学"
	queue._ready()
	queue.push_legacy("旧接口消息", Color.CYAN)
	var notices := queue.get_visible_notices()
	assert_eq(notices.size(), 1)
	assert_eq(notices[0]["text"], "旧接口消息")
	assert_eq(notices[0]["priority"], CombatNotice.Priority.NORMAL)
