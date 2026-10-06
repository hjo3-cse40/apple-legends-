extends SceneTree
## Real host/client ENet 3v3 with the preloaded local Laya worker on the host.
## Run only when ENet27777 is free: python3 tests/run_lan_tests.py tactical_decision_lan_two_process.gd
var session: Node
var channel: Node
var app: Node
var manager: TeamMatchManager
var acknowledgements: Dictionary = {}
var client_id := 0
var snapshots := 0

func _initialize() -> void: call_deferred("run")

func run() -> void:
	session = root.get_node("LanSession")
	channel = preload("res://tests/lan_match_test_channel.gd").new()
	channel.name = "LanMatchTestChannel"
	root.add_child(channel)
	channel.acknowledgement_received.connect(func(command: String, result: Dictionary): acknowledgements[command] = result)
	channel.command_received.connect(client_command)
	session.world_snapshot_received.connect(func(_snapshot: Dictionary): snapshots += 1)
	app = load("res://scenes/main/lan_main.tscn").instantiate()
	root.add_child(app)
	if OS.get_cmdline_user_args()[0] == "host":
		assert(session.host_lobby("Laya LAN host") == OK)
		await host_run()
	else:
		assert(session.join_lobby("127.0.0.1", "Laya LAN partner") == OK)
		await until(func(): return session.roster.size() == 2)
		session.choose_team(1)
		session.set_ready(true)
		await create_timer(15.0).timeout
		assert(false, "Host must finish focused Laya LAN checks")

func host_run() -> void:
	await until(func(): return session.roster.size() == 2 and session.team_count(1) == 2 and session.roster[1].ready)
	client_id = int(session.roster[1].peer_id)
	for team in [1, 2, 2, 2]: session.add_bot(team)
	session.set_ready(true)
	session.start_match()
	await until(func(): return is_instance_valid(app.arena))
	manager = app.arena.get_node("DuelManager")
	assert(manager.actors.size() == 6)
	manager.player.set_physics_process(false)
	manager.player.weapon.set_physics_process(false)
	manager.set_tactical_mode(TacticalDecisionClient.Mode.ENABLED)
	await command("observe", {})
	var metrics := manager.tactical_decisions.get_metrics()
	assert(metrics.worker_ready and metrics.completed > 0 and metrics.applied > 0, "Real worker completes and applies host bot decisions")
	assert(manager.tactical_decisions.mode == TacticalDecisionClient.Mode.ENABLED, "Joining client cannot change host tactical mode")
	var observed: Dictionary = acknowledgements.observe
	assert(observed.actors == 6 and observed.snapshots > 10 and observed.bot_movement > 0.5, "Six actor snapshots and bot movement replicate")
	assert(observed.mode == TacticalDecisionClient.Mode.ENABLED and observed.status_seen, "Joining client observes host mode and real-worker status")
	assert(observed.requests == 0 and observed.client_mode == TacticalDecisionClient.Mode.LOCAL and not observed.worker_ready, "Joining client never requests model inference")
	var remote_id := "peer_%s" % client_id
	var remote: CharacterBody3D = manager.actors[remote_id]
	remote.global_position = Vector3(0, 40, 0)
	session.reset_peer_pose(client_id, remote.global_position, int(manager.spawn_generations[remote_id]))
	await command("move", {})
	assert(remote.global_position.x > 2.0, "Host still receives joining player movement while model decisions run")
	assert(float(acknowledgements.move.rewind) < 0.04, "Worker inference does not rewind joining movement")
	assert(manager.tactical_decisions.metrics.applied >= metrics.applied, "Host planner remains operational during movement")
	print("TACTICAL_LAN_PASS host: actual3v3 worker completed%d/applied%d, joining requests0, authority/status/snapshots/bot movement and human movement" % [metrics.completed, metrics.applied])
	await command("finish", {})
	session.leave_lobby()
	quit(0)

func command(name: String, args: Dictionary) -> void:
	channel.rpc_id(client_id, "command", name, args)
	await until(func(): return acknowledgements.has(name), 10.0)

func client_command(name: String, _args: Dictionary) -> void:
	if name == "finish":
		channel.rpc_id(1, "acknowledge", name, {})
		await create_timer(0.1).timeout
		print("TACTICAL_LAN_PASS client: observer-only model status and zero inference requests")
		session.leave_lobby()
		quit(0)
		return
	await until(func(): return is_instance_valid(app.arena))
	manager = app.arena.get_node("DuelManager")
	manager.player.set_physics_process(false)
	manager.player.weapon.set_physics_process(false)
	var result := {}
	if name == "observe":
		await until(func(): return manager.host_tactical_mode == TacticalDecisionClient.Mode.ENABLED)
		manager.set_tactical_mode(TacticalDecisionClient.Mode.LOCAL)
		manager.dev_action("tactical_mode", TacticalDecisionClient.Mode.LOCAL)
		var origins := {}
		for id in manager.actors:
			if str(id).begins_with("bot_"): origins[id] = manager.actors[id].global_position
		var saw_status := false
		var maximum_motion := 0.0
		var deadline := Time.get_ticks_msec() + 7000
		while Time.get_ticks_msec() < deadline:
			await create_timer(0.05).timeout
			saw_status = saw_status or manager.host_tactical_status.begins_with("Laya enabled:")
			for id in origins: maximum_motion = maxf(maximum_motion, manager.actors[id].global_position.distance_to(origins[id]))
		var client: TacticalDecisionClient = manager.tactical_decisions
		result = {"actors": manager.actors.size(), "snapshots": snapshots, "bot_movement": maximum_motion, "mode": manager.host_tactical_mode, "status_seen": saw_status, "requests": client.metrics.requested, "client_mode": client.mode, "worker_ready": client.worker_ready}
	elif name == "move":
		manager.player.global_position = Vector3(0, 40, 0)
		# This test teleport is out of band; discard pre-teleport samples before
		# measuring normal acknowledgement correction during scripted movement.
		session.set_local_generation(session._local_generation)
		var expected := manager.player.global_position
		var rewind := 0.0
		for tick in 60:
			await physics_frame
			expected.x += 3.0 / 60.0
			manager.player.global_position.x += 3.0 / 60.0
			rewind = maxf(rewind, manager.player.global_position.distance_to(expected))
		await create_timer(0.2).timeout
		result.rewind = maxf(rewind, manager.player.global_position.distance_to(expected))
		assert(manager.tactical_decisions.metrics.requested == 0, "Joining player remains inference-free throughout movement")
	channel.rpc_id(1, "acknowledge", name, result)

func until(condition: Callable, timeout: float = 5.0) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while not condition.call() and Time.get_ticks_msec() < deadline: await create_timer(0.02).timeout
	assert(condition.call(), "Timed out waiting for tactical LAN state")
