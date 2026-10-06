extends SceneTree
## Real map replay of a post-reload objective recovery. No ENet or model worker.
## Diagnostic only: captured position collides with objective geometry, but
## neutral replay of unchanged production recovers in about2.6s. This does NOT
## reproduce or prove a fix for the20s live-match stall. Optional --baseline=
## logs the preserved production replay too; --guards adds enclosure checks.
const START := Vector3(-11.54971, .04923, 5.797735)
const HILL := Vector3(0, .09, 0) / .31
const DT := 1.0 / 60.0
var failures: Array[String] = []
var map: Node3D
var scene: PackedScene
var run_guards := false
var baseline_path := ""
var initial_strafe := 1.0
var initial_stance := 0.0

func _init() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--guards": run_guards = true
		if argument.begins_with("--side="): initial_strafe = clampf(float(argument.trim_prefix("--side=")), -1, 1)
		if argument.begins_with("--stance="): initial_stance = maxf(0, float(argument.trim_prefix("--stance=")))
		if argument.begins_with("--baseline="): baseline_path = argument.trim_prefix("--baseline=")
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1.0
	map = Node3D.new()
	root.add_child(map)
	var arena := (load("res://art/maps/garden_circuit/GardenCircuit.glb") as PackedScene).instantiate() as Node3D
	arena.scale = Vector3.ONE / .31
	map.add_child(arena)
	# Invoke the genuine production builder including the smooth hill apron and
	# separate layer2 bullet art; do not substitute raw decorative floor meshes.
	var collision_builder: Node3D = load("res://scenes/levels/garden/garden_circuit.gd").new()
	collision_builder.call("_add_collision", arena)
	collision_builder.free()
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(32, .20, 44) / .31
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0, -.085, 0) / .31
	map.add_child(floor_body)
	scene = load("res://scenes/bots/duel_bot.tscn")
	await physics_frame
	if not baseline_path.is_empty():
		check(FileAccess.file_exists(baseline_path), "Explicit preserved production baseline source exists")
		if FileAccess.file_exists(baseline_path):
			var baseline := GDScript.new()
			baseline.source_code = FileAccess.get_file_as_string(baseline_path).replace("class_name DuelBot\n", "")
			check(baseline.reload() == OK, "Preserved baseline compiles without modifying production")
			if baseline.is_valid():
				print("RECOVERY_PRESERVED_DIAGNOSTIC ", JSON.stringify(await replay(baseline)))
	var result := await replay(null)
	print("RECOVERY_DIAGNOSTIC ", JSON.stringify(result))
	check(bool(result.initial_probe.blocked) or int(result.wall_contact_ticks) > 0, "Captured position has an actual blocking collider")
	check(float(result.minimum_y) > -.15, "Diagnostic remains supported by real map collision")
	if run_guards: await collision_guard_trial()
	map.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: collision replay diagnostic; does not reproduce or resolve the prolonged live stall")
	quit(0 if failures.is_empty() else 1)

