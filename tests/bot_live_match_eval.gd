extends SceneTree
## Production6bot KOTH, actual map/collision/combat/respawns; metrics are evidence,
## not a claim about humanlike play. No gameplay knobs are overridden.
const DT := 1.0 / 60.0
var session: Node
var statistics: Dictionary = {}
var rounds: Array[Dictionary] = []
var limit_seconds := 300.0
var run_count := 2
var level := 1
var seed_value := 173
var output_path := "res://work/bot-live-eval.json"
var tag := "baseline"
var baseline_source := ""
var accelerated := true
var screenshot_path := ""
var screenshots_prefix := ""
var current_round: Dictionary = {}
var current_time := 0.0
var motion_trace_path := ""
var _motion_trace: Array[Dictionary] = []
var policy_mode := 0
var enabled_teams: Array[int] = []
var _policy_events: Array[Dictionary] = []
var _frame_times_ms: Array[float] = []
var _process_times_ms: Array[float] = []
var _physics_times_ms: Array[float] = []
var _last_frame_usec := 0
var _collect_frame_metrics := false
var _fps_samples: Array[int] = []

func _initialize() -> void: call_deferred("run")
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("seconds="): limit_seconds = float(argument.get_slice("=", 1))
		if argument.begins_with("runs="): run_count = int(argument.get_slice("=", 1))
		if argument.begins_with("level="): level = int(argument.get_slice("=", 1))
		if argument.begins_with("seed="): seed_value = int(argument.get_slice("=", 1))
		if argument.begins_with("motion_trace="): motion_trace_path = argument.trim_prefix("motion_trace=")
		if argument.begins_with("policy="): policy_mode = clampi(int(argument.get_slice("=", 1)), 0, 2)
		if argument.begins_with("teams="):
			for team in argument.trim_prefix("teams=").split(",", false): enabled_teams.append(int(team))
		if argument.begins_with("output="): output_path = argument.trim_prefix("output=")
		if argument.begins_with("tag="): tag = argument.trim_prefix("tag=")
		if argument.begins_with("source="): baseline_source = argument.trim_prefix("source=")
		if argument == "realtime": accelerated = false
		if argument.begins_with("screenshot="): screenshot_path = argument.trim_prefix("screenshot=")
		if argument.begins_with("screenshots="): screenshots_prefix = argument.trim_prefix("screenshots=")
	# Actual async inference must retain wall-time cadence and expiry semantics.
	# Accelerated local-only fixtures are useful but cannot be paired with model
	# arms and described as equivalent real inference.
	if policy_mode > 0: accelerated = false
	if not baseline_source.is_empty():
		var script: GDScript = load("res://scenes/bots/duel_bot.gd")
		script.source_code = FileAccess.get_file_as_string(baseline_source)
		assert(script.reload() == OK, "Baseline source reload must compile without mutating files")
	Engine.physics_ticks_per_second = 600 if accelerated else 60
	Engine.time_scale = 10.0 if accelerated else 1.0
	session = root.get_node("LanSession")
	assert(session.host_lobby("Evaluation spectator") == OK)
	# Spectator fixture only: replace host seat with a third genuine host bot.
	# Normal party UI remains unchanged; all six actors use productionmanager.
	session.roster.clear()
	for team in [1, 2]:
		for slot in range(3): session.add_bot(team)
	session.start_match()
	var loaded_bot_script: GDScript = load("res://scenes/bots/duel_bot.gd")
	var bot_source_hash := loaded_bot_script.source_code.sha256_text()
	for round_index in range(run_count):
		var arena: Node3D = load("res://scenes/levels/garden/lan_garden.tscn").instantiate()
		root.add_child(arena)
		await process_frame
		var observer: Camera3D
		var manager: TeamMatchManager = arena.get_node("DuelManager")
		assert(manager.actors.size() == 6, "Evaluation needs6 genuine bots")
		manager.player.set_physics_process(false)
		manager.player.weapon.set_physics_process(false)
		manager.player.global_position = Vector3(0, 100, 0)
		manager.player.get_node("CollisionShape3D").disabled = true
		if not accelerated:
			observer = Camera3D.new()
			arena.add_child(observer)
			observer.global_position = manager.point_position + Vector3(18, 16, 18)
			observer.look_at(manager.point_position + Vector3.UP, Vector3.UP)
			observer.current = true
			manager.player.camera = observer
		manager.dev_action("bot_difficulty", level)
		if manager.has_method("set_tactical_mode"): manager.call("set_tactical_mode", 0)
		elif policy_mode > 0: assert(false, "Requested policy arm requires actual tactical integration")
		statistics.clear()
		current_time = 0.0
		current_round = {"round": round_index + 1, "seed": seed_value + round_index * 1009, "captures": [], "contested_seconds": 0.0, "unowned_seconds": 0.0, "both_teams_near_hill_seconds": 0.0, "actors": {}}
		manager.rules.point_captured.connect(func(team: int): current_round.captures.append({"time": current_time, "team": team}))
		for id in manager.actors:
			var actor: DuelBot = manager.actors[id]
			actor._random.seed = seed_value + round_index * 1009 + statistics.size() * 41
			actor.respawn_at(manager._roster_spawn(id))
			var route: Variant = actor.get("route_variant")
			var counters := {"rng_seed": seed_value + round_index * 1009 + statistics.size() * 41, "route_variants": [int(route)] if route is int else [], "lives": [], "maximum_waypoint_dwell": 0.0, "waypoint_dwell_bursts": [], "_waypoint_index": -1, "_waypoint_dwell": 0.0, "_waypoint_start_distance": 0.0, "_waypoint_end_distance": 0.0, "_life": {"spawn_time": 0.0, "first_hill_time": -1.0, "first_grounded_hill_time": -1.0}, "team": actor.team_id, "role": actor.tactical_role, "shots": 0, "deaths": 0, "damage_taken": 0.0, "respawns": 0, "reloads": 0, "jumps": 0, "alive_seconds": 0.0, "hill_grounded_seconds": 0.0, "outside_hill_behavior_seconds": {}, "sprint_seconds": 0.0, "cover_seconds": 0.0, "goal_stall_seconds": 0.0, "behavior_goal_stall_seconds": {}, "maximum_goal_stall": 0.0, "stall_bursts": [], "behavior_seconds": {}, "first_hill_time": -1.0, "maximum_route_index": 0, "travel_distance": 0.0, "_previous": actor.global_position, "_window_position": actor.global_position, "_window_alive": true, "_stall_run": 0.0, "_reload": false, "_grounded": true, "_health": actor.current_health}
			statistics[id] = counters
			actor.shot_fired.connect(func(_target: Node3D): counters.shots += 1)
			actor.died.connect(func():
				counters.deaths += 1
				_finish_life(counters, "death")
				_flush_waypoint(counters, actor.global_position))
			actor.health_changed.connect(func(health: float, _maximum: float):
				if health < float(counters._health): counters.damage_taken += float(counters._health) - health
				counters._health = health)
			actor.respawned.connect(func():
				counters.respawns += 1
				_finish_life(counters, "forced_respawn")
				counters._life = {"spawn_time": current_time, "first_hill_time": -1.0, "first_grounded_hill_time": -1.0}
				counters._waypoint_index = -1
				counters._window_position = actor.global_position
				counters._previous = actor.global_position
				counters._window_alive = false
				var next_route: Variant = actor.get("route_variant")
				if next_route is int: counters.route_variants.append(int(next_route)))
		var policy_client: Node = manager.get("tactical_decisions")
		_policy_events.clear()
		if policy_client != null:
			policy_client.set("enabled_teams", enabled_teams)
			policy_client.call("reset_metrics")
			if policy_client.has_signal("decision_logged"):
				policy_client.connect("decision_logged", func(event: Dictionary): _policy_events.append(event.duplicate(true)))
			manager.call("set_tactical_mode", policy_mode)
		_frame_times_ms.clear()
		_process_times_ms.clear()
		_physics_times_ms.clear()
		_fps_samples.clear()
		_last_frame_usec = 0
		_collect_frame_metrics = not accelerated and DisplayServer.get_name() != "headless"
		var round_wall_start := Time.get_ticks_usec()
		current_round["wall_start_unix"] = Time.get_unix_time_from_system()
		var ticks := int(limit_seconds * 60.0)
		for tick in range(ticks):
			await physics_frame
			current_time = (tick + 1) * DT
			if manager.rules.contested: current_round.contested_seconds += DT
			if manager.rules.owner_team == 0: current_round.unowned_seconds += DT
			if manager.cyan_count > 0 and manager.amber_count > 0: current_round.both_teams_near_hill_seconds += DT
			for id in manager.actors:
				var actor: DuelBot = manager.actors[id]
				var counters: Dictionary = statistics[id]
				if actor.is_alive:
					counters.alive_seconds += DT
					counters.travel_distance += actor.global_position.distance_to(counters._previous)
					if actor.sprinting: counters.sprint_seconds += DT
					if actor._has_cover: counters.cover_seconds += DT
					if actor.reloading and not counters._reload: counters.reloads += 1
					if not actor.is_on_floor() and counters._grounded and actor.velocity.y > 0.0: counters.jumps += 1
					counters.behavior_seconds[actor.behavior_state] = float(counters.behavior_seconds.get(actor.behavior_state, 0.0)) + DT
					counters.maximum_route_index = maxi(counters.maximum_route_index, actor._objective_index)
					var flat := actor.global_position - manager.point_position
					if counters.first_hill_time < 0.0 and Vector2(flat.x, flat.z).length() < manager.point_radius:
						counters.first_hill_time = current_time
					if counters._life is Dictionary and counters._life.first_hill_time < 0.0 and Vector2(flat.x, flat.z).length() < manager.point_radius:
						counters._life.first_hill_time = current_time
					if Vector2(flat.x, flat.z).length() > manager.point_radius:
						counters.outside_hill_behavior_seconds[actor.behavior_state] = float(counters.outside_hill_behavior_seconds.get(actor.behavior_state, 0.0)) + DT
					elif absf(flat.y) <= manager.point_height_tolerance and actor.is_on_floor():
						counters.hill_grounded_seconds += DT
						if counters._life is Dictionary and counters._life.first_grounded_hill_time < 0.0: counters._life.first_grounded_hill_time = current_time
				else: counters._window_alive = false
				counters._previous = actor.global_position
				counters._reload = actor.reloading
				counters._grounded = actor.is_on_floor()
				if (tick + 1) % 60 == 0:
					if not motion_trace_path.is_empty(): _trace_motion(str(id), actor)
					var goal_distance := 0.0
					if not actor._objective_route.is_empty():
						var offset: Vector3 = actor._objective_route[actor._objective_index] - actor.global_position
						goal_distance = Vector2(offset.x, offset.z).length()
					var actual_displacement: float = actor.global_position.distance_to(counters._window_position)
					var hill_offset: Vector3 = actor.global_position - manager.point_position
					var outside_hill := Vector2(hill_offset.x, hill_offset.z).length() > manager.point_radius + 2.0
					var traveling := actor.is_alive and outside_hill and goal_distance > 2.0
					if traveling:
						if actor._objective_index != int(counters._waypoint_index):
							_flush_waypoint(counters, actor.global_position)
							counters._waypoint_index = actor._objective_index
							counters._waypoint_start_distance = goal_distance
						counters._waypoint_dwell += 1.0
						counters._waypoint_end_distance = goal_distance
						counters.maximum_waypoint_dwell = maxf(counters.maximum_waypoint_dwell, counters._waypoint_dwell)
					else:
						_flush_waypoint(counters, actor.global_position)
						counters._waypoint_index = -1
					if actor.is_alive and counters._window_alive and outside_hill and goal_distance > 2.0 and actual_displacement < 0.35 and not actor.reloading and not actor._has_cover and actor._retreat_remaining <= 0.0:
						counters._stall_run += 1.0
						counters.goal_stall_seconds += 1.0
						counters.behavior_goal_stall_seconds[actor.behavior_state] = float(counters.behavior_goal_stall_seconds.get(actor.behavior_state, 0.0)) + 1.0
						counters.maximum_goal_stall = maxf(counters.maximum_goal_stall, counters._stall_run)
					else:
						if counters._stall_run >= 2.0: counters.stall_bursts.append({"end_time": current_time, "seconds": counters._stall_run, "position": str(actor.global_position)})
						counters._stall_run = 0.0
					counters._window_position = actor.global_position
					counters._window_alive = actor.is_alive
			if (tick + 1) % 60 == 0 and _collect_frame_metrics:
				_fps_samples.append(Engine.get_frames_per_second())
			if (tick + 1) % 3600 == 0:
				print("BOT_LIVE_PROGRESS tag=%s level=%d round=%d sim=%.0fs captures=%d contested=%.1fs deaths=%d" % [tag, level, round_index + 1, current_time, current_round.captures.size(), current_round.contested_seconds, _sum("deaths")])
			if not screenshots_prefix.is_empty() and not accelerated and (tick + 1) % 900 == 0:
				var side := 1.0 if (tick + 1) % 1800 == 0 else -1.0
				observer.global_position = manager.point_position + Vector3(18 * side, 16, 18 * side)
				observer.look_at(manager.point_position + Vector3.UP, Vector3.UP)
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("%s-%03d.png" % [screenshots_prefix, int(current_time)])
			if manager.match_over: break
		_collect_frame_metrics = false
		current_round["wall_end_unix"] = Time.get_unix_time_from_system()
		current_round["wall_seconds"] = (Time.get_ticks_usec() - round_wall_start) / 1000000.0
		current_round["policy_mode"] = policy_mode
		current_round["enabled_teams"] = enabled_teams
		current_round["policy_metrics"] = policy_client.call("get_metrics") if policy_client != null else {}
		current_round["policy_events"] = _policy_events.duplicate(true)
		current_round["frame_metrics"] = {"samples": _frame_times_ms.size(), "frame_ms": _distribution(_frame_times_ms), "cpu_process_ms": _distribution(_process_times_ms), "cpu_physics_ms": _distribution(_physics_times_ms), "fps_samples": _fps_samples, "gpu_time": "not measured", "warmup": "First5simulation seconds excluded after scene/roster setup; no scene import included."}
		current_round["duration"] = current_time
		current_round["winner"] = manager.rules.winner_team
		current_round["match_complete"] = manager.match_over
		current_round["remaining_clocks"] = [manager.rules.get_team_seconds(1), manager.rules.get_team_seconds(2)]
		for id in statistics:
			var counters: Dictionary = statistics[id]
			_finish_life(counters, "match_end" if manager.match_over else "time_cap")
			_flush_waypoint(counters, manager.actors[id].global_position)
			if counters._stall_run >= 2.0: counters.stall_bursts.append({"end_time": current_time, "seconds": counters._stall_run, "position": str(manager.actors[id].global_position)})
			for key in counters.keys():
				if str(key).begins_with("_"): counters.erase(key)
			current_round.actors[id] = counters
		rounds.append(current_round.duplicate(true))
		print("BOT_LIVE_ROUND tag=%s level=%d round=%d duration=%.1f captures=%d contested=%.1f shots=%d deaths=%d reloads=%d" % [tag, level, round_index + 1, current_time, current_round.captures.size(), current_round.contested_seconds, _sum("shots"), _sum("deaths"), _sum("reloads")])
		if not screenshot_path.is_empty() and not accelerated:
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(screenshot_path)
		arena.queue_free()
		await process_frame
	if not motion_trace_path.is_empty():
		var trace_file := FileAccess.open(motion_trace_path, FileAccess.WRITE)
		assert(trace_file != null, "Unable to save optional motion trace")
		trace_file.store_string(JSON.stringify({"tag": tag, "sample_interval_seconds": 1, "read_only": true, "records": _motion_trace}))
		trace_file.close()
	var result := {"policy_mode": policy_mode, "enabled_teams": enabled_teams, "tag": tag, "level": level, "bot_source_sha256": bot_source_hash, "physics_delta": DT, "physics_ticks": Engine.physics_ticks_per_second, "time_scale": Engine.time_scale, "rounds": rounds, "limits": "Host-only spectator fixture; seed-controlled RNG, real map/collision/combat/objective clocks. Native frame metrics only when rendered; not human skill or2device Wi-Fi evidence."}
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	assert(file != null, "Evaluation output must be writable")
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	session.leave_lobby()
	print("BOT_LIVE_EVAL_PASS output=%s rounds=%d" % [output_path, rounds.size()])
	quit(0)

