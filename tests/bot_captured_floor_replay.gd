extends SceneTree
## Exact268 floor-lock regression: preserved source stalls15s; grounded
## vertical velocity0 restores capsule movement with existing floor snapping.
## The267 moving replay did NOT reproduce the long stall. Exact unlogged
## history/engine caches remain unavailable; controlled reconstruction is logged.
const DT := 1.0 / 60.0
var snapshot_path := "res://tests/fixtures/bot_floor_267_268_capture.json"
var output_path := "res://work/recovery-267-replay.json"
var capture_second := 268.0
var one_history := true
var compare_baseline := true
var parent_script_path := "res://scenes/bots/duel_bot.gd"
var arm_name := "production_after"
var failures: Array[String] = []
var world: Node3D
var scene: PackedScene
var trace_script: GDScript
var captured: Dictionary
var results: Array[Dictionary] = []

func _init() -> void: call_deferred("run")
func vector(values: Array) -> Vector3: return Vector3(float(values[0]), float(values[1]), float(values[2]))
func flat_distance(a: Vector3, b: Vector3) -> float: return Vector2(a.x - b.x, a.z - b.z).length()
func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seconds="): capture_second = float(argument.trim_prefix("--seconds="))
		if argument == "--one-history": one_history = true
		if argument == "--all-histories": one_history = false
		if argument == "--no-baseline": compare_baseline = false
		if argument.begins_with("--snapshot="): snapshot_path = argument.trim_prefix("--snapshot=")
		if argument.begins_with("--output="): output_path = argument.trim_prefix("--output=")
	check(FileAccess.file_exists(snapshot_path), "Captured state file exists")
	if not failures.is_empty(): finish(); return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(snapshot_path))
	check(parsed is Dictionary and parsed.get("actors") is Array, "Snapshot contains recorded actors")
	if not failures.is_empty(): finish(); return
	for actor in parsed.actors:
		if actor.bot_id == "bot_1" and float(actor.seconds) == capture_second: captured = actor
	check(not captured.is_empty(), "Requested recorded bot1 pressure state exists")
	if not failures.is_empty(): finish(); return
	Engine.physics_ticks_per_second = 60
	Engine.time_scale = 1
	world = Node3D.new()
	root.add_child(world)
	var arena := (load("res://art/maps/garden_circuit/GardenCircuit.glb") as PackedScene).instantiate() as Node3D
	arena.scale = Vector3.ONE / .31
	world.add_child(arena)
	var builder: Node3D = load("res://scenes/levels/garden/garden_circuit.gd").new()
	builder.call("_add_collision", arena)
	builder.free()
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(32, .20, 44) / .31
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0, -.085, 0) / .31
	world.add_child(floor_body)
	scene = load("res://scenes/bots/duel_bot.tscn")
	await physics_frame
	for arm in (["preserved_before", "production_after"] if compare_baseline else ["production_after"]):
		arm_name = arm
		parent_script_path = "res://tests/fixtures/bot_floor_before_5519.gd" if arm == "preserved_before" else "res://scenes/bots/duel_bot.gd"
		# Observation-only override calls the actual complete controller source.
		trace_script = GDScript.new()
		trace_script.source_code = "extends \"" + parent_script_path + "\"\nvar measured_controller_velocity := Vector3.ZERO\nfunc _tactical_velocity(base_velocity: Vector3, delta: float) -> Vector3:\n\tmeasured_controller_velocity = super._tactical_velocity(base_velocity, delta)\n\treturn measured_controller_velocity\n"
		check(trace_script.reload() == OK, "Read-only instrumentation subclass compiles: " + arm)
		if not failures.is_empty(): finish(); return
		for history in (["restored_no_progress"] if one_history else ["fresh_progress", "restored_no_progress"]):
			for policy in [false, true]: results.append(await trial(history, policy))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path).get_base_dir())
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	check(file != null, "Diagnostic trace output opens")
	if file != null:
		file.store_string(JSON.stringify({"controlled_capture_regression": true, "source": snapshot_path, "unlogged": parsed.get("unlogged", []), "results": results}, "\t"))
		file.close()
	world.queue_free()
	await process_frame
	finish()