func replay(script_override: GDScript) -> Dictionary:
	var bot: CharacterBody3D = scene.instantiate()
	if script_override != null: bot.set_script(script_override)
	bot.position = START
	map.add_child(bot)
	bot.set_physics_process(false)
	bot.set("team_id", 1)
	bot.set("movement_enabled", true)
	bot.call("set_difficulty", 1)
	bot.call("configure_combatants", [bot] as Array[Node3D], 2)
	bot.call("configure_objective", HILL, map)
	bot.call("set_tactical_context", 1, false)
	bot.call("set_target", null)
	# Reconstruct the original direct entry from the Cyan spawn. Rebuilding from
	# the displaced body would erase the actual current waypoint being diagnosed.
	var lane := -7.15 / .31
	var route: Array[Vector3] = [Vector3(lane, 0, 19.26 / .31), Vector3(lane, 0, 4.5 / .31), Vector3(0, 0, 4.5 / .31), HILL + Vector3(2.1, 0, 0)]
	bot.set("_objective_route", route)
	bot.set("_objective_index", 3)
	bot.set("route_variant", 0)
	bot.set("reloading", false)
	bot.set("_has_cover", false)
	bot.get("_random").seed = 255
	bot.set("_strafe_direction", initial_strafe)
	bot.set("_stance_remaining", initial_stance)
	await physics_frame
	var goal := route[3]
	var result := {"source_sha256": bot.get_script().source_code.sha256_text(), "start": str(START), "goal": str(goal), "initial_distance": flat_distance(bot.position, goal), "initial_probe": probe(bot, goal), "distance_at_8s": -1.0, "first_grounded_hill": -1.0, "grounded_hill_seconds": 0.0, "wall_contact_ticks": 0, "static_wall_ticks": 0, "recovery_ticks": 0, "travel_distance": 0.0, "minimum_y": START.y, "trace": []}
	for tick in 900:
		var previous := bot.position
		bot.call("_physics_process", DT)
		await physics_frame
		result.travel_distance += bot.position.distance_to(previous)
		result.minimum_y = minf(float(result.minimum_y), bot.position.y)
		var wall := false
		var static_wall := false
		for index in bot.get_slide_collision_count():
			var collision := bot.get_slide_collision(index)
			if collision.get_normal().dot(Vector3.UP) < cos(bot.floor_max_angle):
				wall = true
				static_wall = static_wall or collision.get_collider() is StaticBody3D
		if wall: result.wall_contact_ticks += 1
		if static_wall: result.static_wall_ticks += 1
		if float(bot.get("_advance_commit_remaining")) > 0.0 or float(bot.get("_objective_detour")) > 0.0: result.recovery_ticks += 1
		var grounded_hill := flat_distance(bot.position, HILL) <= 1.8 / .31 and absf(bot.position.y - HILL.y) <= .45 and bot.is_on_floor()
		if grounded_hill:
			if float(result.first_grounded_hill) < 0.0: result.first_grounded_hill = float(tick + 1) * DT
			result.grounded_hill_seconds += DT
		if tick == 479: result.distance_at_8s = flat_distance(bot.position, goal)
		if tick % 60 == 59:
			result.trace.append({"time": float(tick + 1) * DT, "position": str(bot.position), "goal_distance": flat_distance(bot.position, goal), "wall": wall, "advance_commit": bot.get("_advance_commit_remaining"), "detour": bot.get("_objective_detour"), "probe": probe(bot, goal)})
	result["end_distance"] = flat_distance(bot.position, goal)
	result["end_position"] = str(bot.position)
	bot.queue_free()
	await process_frame
	return result

func flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func probe(bot: CharacterBody3D, goal: Vector3) -> Dictionary:
	var offset := goal - bot.position
	offset.y = 0
	var motion := offset.normalized() * .9
	var contact := KinematicCollision3D.new()
	var blocked := bot.test_move(bot.global_transform, motion, contact)
	var collider := ""
	var normal := ""
	if blocked:
		var body := contact.get_collider() as Node
		collider = str(body.get_path()) if body != null else "non-node"
		normal = str(contact.get_normal())
	return {"blocked": blocked, "collider": collider, "normal": normal, "left_clear": not bot.test_move(bot.global_transform, motion.rotated(Vector3.UP, .85)), "right_clear": not bot.test_move(bot.global_transform, motion.rotated(Vector3.UP, -.85))}

func solid(parent: Node3D, size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at
	parent.add_child(body)

func collision_guard_trial() -> void:
	# No free direction exists here. Recovery may choose a new local heading,
	# but must never bypass tall walls or their ceiling to reach an outside goal.
	var cell := Node3D.new()
	cell.position = Vector3(200, 0, 200)
	root.add_child(cell)
	solid(cell, Vector3(6, 1, 6), Vector3(0, -.5, 0))
	for side in [-1, 1]:
		solid(cell, Vector3(.4, 6, 4.4), Vector3(side * 2, 3, 0))
		solid(cell, Vector3(4.4, 6, .4), Vector3(0, 3, side * 2))
	solid(cell, Vector3(4.4, .4, 4.4), Vector3(0, 2.4, 0))
	var bot := scene.instantiate() as DuelBot
	cell.add_child(bot)
	bot.set_physics_process(false)
	bot.position = Vector3(0, .02, 0)
	bot.movement_enabled = true
	bot.configure_combatants([bot], 2)
	bot.set_difficulty(1)
	bot.configure_objective(cell.global_position + Vector3(10, 0, 0), cell)
	bot._objective_route = [cell.global_position + Vector3(10, 0, 0)]
	bot._objective_index = 0
	var wall_ticks := 0
	var recovered := false
	for tick in 300:
		bot._physics_process(DT)
		await physics_frame
		if bot._has_wall_contact(): wall_ticks += 1
		recovered = recovered or bot._advance_commit_remaining > 0.0 or bot._objective_detour > 0.0
		check(absf(bot.position.x) < 1.65 and absf(bot.position.z) < 1.65 and bot.position.y > -.05 and bot.position.y < .2, "Recovery cannot escape enclosing walls/floor/ceiling at tick%s" % tick)
	check(recovered and bot.test_move(bot.global_transform, Vector3(3, 0, 0)), "Safety trial exercises recovery with an actually capsule-blocked exit")
	print("ENCLOSURE_GUARD recovered=", recovered, " sampledwallticks=", wall_ticks, " final=", bot.position)
	cell.queue_free()
	await process_frame
