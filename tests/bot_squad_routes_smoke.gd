extends SceneTree

var failures: Array[String] = []
var difficulty: int = 1
var seed_value: int = 173

func _init() -> void: call_deferred("run")

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--difficulty="):
			difficulty = clampi(int(argument.trim_prefix("--difficulty=")), 0, 2)
		if argument.begins_with("--seed="):
			seed_value = int(argument.trim_prefix("--seed="))
	Engine.physics_ticks_per_second = 600
	Engine.time_scale = 10.0
	var map := Node3D.new()
	root.add_child(map)
	var arena := (load("res://art/maps/garden_circuit/GardenCircuit.glb") as PackedScene).instantiate() as Node3D
	arena.scale = Vector3.ONE / .31
	map.add_child(arena)
	add_collision(arena)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(32, .2, 44) / .31
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0, -.085, 0) / .31
	map.add_child(floor_body)
	var scene := load("res://scenes/bots/duel_bot.tscn") as PackedScene
	var actors: Array[Node3D] = []
	for team in [1, 2]:
		for slot in 3:
			var bot := scene.instantiate() as DuelBot
			bot.team_id = team
			bot.set_difficulty(difficulty)
			bot.hit_chance = 0.0
			bot.movement_enabled = true
			map.add_child(bot)
			var prefix := "CYAN" if team == 1 else "AMBER"
			var marker := arena.find_child(prefix + "_SPAWN_" + str(slot + 1) + "*", true, false) as Node3D
			bot.respawn_at(marker.global_transform)
			bot.configure_objective(Vector3(0, .09, 0) / .31, arena)
			actors.append(bot)
	var metrics: Array[Dictionary] = []
	for index in actors.size():
		var bot := actors[index] as DuelBot
		bot.configure_combatants(actors, index % 3)
		bot._random.seed = seed_value + index
		bot.respawn_at(bot._spawn_transform)
		metrics.append({"first_hill": -1.0, "hill_time": 0.0, "outside": 0.0, "longest_outside": 0.0, "outside_trace": ""})
	# A single endpoint cannot distinguish a legitimate short reload-cover visit
	# from a bot that never reaches or returns to the hill. Observe grounded
	# capture eligibility over time and retain the longest absence with its state.
	for tick in 2700:
		await physics_frame
		for index in actors.size():
			var bot := actors[index] as DuelBot
			var metric := metrics[index]
			var distance := Vector2(bot.position.x, bot.position.z).length()
			var capturing := distance <= 1.8 / .31 and absf(bot.position.y - .09 / .31) <= .45 and bot.is_on_floor()
			if capturing:
				if float(metric.first_hill) < 0: metric.first_hill = float(tick) / 60
				metric.hill_time += 1.0 / 60
				metric.outside = 0.0
			elif float(metric.first_hill) >= 0:
				metric.outside += 1.0 / 60
				if float(metric.outside) > float(metric.longest_outside):
					metric.longest_outside = metric.outside
					metric.outside_trace = "state%s reload%s cover%s retreat%.2f advance%.2f goalstall%.2f waypoint%s distance%.2f" % [bot.behavior_state, bot.reloading, bot._has_cover, bot._retreat_remaining, bot._advance_commit_remaining, bot._goal_stall_time, bot._objective_index, distance]
	for index in actors.size():
		var bot := actors[index] as DuelBot
		var metric := metrics[index]
		print("SQUAD_TRACE difficulty%s seed%s team%s slot%s variant%s firsthill%.2fs groundedhill%.2fs longestabsence%.2fs finaldistance%.2f %s" % [difficulty, seed_value, bot.team_id, bot._role_index, bot.route_variant, metric.first_hill, metric.hill_time, metric.longest_outside, Vector2(bot.position.x, bot.position.z).length(), metric.outside_trace])
		if float(metric.first_hill) < 0 or float(metric.first_hill) > 30.0: failures.append("Bot did not reach grounded hill in 30s: %s" % metric)
		if float(metric.hill_time) < 5.0: failures.append("Bot did not contribute at least5s of grounded hill occupancy: %s" % metric)
		if float(metric.longest_outside) > 8.0: failures.append("Bot failed bounded return after hill entry: %s" % metric)
	for bot in actors: bot.queue_free()
	map.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: six bots reach grounded hill, contribute capture time and bound cover/jump absences at difficulty %s" % difficulty)
	quit(0 if failures.is_empty() else 1)

func add_collision(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var extras: Dictionary = mesh.get_meta("extras", {})
		if bool(extras.get("collision_only", false)) or (not "Planting" in mesh.name and not "Signage" in mesh.name and not "Ground" in mesh.name):
			var shape := mesh.mesh.create_trimesh_shape()
			shape.backface_collision = true
			var body := StaticBody3D.new()
			var collider := CollisionShape3D.new()
			collider.shape = shape
			body.add_child(collider)
			mesh.add_child(body)
	for child in node.get_children():
		if not child is StaticBody3D: add_collision(child)
