extends SceneTree
## Run two real OS processes: -- host / -- client. No mocked RPCs.
var session: Node
var role := "host"
var started := false
var got_snapshot := false
var poses := 0
var shots := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	role = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "host"
	session = root.get_node("LanSession")
	session.match_started.connect(_started)
	session.world_snapshot_received.connect(_snapshot)
	session.peer_pose_received.connect(func(_id: int, _pose: Dictionary): poses += 1)
	session.shot_requested.connect(func(_id: int, _origin: Vector3, _direction: Vector3, _views: Dictionary): shots += 1)
	if role == "host":
		assert(session.host_lobby("Sam") == OK)
	else:
		assert(session.join_lobby("127.0.0.1", "Partner") == OK)
	var deadline := Time.get_ticks_msec() + 12000
	while session.roster.size() != 2 and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	assert(session.roster.size() == 2, "Handshake must replicate two humans")
	if role == "host":
		await create_timer(0.25).timeout
		assert(session.team_count(1) == 2, "Client selected host team")
		session.add_bot(2)
		session.add_bot(2)
		assert(session.roster.size() == 4)
		session.fill_bots()
		assert(session.team_count(1) == 3 and session.team_count(2) == 3)
		session.add_bot(2)
		assert(session.roster.size() == 6, "Team limit must hold")
		session.set_ready(true)
		await create_timer(0.25).timeout
		session.start_match()
	else:
		session.choose_team(1)
		session.set_ready(true)
	while not started and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	assert(started, "Host start must arrive")
	if role == "host":
		session.fill_bots() # Regression: must not spin while in a match.
		session.broadcast_world({"tick": 123, "health": 78.0})
		await create_timer(0.8).timeout
		assert(poses >= 1, "Client position intent arrives")
		assert(shots == 1, "Server rejects rapid duplicated shots")
		session.return_to_lobby()
		await create_timer(0.4).timeout
		assert(not session.in_match)
	else:
		session.send_local_pose(Vector3(1, 0, 2), 0.3, 0.1)
		await create_timer(0.1).timeout
		session.request_shot(Vector3(1, 1.62, 2), Vector3.FORWARD)
		session.request_shot(Vector3(1, 1.62, 2), Vector3.FORWARD)
		await create_timer(1.0).timeout
		assert(got_snapshot, "Host world snapshot arrives")
		assert(not session.in_match, "Return to lobby replicates")
	print("LAN_SESSION_PASS ", role)
	session.leave_lobby()
	quit(0)

func _started(_players: Array) -> void:
	started = true

func _snapshot(snapshot: Dictionary) -> void:
	got_snapshot = snapshot.tick == 123
