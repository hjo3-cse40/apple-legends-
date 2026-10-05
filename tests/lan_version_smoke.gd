extends SceneTree
var session: Node
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	session = root.get_node("LanSession")
	var role := OS.get_cmdline_user_args()[0]
	if role == "host":
		assert(session.host_lobby("Host") == OK)
		await create_timer(2.0).timeout
		assert(session.roster.size() == 1, "Mismatched builds must not enter roster")
	else:
		session.multiplayer.connected_to_server.disconnect(session._on_connected)
		session.multiplayer.connected_to_server.connect(func(): session.rpc_id(1, "_hello", "old-build", "Partner"))
		assert(session.join_lobby("127.0.0.1", "Partner") == OK)
		await create_timer(1.0).timeout
		assert(not session.connected, "Version mismatch must leave client disconnected")
		assert("Different game version" in session.status, "Version rejection tells player how to update")
	print("LAN_VERSION_PASS ", role)
	session.leave_lobby()
	quit(0)