func trial(history: String, policy: bool) -> Dictionary:
	var bot := scene.instantiate() as DuelBot
	bot.set_script(trace_script)
	bot.position = vector(captured.position)
	world.add_child(bot)
	bot.set_physics_process(false)
	bot.team_id = 1
	bot.configure_combatants([bot], 0)
	bot.set_difficulty(1)
	bot.configure_objective(Vector3(0, .09, 0) / .31, world)
	bot.set_tactical_context(1, false)
	bot.set_target(null)
	# Warm floor cache without horizontal movement or advancing AI/RNG clocks.
	bot.movement_enabled = false
	bot.velocity = Vector3.ZERO
	for tick in 5:
		bot._update_movement(DT)
		await physics_frame
	var warm_position := bot.position
	var warm_grounded := bot.is_on_floor()
	bot.position = vector(captured.position)
	bot.velocity = vector(captured.velocity)
	bot.movement_enabled = true
	bot.current_health = float(captured.health)
	bot.ammo_in_magazine = int(captured.ammo)
	bot.reloading = bool(captured.reloading)
	bot._has_cover = bool(captured.has_cover)
	bot._cover_position = vector(captured.cover_goal)
	bot._cover_remaining = 0.0
	bot._objective_route.clear()
	for point in captured.route: bot._objective_route.append(vector(point))
	bot._objective_index = int(captured.waypoint_index)
	bot.route_variant = int(captured.route_variant)
	bot._strafe_direction = float(captured.strafe_side)
	bot._combat_bias = float(captured.combat_bias)
	bot._stance_remaining = float(captured.stance_remaining)
	bot._engagement_remaining = float(captured.engagement_remaining)
	bot._advance_commit_remaining = float(captured.advance_commit_remaining)
	bot._objective_detour = float(captured.objective_detour)
	bot._goal_stall_time = float(captured.goal_stall_time)
	bot._retreat_remaining = float(captured.retreat_remaining)
	bot._retreat_cooldown = float(captured.retreat_cooldown)
	bot._random.state = int(str(captured.rng_state))
	bot._objective_previous = bot.position
	bot._goal_best_distance = INF if history == "fresh_progress" else flat_distance(bot.position, vector(captured.waypoint_goal))
	bot._objective_stuck_time = 0.0 if history == "fresh_progress" else .79
	bot._jump_remaining = 1000.0 # no target exists; neutralizes an unlogged timer only
	bot.clear_tactical_policy()
	if policy:
		var request := bot.build_tactical_request()
		check(bot.apply_tactical_candidate("continue_objective", request), "Captured objective intent binds a real local goal")
		bot._policy_remaining = float(captured.policy_remaining)
	var result := {"arm": arm_name, "history": history, "policy": policy, "production_sha256": (load(parent_script_path) as GDScript).source_code.sha256_text(), "warm_grounded": warm_grounded, "warm_position": str(warm_position), "start_distance": flat_distance(bot.position, vector(captured.waypoint_goal)), "travel": 0.0, "longest_low_motion": 0.0, "distance_at_8s": -1.0, "frames": []}
	var low_motion := 0.0
	var grounded_frames := 0
	var first_goal := -1.0
	var minimum_y := bot.position.y
	var off_goal_stall := 0.0
	var maximum_off_goal_stall := 0.0
	var refresh_time := float(captured.policy_remaining)
	for tick in 900:
		var time := float(tick) * DT
		if policy and time >= refresh_time:
			var request := bot.build_tactical_request()
			check(bot.apply_tactical_candidate("continue_objective", request), "Objective refresh revalidates normal candidate guards")
			refresh_time += 2.0
		var previous := bot.position
		var incoming := bot.velocity
		bot._physics_process(DT)
		await physics_frame
		var displacement := bot.position.distance_to(previous)
		result.travel += displacement
		if bot.is_on_floor(): grounded_frames += 1
		minimum_y = minf(minimum_y, bot.position.y)
		var goal_distance := flat_distance(bot.position, vector(captured.waypoint_goal))
		if first_goal < 0 and goal_distance < .8: first_goal = float(tick + 1) * DT
		off_goal_stall = off_goal_stall + DT if goal_distance > .8 and displacement < .002 else 0.0
		maximum_off_goal_stall = maxf(maximum_off_goal_stall, off_goal_stall)
		low_motion = low_motion + DT if displacement < .002 else 0.0
		result.longest_low_motion = maxf(float(result.longest_low_motion), low_motion)
		var collisions: Array[Dictionary] = []
		for index in bot.get_slide_collision_count():
			var collision := bot.get_slide_collision(index)
			var collider := collision.get_collider() as Node
			var shape := collision.get_collider_shape()
			collisions.append({"collider": str(collider.get_path()) if collider != null else "non-node", "shape": str(shape), "normal": str(collision.get_normal()), "point": str(collision.get_position()), "travel": str(collision.get_travel()), "remainder": str(collision.get_remainder())})
		var controller: Vector3 = bot.get("measured_controller_velocity")
		var intended := controller.normalized() * bot._sprint_speed if bot.sprinting else controller
		result.frames.append({"seconds": float(tick + 1) * DT, "position": str(bot.position), "incoming_velocity": str(incoming), "controller_velocity": str(controller), "intended_velocity": str(intended), "actual_velocity": str(bot.velocity), "grounded": bot.is_on_floor(), "collisions": collisions, "waypoint_distance": flat_distance(bot.position, vector(captured.waypoint_goal)), "goal_stall": bot._goal_stall_time, "detour": bot._objective_detour, "advance_commit": bot._advance_commit_remaining, "policy_remaining": bot._policy_remaining, "rng_state": str(bot._random.state)})
		if tick == 479: result.distance_at_8s = flat_distance(bot.position, vector(captured.waypoint_goal))
	result["grounded_frames"] = grounded_frames
	result["minimum_y"] = minimum_y
	result["first_goal"] = first_goal
	result["maximum_off_goal_stall"] = maximum_off_goal_stall
	if capture_second == 268 and history == "restored_no_progress":
		if arm_name == "preserved_before":
			check(float(result.travel) < .01 and float(result.distance_at_8s) > 11, "Preserved baseline reproduces15s floor lock with/without policy")
		else:
			check(first_goal >= 0 and first_goal < 5 and maximum_off_goal_stall < 2, "Fixed bot escapes captured floor lock and reaches the real waypoint")
			check(grounded_frames == 900 and minimum_y > .03, "Fixed bot retains continuously grounded, supported floor movement")
	result["end_distance"] = flat_distance(bot.position, vector(captured.waypoint_goal))
	result["end_position"] = str(bot.position)
	print("CAPTURED_FLOOR_REPLAY ", JSON.stringify({"arm": arm_name, "history": history, "policy": policy, "first_goal": first_goal, "grounded_frames": grounded_frames, "maximum_off_goal_stall": maximum_off_goal_stall, "distance8": result.distance_at_8s, "end_distance": result.end_distance, "longest_low_motion": result.longest_low_motion, "travel": result.travel}))
	bot.queue_free()
	await process_frame
	return result

func finish() -> void:
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: exact captured floor lock reproduces before and recovers with supported local/model movement after")
	quit(0 if failures.is_empty() else 1)
