extends SceneTree

var failures := 0
var started: Array[Dictionary] = []
var connections := 0
var collapsed_count := 0


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func run() -> void:
	var comms := CombatCommsController.new()
	root.add_child(comms)
	comms.message_started.connect(func(entry: Dictionary, connected: bool) -> void:
		started.append(entry)
		connections += int(connected)
	)
	comms.collapsed.connect(func() -> void: collapsed_count += 1)
	comms.push_message("普通战术提示", CombatCommsController.Priority.NORMAL, &"legendary_master", "相山")
	comms.push_message("下一条普通提示", CombatCommsController.Priority.NORMAL, &"legendary_master", "相山")
	check(started.size() == 1 and connections == 1, "first message expands and rings once while normal follow-up waits")
	comms.push_message("接管执行", CombatCommsController.Priority.CRITICAL, &"legendary_master", "相山")
	check(started.size() == 2 and connections == 1 and started[-1].text == "接管执行", "critical takeover interrupts without replaying the connection sound")
	for _index in 5:
		comms._process(1.0)
	check(started.size() == 3 and started[-1].text == "下一条普通提示", "one pending normal message resumes after the interrupt")
	for _index in 5:
		comms._process(1.0)
	check(collapsed_count == 1 and not comms.is_expanded(), "communications collapse after the adaptive display window")
	check(comms.get_history().size() == 3, "displayed communications are retained for the pause menu")
	comms.push_message("这是一条超过二十八个汉字的通讯内容，需要自动拆分而不是塞进第三行继续显示。", CombatCommsController.Priority.NORMAL)
	for entry in comms.get_history():
		check(String(entry.text).length() <= CombatCommsController.MAX_LINE_CHARACTERS, "communication chunks stay within the two-line budget")
	comms.queue_free()
	await process_frame
	print("Combat comms failures: ", failures)
	quit(0 if failures == 0 else 1)
