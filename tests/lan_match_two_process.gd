extends SceneTree
## Actual arena + actual ENet processes, synchronized via a test-only RPC channel.
var session: Node
var channel: Node
var manager: Node
var app: Node
var acknowledgements: Dictionary = {}
var client_id := 0
var hit_confirmations := 0
var expected_actors := 4

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	session = root.get_node("LanSession")
	channel = preload("res://tests/lan_match_test_channel.gd").new()
	channel.name = "LanMatchTestChannel"
	root.add_child(channel)
	channel.acknowledgement_received.connect(func(command: String, result: Dictionary): acknowledgements[command] = result)
	channel.command_received.connect(_client_command)
	session.shot_result_received.connect(func(hit: bool): hit_confirmations += 1 if hit else 0)
	app = load("res://scenes/main/lan_main.tscn").instantiate()
	root.add_child(app)
	var role := OS.get_cmdline_user_args()[0]
	if OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "3v3":
		expected_actors = 6
	if role == "host":
		assert(session.host_lobby("Host") == OK)
		await _host_run()
	else:
		assert(session.join_lobby("127.0.0.1", "Partner") == OK)
		await _until(func(): return session.roster.size() == 2)
		session.choose_team(1)
		session.set_ready(true)
		await create_timer(14.0).timeout
		assert(false, "Host must finish commands before deadline")

func _host_run() -> void:
	await _until(func(): return session.roster.size() == 2)
	await _until(func(): return session.team_count(1) == 2 and session.roster[1].ready)
	client_id = int(session.roster[1].peer_id)
	session.add_bot(2)
	session.add_bot(2)
	if expected_actors == 6:
		session.add_bot(1)
		session.add_bot(2)
	session.set_ready(true)
	session.start_match()
	await create_timer(0.25).timeout
	manager = app.arena.get_node("DuelManager")
	assert(manager.actors.size() == expected_actors)
	manager.set_bots_frozen(true)
	manager.player.set_physics_process(false)
	manager.respawn_delay = 0.5
	await _command("check_roster", {})
	assert(acknowledgements.check_roster.actors == expected_actors)
	var remote_id := "peer_%s" % client_id
	var remote: CharacterBody3D = manager.actors[remote_id]
	var enemy: CharacterBody3D = manager.actors["bot_1"]
	var floor_y: float = manager.point_position.y + 0.08
	var location := Vector3(0, floor_y, 3)
	remote.global_position = location
	manager.player.global_position = location + Vector3(0, 0, -3)
	enemy.global_position = location + Vector3(5, 0, -3)
	manager.actors["bot_2"].global_position = location + Vector3(-5, 0, -3)
	session.reset_peer_pose(client_id, location)
	await _command("friendly_shot", {"position": location})
	assert(manager.player.current_health == 100.0, "Teammate shot cannot damage host")
	assert(int(session._magazines[client_id].ammo) == 11, "Friendly shot was accepted by server but caused no damage")
	manager.player.global_position = location + Vector3(5, 0, -3)
	enemy.global_position = location + Vector3(0, 0, -3)
	await physics_frame
	await physics_frame
	await _command("enemy_shot", {})
	assert(enemy.current_health == 78.0, "Client shot must damage host-authoritative enemy")
	assert(acknowledgements.enemy_shot.hits == 1, "Client must receive hit marker")
	assert(acknowledgements.enemy_shot.health == 78.0, "Enemy health must replicate")
	remote.apply_damage(22.0, manager.player.global_position)
	await _command("health_check", {"health": 78.0})
	remote.apply_damage(100.0, manager.player.global_position)
	await _command("respawn_check", {})
	assert(remote.is_alive and remote.current_health == 100.0, "Host respawns remote human")
	assert(int(manager.spawn_generations[remote_id]) == 1)
	manager.restart_match()
	await _command("restart_check", {})
	assert(acknowledgements.restart_check.generation == 2)
	assert(acknowledgements.restart_check.round == 1)
	session.return_to_lobby()
	await _command("lobby_check", {})
	assert(not session.in_match)
	await _command("disconnect", {})
	await _until(func(): return session.roster.size() == expected_actors - 1)
	assert(session.is_host(), "Host room survives client disconnect")
	await _until(func(): return session.roster.size() == expected_actors)
	for entry in session.roster:
		if not entry.bot and int(entry.peer_id) != 1:
			client_id = int(entry.peer_id)
	channel.rpc_id(client_id, "command", "host_disconnect", {})
	await create_timer(0.1).timeout
	session.leave_lobby()
	await create_timer(0.3).timeout
	print("LAN_MATCH_PASS host: %sv%s, team immunity, client damage/hit marker, snapshots, respawn, restart, lobby and disconnect" % [expected_actors / 2, expected_actors / 2])
	session.leave_lobby()
	quit(0)

func _command(name: String, arguments: Dictionary) -> void:
	channel.rpc_id(client_id, "command", name, arguments)
	await _until(func(): return acknowledgements.has(name), 3.0)

func _client_command(name: String, arguments: Dictionary) -> void:
	var result := {}
	if name not in ["lobby_check", "disconnect", "host_disconnect"]:
		manager = app.arena.get_node("DuelManager")
	match name:
		"check_roster":
			manager.player.set_physics_process(false)
			result.actors = manager.actors.size()
		"friendly_shot":
			manager.player.global_position = arguments.position
			manager.player.rotation.y = 0.0
			manager.player.camera_pivot.rotation.x = 0.0
			session.send_local_pose(arguments.position, 0.0, 0.0)
			await create_timer(0.12).timeout
			session.request_shot(manager.player.camera.global_position, Vector3.FORWARD)
			await create_timer(0.28).timeout
		"enemy_shot":
			session.request_shot(manager.player.camera.global_position, Vector3.FORWARD)
			await _until(func(): return hit_confirmations == 1 and manager.actors["bot_1"].current_health == 78.0, 2.0)
			result.hits = hit_confirmations
			result.health = manager.actors["bot_1"].current_health
		"health_check":
			await create_timer(0.15).timeout
			assert(manager.player.current_health == arguments.health, "Host damage replicates to client")
		"respawn_check":
			await create_timer(0.18).timeout
			assert(not manager.player.is_alive, "Host death replicates to client")
			await create_timer(0.5).timeout
			assert(manager.player.is_alive and manager.player.current_health == 100.0, "Respawn heals client")
			manager.player.set_physics_process(false)
		"restart_check":
			await create_timer(0.2).timeout
			result.generation = int(manager.spawn_generations[manager.local_id])
			result.round = int(manager._round_generation)
		"lobby_check":
			await create_timer(0.15).timeout
			assert(not session.in_match and app.arena == null and app.lobby.visible, "Both return to lobby")
		"disconnect":
			channel.rpc_id(1, "acknowledge", name, result)
			await create_timer(0.1).timeout
			session.leave_lobby()
			session.lobby_returned.emit()
			await create_timer(0.3).timeout
			assert(session.join_lobby("127.0.0.1", "Partner") == OK)
			return
		"host_disconnect":
			await _until(func(): return not session.connected)
			assert(app.arena == null and app.lobby.visible, "Host disconnect returns client to lobby")
			print("LAN_MATCH_PASS client: reconnect and host disconnect")
			quit(0)
			return
	channel.rpc_id(1, "acknowledge", name, result)

func _until(condition: Callable, timeout: float = 5.0) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await create_timer(0.02).timeout
	assert(condition.call(), "Timed out waiting for LAN test state")