func _sum(key: String) -> int:
	var total := 0
	for counters in statistics.values(): total += int(counters.get(key, 0))
	return total

func _finish_life(counters: Dictionary, reason: String) -> void:
	if not counters._life is Dictionary: return
	counters._life["end_time"] = current_time
	counters._life["end_reason"] = reason
	counters.lives.append(counters._life.duplicate(true))
	counters._life = null

func _flush_waypoint(counters: Dictionary, position: Vector3) -> void:
	if float(counters._waypoint_dwell) >= 10.0:
		counters.waypoint_dwell_bursts.append({"end_time": current_time, "seconds": counters._waypoint_dwell, "index": counters._waypoint_index, "start_distance": counters._waypoint_start_distance, "end_distance": counters._waypoint_end_distance, "position": str(position)})
	counters._waypoint_dwell = 0.0

func _process(_delta: float) -> bool:
	if _collect_frame_metrics and current_time >= 5.0:
		var now := Time.get_ticks_usec()
		if _last_frame_usec > 0: _frame_times_ms.append((now - _last_frame_usec) / 1000.0)
		_last_frame_usec = now
		_process_times_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		_physics_times_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	return false

func _distribution(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	var stalls := 0
	for value in values:
		total += value
		if value > 25.0: stalls += 1
	return {"mean": total / values.size(), "median": sorted[int((sorted.size() - 1) * 0.5)], "p95": sorted[int((sorted.size() - 1) * 0.95)], "p99": sorted[int((sorted.size() - 1) * 0.99)], "maximum": sorted[-1], "over_25ms": stalls}


func _trace_motion(id: String, actor: DuelBot) -> void:
	var goal := actor.global_position
	if not actor._objective_route.is_empty(): goal = actor._objective_route[actor._objective_index]
	var collisions: Array[Dictionary] = []
	for index in actor.get_slide_collision_count():
		var collision := actor.get_slide_collision(index)
		var collider := collision.get_collider()
		collisions.append({"normal": _trace_vector(collision.get_normal()), "point": _trace_vector(collision.get_position()), "collider": str((collider as Node).get_path()) if collider is Node else str(collider)})
	var target: Dictionary = {}
	if is_instance_valid(actor._target): target = {"name": str(actor._target.name), "position": _trace_vector(actor._target.global_position)}
	_motion_trace.append({"seconds": current_time, "seed": current_round.seed, "bot_id": id, "team": actor.team_id, "role": actor.tactical_role, "life": actor.tactical_life_generation, "rng_state": str(actor._random.state), "alive": actor.is_alive, "position": _trace_vector(actor.global_position), "velocity": _trace_vector(actor.velocity), "grounded": actor.is_on_floor(), "collisions": collisions, "target": target, "waypoint_index": actor._objective_index, "waypoint_goal": _trace_vector(goal), "route": actor._objective_route.map(func(point: Vector3): return _trace_vector(point)), "route_variant": actor.route_variant, "behavior": actor.behavior_state, "health": actor.current_health, "ammo": actor.ammo_in_magazine, "reloading": actor.reloading, "sprinting": actor.sprinting, "strafe_side": actor._strafe_direction, "stance_remaining": actor._stance_remaining, "combat_bias": actor._combat_bias, "engagement_remaining": actor._engagement_remaining, "advance_commit_remaining": actor._advance_commit_remaining, "goal_stall_time": actor._goal_stall_time, "objective_detour": actor._objective_detour, "retreat_remaining": actor._retreat_remaining, "retreat_cooldown": actor._retreat_cooldown, "has_cover": actor._has_cover, "cover_goal": _trace_vector(actor._cover_position), "steering_direction": _trace_vector(actor._steering_direction), "policy_action": actor._policy_action, "policy_remaining": actor._policy_remaining, "policy_side": actor._policy_side, "policy_goal": _trace_vector(actor._policy_goal)})

func _trace_vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
