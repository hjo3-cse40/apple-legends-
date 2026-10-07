extends SceneTree
## Real rifle dispatch, ENet transport, rendered targeting and host-owned health.
var session: Node
var channel: Node
var app: Node
var manager: TeamMatchManager
var client_id := 0
var acknowledgements: Dictionary = {}
var hit_count := 0
var moving := false
var moving_actor: Node3D
var speed := 12.0
var delayed_count := 0
var current_ray_control := false
func _initialize() -> void: call_deferred("run")
func run() -> void:
	current_ray_control = OS.get_cmdline_user_args().has("--current-ray-control")
	session = root.get_node("LanSession")
	channel = preload("res://tests/lan_match_test_channel.gd").new()
	channel.name = "HitTestChannel"
	root.add_child(channel)
	channel.acknowledgement_received.connect(func(command: String, result: Dictionary): acknowledgements[command] = result)
	channel.command_received.connect(client_command)
	session.shot_result_received.connect(func(hit: bool): hit_count += 1 if hit else 0)
	app = load("res://scenes/main/lan_main.tscn").instantiate()
	root.add_child(app)
	if OS.get_cmdline_user_args()[0] == "host":
		assert(session.host_lobby("Host") == OK)
		await host_run()
	else:
		assert(session.join_lobby("127.0.0.1", "Client") == OK)
		await until(func(): return session.roster.size() == 2)
		session.choose_team(2)
		session.set_ready(true)
		await create_timer(15).timeout
		assert(false, "host completes test")
func host_run() -> void:
	await until(func(): return session.roster.size() == 2 and session.roster[1].ready)
	client_id = int(session.roster[1].peer_id)
	session.add_bot(1)
	session.set_ready(true)
	session.start_match()
	await create_timer(0.2).timeout
	manager = app.arena.get_node("DuelManager")
	manager.set_bots_frozen(true)
	manager.player.set_physics_process(false)
	manager.player.health.maximum_health = 1000
	manager.player.health.current_health = 1000
	var remote_id := "peer_%d" % client_id
	var remote: RemoteActor = manager.actors[remote_id]
	remote.position = Vector3(0, 40, 10)
	session.reset_peer_pose(client_id, remote.position)
	var bot: DuelBot = manager.actors.bot_1
	bot.maximum_health = 1000
	bot.current_health = 1000
	bot.position = Vector3(20, 40, 0)
	manager.player.position = Vector3(-4, 40, 0)
	moving_actor = manager.player
	moving = true
	move_target()
	await command("moving_human", {"target": "peer_1"})
	moving = false
	await physics_frame
	assert(manager.player.current_health == (1000 if current_ray_control else 934), "three centered shots damage moving host human")
	assert(acknowledgements.moving_human.hits == (0 if current_ray_control else 3), "joining rifle receives all host-authoritative hit markers")
	assert(float(acknowledgements.moving_human.minimum_offset) > CombatHitbox.HEAD_RADIUS + 0.05, "rendered target differs from newest sample by more than the largest combat radius plus clearance")
	manager.player.position = Vector3(20, 40, 0)
	bot.position = Vector3(-4, 40, 0)
	moving_actor = bot
	moving = true
	move_target()
	await command("moving_bot", {"target": "bot_1"})
	moving = false
	await physics_frame
	assert(bot.current_health == (1000 if current_ray_control else 934), "same rendered targeting damages moving bot three times")
	assert(acknowledgements.moving_bot.hits == (0 if current_ray_control else 3), "bot/human network hit parity")
	manager.player.position = Vector3(0, 40, 0)
	bot.position = Vector3(20, 40, 0)
	await command("prepare_host_head", {})
	await physics_frame
	manager.player.camera.look_at(remote.position + Vector3(0.25, 1.8, 0), Vector3.UP)
	manager.player.weapon.request_fire()
	await physics_frame
	await physics_frame
	assert(remote.current_health == 78, "actual host rifle hits stationary visible human upper helmet")
	await command("host_head_result", {})
	await command("finish", {})
	print("LAN_HIT_REGISTRATION_CONTROL current-ray movinghits=", acknowledgements.moving_human.hits + acknowledgements.moving_bot.hits, "/6")
	print("LAN_HIT_REGISTRATION_PASS host: current-ray-control=", current_ray_control, "; joining movinghuman=", acknowledgements.moving_human.hits, "/3 movingbot=", acknowledgements.moving_bot.hits, "/3 at12units/s;80/100/120ms added snapshot delay; hosthelmet22damage")
	session.leave_lobby()
	quit(0)
