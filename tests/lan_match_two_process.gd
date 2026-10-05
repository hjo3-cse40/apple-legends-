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
var delayed_snapshots := 0
var stale_pose_accepted := false
var previous_match_world: Dictionary = {}
var previous_epoch := -1

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
	if OS.get_cmdline_user_args().size() > 1:
		if OS.get_cmdline_user_args()[1] == "3v3": expected_actors = 6
		if OS.get_cmdline_user_args()[1] == "1v1": expected_actors = 2
	if role == "host":
		assert(session.host_lobby("Host") == OK)
		await _host_run()
	else:
		assert(session.join_lobby("127.0.0.1", "Partner") == OK)
		await _until(func(): return session.roster.size() == 2)
		session.choose_team(2 if expected_actors == 2 else 1)
		session.set_ready(true)
		await create_timer(17.0).timeout
		assert(false, "Host must finish commands before deadline")

func _host_run() -> void:
	await _until(func(): return session.roster.size() == 2)
	await _until(func(): return session.team_count(1) == (1 if expected_actors == 2 else 2) and session.roster[1].ready)
	client_id = int(session.roster[1].peer_id)
	if expected_actors > 2:
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
	manager.dev_action("bot_difficulty", 2)
	manager.player.set_physics_process(false)
	manager.respawn_delay = 0.5
	await _command("check_roster", {})
	assert(acknowledgements.check_roster.actors == expected_actors)
	assert(acknowledgements.check_roster.difficulty == 2, "Host difficulty setting reaches joining client")
	var remote_id := "peer_%s" % client_id
	var remote: CharacterBody3D = manager.actors[remote_id]
	var enemy: CharacterBody3D = manager.actors["bot_1"] if expected_actors > 2 else manager.player
	# Real ENet movement plus delayed/uneven inbound snapshots. Twenty metres
	# per second exceeds the old 1.5m stale-position snap threshold at 120ms RTT.
	remote.global_position = Vector3(0, 40, 0)
	session.reset_peer_pose(client_id, remote.global_position)
	await _command("jitter_motion", {})
	assert(float(acknowledgements.jitter_motion.error) < 0.04, "Latency must not rewind locally controlled movement")
	var geometry := _movement_test_geometry()
	remote.global_position = Vector3(-3, 40.02, 0)
	session.reset_peer_pose(client_id, remote.global_position)
	await _command("grounded_step", {})
	assert(float(acknowledgements.grounded_step.error) < 0.1, "Joining client crosses low step without authority jitter")
	assert(remote.global_position.x > 2.0, "Host follows actual capsule across legal step")
	geometry.queue_free()
	session.peer_pose_received.connect(func(_peer: int, pose: Dictionary):
		if int(pose.get("sequence", 0)) in [999999, 999998]: stale_pose_accepted = true)
	var floor_y: float = manager.point_position.y + 0.08
	var location := Vector3(0, floor_y, 3)
	remote.global_position = location
	manager.player.global_position = location + Vector3(0, 0, -3)
	enemy.global_position = location + Vector3(5, 0, -3)
	if expected_actors > 2:
		manager.actors["bot_2"].global_position = location + Vector3(-5, 0, -3)
	session.reset_peer_pose(client_id, location)
	if expected_actors > 2:
		await _command("friendly_shot", {"position": location})
		assert(manager.player.current_health == 100.0, "Teammate shot cannot damage host")
		assert(int(session._magazines[client_id].ammo) == 11, "Friendly shot was accepted by server but caused no damage")
		manager.player.global_position = location + Vector3(5, 0, -3)
	enemy.global_position = location + Vector3(0, 0, -3)
	await physics_frame
	await physics_frame
	await _command("enemy_shot", {"position": location, "enemy": "bot_1" if expected_actors > 2 else "peer_1"})
	assert(enemy.current_health == 78.0, "Client shot must damage host-authoritative enemy")
	assert(acknowledgements.enemy_shot.hits == 1, "Client must receive hit marker")
	assert(acknowledgements.enemy_shot.health == 78.0, "Enemy health must replicate")
	remote.apply_damage(22.0, manager.player.global_position)
	await _command("health_check", {"health": 78.0})
	remote.apply_damage(100.0, manager.player.global_position)
	await _command("respawn_check", {})
	assert(remote.is_alive and remote.current_health == 100.0, "Host respawns remote human")
	assert(int(manager.spawn_generations[remote_id]) == 1)
	assert(not stale_pose_accepted, "Previous life pose rejected after respawn")
	await _command("stale_reload", {})
	assert(int(session._magazines[client_id].ammo) == 11 and int(session._magazines[client_id].reload_end) == 0, "Previous life/match reload cannot consume fresh reload state")
	manager.restart_match()
	await _command("restart_check", {})
	assert(acknowledgements.restart_check.generation == 2)
	assert(acknowledgements.restart_check.round == 1)
	session.return_to_lobby()
	await _command("lobby_check", {})
	assert(not session.in_match)
	await _command("ready_again", {})
	session.set_ready(true)
	session.start_match()
	await create_timer(0.25).timeout
	manager = app.arena.get_node("DuelManager")
	manager.set_bots_frozen(true)
	await _command("epoch_check", {})
	assert(not stale_pose_accepted, "Previous match movement cannot enter fresh round")
	assert(int(session._magazines[client_id].ammo) == 12, "Previous match shot cannot consume fresh ammo")
	session.return_to_lobby()
	await _command("lobby_check", {})
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
	acknowledgements.erase(name)
	channel.rpc_id(client_id, "command", name, arguments)
	await _until(func(): return acknowledgements.has(name), 3.0)

