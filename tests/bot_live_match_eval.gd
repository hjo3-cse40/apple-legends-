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

func _initialize() -> void: call_deferred("run")
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("seconds="): limit_seconds = float(argument.get_slice("=", 1))
		if argument.begins_with("runs="): run_count = int(argument.get_slice("=", 1))
		if argument.begins_with("level="): level = int(argument.get_slice("=", 1))
		if argument.begins_with("seed="): seed_value = int(argument.get_slice("=", 1))
		if argument.begins_with("output="): output_path = argument.trim_prefix("output=")
		if argument.begins_with("tag="): tag = argument.trim_prefix("tag=")
		if argument.begins_with("source="): baseline_source = argument.trim_prefix("source=")
		if argument == "realtime": accelerated = false
		if argument.begins_with("screenshot="): screenshot_path = argument.trim_prefix("screenshot=")
		if argument.begins_with("screenshots="): screenshots_prefix = argument.trim_prefix("screenshots=")
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
	var result := {"tag": tag, "level": level, "bot_source_sha256": bot_source_hash, "physics_delta": DT, "physics_ticks": Engine.physics_ticks_per_second, "time_scale": Engine.time_scale, "rounds": rounds, "limits": "Host-only spectator fixture; seed-controlled RNG, real map/collision/combat/objective clocks. Not human skill, native frame pacing or2device Wi-Fi evidence."}
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