func move_target() -> void:
	while moving:
		await physics_frame
		if not moving: break
		moving_actor.position.x += speed / 60.0
func command(name: String, arguments: Dictionary) -> void:
	acknowledgements.erase(name)
	channel.rpc_id(client_id, "command", name, arguments)
	await until(func(): return acknowledgements.has(name), 4)
func client_command(name: String, arguments: Dictionary) -> void:
	manager = app.arena.get_node("DuelManager")
	var result := {}
	match name:
		"moving_human", "moving_bot":
			manager.player.set_physics_process(false)
			if current_ray_control: manager.player.weapon.shot_dispatcher = session.request_shot
			manager.player.position = Vector3(0, 40, 10)
			manager.player.camera.rotation = Vector3.ZERO
			session.send_local_pose(manager.player.position, 0, 0)
			if name == "moving_human":
				session.world_snapshot_received.disconnect(manager._receive_world)
				session.world_snapshot_received.connect(delay_snapshot)
			await create_timer(0.45).timeout
			var before := hit_count
			var minimum_offset := INF
			var target: RemoteActor = manager.actors[arguments.target]
			for index in range(3):
				await create_timer(0.25).timeout
				minimum_offset = minf(minimum_offset, target.position.distance_to(target._target_position))
				manager.player.camera.look_at(target.position + Vector3.UP * 1.3, Vector3.UP)
				manager.player.weapon.request_fire()
				await physics_frame
			if current_ray_control:
				await create_timer(0.25).timeout
			else:
				await until(func(): return hit_count - before == 3)
			result.hits = hit_count - before
			result.minimum_offset = minimum_offset
			print("LAN_VISIBLE_AIM ", name, " hits=", result.hits, " minimum rendered/newest displacement=", minimum_offset)
		"prepare_host_head":
			session.world_snapshot_received.disconnect(delay_snapshot)
			session.world_snapshot_received.connect(manager._receive_world)
			manager.player.position = Vector3(0, 40, 10)
			session.send_local_pose(manager.player.position, 0, 0)
			await create_timer(0.2).timeout
		"host_head_result":
			await until(func(): return manager.player.current_health == 78)
			result.health = manager.player.current_health
		"finish":
			channel.rpc_id(1, "acknowledge", name, {})
			await create_timer(0.1).timeout
			print("LAN_HIT_REGISTRATION_CONTROL client current-ray=", current_ray_control, " hits=", hit_count)
			print("LAN_HIT_REGISTRATION_PASS client: hitmarkers=", hit_count, "; delayedworld samples=", delayed_count, "; incominghosthelmet health78")
			quit(0)
			return
	channel.rpc_id(1, "acknowledge", name, result)
func delay_snapshot(snapshot: Dictionary) -> void:
	delayed_count += 1
	await create_timer([0.08, 0.12, 0.10][delayed_count % 3]).timeout
	if is_instance_valid(manager): manager._receive_world(snapshot)
func until(condition: Callable, timeout: float = 4) -> void:
	var end := Time.get_ticks_msec() + int(timeout * 1000)
	while not condition.call() and Time.get_ticks_msec() < end: await create_timer(0.01).timeout
	assert(condition.call(), "timed out waiting for actual combat result")