func _client_command(name: String, arguments: Dictionary) -> void:
	var result := {}
	if name not in ["lobby_check", "disconnect", "host_disconnect", "ready_again"]:
		manager = app.arena.get_node("DuelManager")
	match name:
		"ready_again":
			session.set_ready(true)
			await create_timer(0.1).timeout
		"epoch_check":
			assert(session._match_epoch != previous_epoch, "New match increments epoch")
			previous_match_world.actors[manager.local_id].health = 0.0
			previous_match_world.actors[manager.local_id].generation = 99
			previous_match_world.server_time = Time.get_ticks_msec() / 1000.0 + 10.0
			manager._receive_world(previous_match_world)
			assert(manager.player.is_alive and int(manager.spawn_generations[manager.local_id]) == 0, "Old-match buffered snapshot cannot kill or respawn new player")
			session.rpc_id(1, "_submit_pose", {"position": manager.player.global_position, "yaw": 0.0, "pitch": 0.0, "generation": 0, "sequence": 999998, "epoch": previous_epoch})
			session.rpc_id(1, "_submit_shot", manager.player.camera.global_position, Vector3.FORWARD, 0, previous_epoch)
			await create_timer(0.1).timeout
		"check_roster":
			previous_match_world = manager._world_snapshot()
			previous_epoch = session._match_epoch
			previous_match_world.epoch = previous_epoch
			manager.player.set_physics_process(false)
			result.actors = manager.actors.size()
			await _until(func(): return manager.bot_difficulty == 2)
			result.difficulty = manager.bot_difficulty
		"jitter_motion":
			manager.player.global_position = Vector3(0, 40, 0)
			session.set_local_generation(0)
			session.world_snapshot_received.disconnect(manager._receive_world)
			session.world_snapshot_received.connect(_delay_snapshot)
			var start: Vector3 = manager.player.global_position
			var expected := start
			var maximum_error := 0.0
			for tick in range(90):
				await physics_frame
				expected.x += 20.0 / 60.0
				manager.player.global_position.x += 20.0 / 60.0
				maximum_error = maxf(maximum_error, manager.player.global_position.distance_to(expected))
			await create_timer(0.2).timeout
			maximum_error = maxf(maximum_error, manager.player.global_position.distance_to(expected))
			session.world_snapshot_received.disconnect(_delay_snapshot)
			session.world_snapshot_received.connect(manager._receive_world)
			result.error = maximum_error
			print("LAN_JITTER_METRIC: client20m/s delayed100-140ms max rewind=%.6fm samples=%d" % [maximum_error, delayed_snapshots])
		"grounded_step":
			var geometry := _movement_test_geometry()
			manager.player.respawn_at(Transform3D(Basis.IDENTITY, Vector3(-3, 40.02, 0)))
			manager.player.set_physics_process(false)
			session.set_local_generation(0)
			var reference: FirstPersonPlayer = load("res://scenes/player/player.tscn").instantiate()
			app.arena.add_child(reference)
			reference.set_physics_process(false)
			reference.respawn_at(Transform3D(Basis.IDENTITY, Vector3(-3, 40.02, 4)))
			session.world_snapshot_received.disconnect(manager._receive_world)
			session.world_snapshot_received.connect(_delay_snapshot)
			var maximum_error := 0.0
			for tick in range(120):
				await physics_frame
				for actor in [manager.player, reference]:
					actor.velocity = Vector3(3, -0.5, 0)
					actor._try_step_up(Vector3(3.0 / 60.0, 0, 0))
					actor.move_and_slide()
				maximum_error = maxf(maximum_error, manager.player.global_position.distance_to(reference.global_position - Vector3(0, 0, 4)))
			await create_timer(0.2).timeout
			session.world_snapshot_received.disconnect(_delay_snapshot)
			session.world_snapshot_received.connect(manager._receive_world)
			result.error = maximum_error
			print("LAN_GROUNDED_METRIC: client.30m step delayed100-140ms maximum divergence=%.6fm" % maximum_error)
			reference.queue_free()
			geometry.queue_free()
		"friendly_shot":
			manager.player.global_position = arguments.position
			manager.player.rotation.y = 0.0
			manager.player.camera_pivot.rotation.x = 0.0
			session.send_local_pose(arguments.position, 0.0, 0.0)
			await create_timer(0.12).timeout
			session.request_shot(manager.player.camera.global_position, Vector3.FORWARD)
			await create_timer(0.28).timeout
		"enemy_shot":
			manager.player.global_position = arguments.position
			manager.player.rotation.y = 0.0
			manager.player.camera_pivot.rotation.x = 0.0
			session.send_local_pose(arguments.position, 0.0, 0.0)
			await create_timer(0.12).timeout
			session.request_shot(manager.player.camera.global_position, Vector3.FORWARD)
			await _until(func(): return hit_confirmations == 1 and manager.actors[arguments.enemy].current_health == 78.0, 2.0)
			result.hits = hit_confirmations
			result.health = manager.actors[arguments.enemy].current_health
		"health_check":
			await create_timer(0.15).timeout
			assert(manager.player.current_health == arguments.health, "Host damage replicates to client")
		"respawn_check":
			await create_timer(0.18).timeout
			assert(not manager.player.is_alive, "Host death replicates to client")
			await create_timer(0.5).timeout
			assert(manager.player.is_alive and manager.player.current_health == 100.0, "Respawn heals client")
			manager.player.set_physics_process(false)
			# Deliberately deliver a buffered packet from the previous life.
			session.rpc_id(1, "_submit_pose", {"position": manager.player.global_position + Vector3.RIGHT, "yaw": 0.0, "pitch": 0.0, "generation": 0, "sequence": 999999, "epoch": session._match_epoch})
			await create_timer(0.1).timeout
		"stale_reload":
			session.request_shot(manager.player.camera.global_position, Vector3.UP)
			await create_timer(0.1).timeout
			session.rpc_id(1, "_submit_reload", 0, session._match_epoch)
			session.rpc_id(1, "_submit_reload", 1, session._match_epoch - 1)
			await create_timer(0.1).timeout
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

func _delay_snapshot(snapshot: Dictionary) -> void:
	delayed_snapshots += 1
	# Repeatably emulate Wi-Fi/render scheduling delay, including reordered delivery.
	await create_timer([0.10, 0.14, 0.12][delayed_snapshots % 3]).timeout
	if is_instance_valid(manager):
		manager._receive_world(snapshot)

func _movement_test_geometry() -> Node3D:
	var geometry := Node3D.new()
	app.arena.add_child(geometry)
	for specification in [[Vector3(30, 1, 30), Vector3(0, 39.5, 0)], [Vector3(2, 0.3, 12), Vector3(0, 40.15, 0)]]:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = specification[0]
		shape.shape = box
		body.add_child(shape)
		geometry.add_child(body)
		body.position = specification[1]
	return geometry
