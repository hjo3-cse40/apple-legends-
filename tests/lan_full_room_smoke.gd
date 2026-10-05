extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var session: Node = root.get_node("LanSession")
	var role := OS.get_cmdline_user_args()[0]
	if role == "host":
		assert(session.host_lobby("Host") == OK)
		session.fill_bots()
		assert(session.roster.size() == 6)
	else:
		assert(session.join_lobby("127.0.0.1", "Partner") == OK)
	var deadline := Time.get_ticks_msec() + 5000
	var human_count := 0
	while human_count < 2 and Time.get_ticks_msec() < deadline:
		human_count = 0
		for entry in session.roster:
			if not entry.bot:
				human_count += 1
		await create_timer(0.02).timeout
	assert(human_count == 2, "New human replaces a bot in the full room")
	assert(session.roster.size() == 6 and session.team_count(1) == 3 and session.team_count(2) == 3)
	var bots := 0
	for entry in session.roster:
		if entry.bot:
			bots += 1
		else:
			assert(not entry.ready)
	assert(bots == 4)
	if role == "host":
		await create_timer(0.3).timeout
	print("LAN_FULL_ROOM_PASS ", role)
	session.leave_lobby()
	quit(0)
