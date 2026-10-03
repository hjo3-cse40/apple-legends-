extends SceneTree
## Real map, bot movement, occupancy, respawn and production three-minute clocks.
const DT := 1.0 / 60.0
var failures: Array[String] = []

func _init() -> void:
	call_deferred(&"_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _run() -> void:
	if "--fast" in OS.get_cmdline_user_args():
		Engine.physics_ticks_per_second = 600
		Engine.time_scale = 10.0
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var arena := main.get_node("MovementLab")
	var manager := arena.get_node("DuelManager") as KothManager
	var player := arena.get_node("Player") as FirstPersonPlayer
	var bot := arena.get_node("DuelBot") as DuelBot
	# Keep the player protected at their spawn; the bot still uses production movement.
	player.set_physics_process(false)
	player.weapon.set_physics_process(false)
	bot.hit_chance = 0.0
	for match_index in range(3):
		var saw_capture := false
		var killed_bot := false
		var retained_clock := -1.0
		var simulated_time := 0.0
		for tick in range(60 * 270):
			await physics_frame
			simulated_time += DT
			if not saw_capture and manager.rules.owner_team == KothRules.AMBER:
				saw_capture = true
				print("KOTH eval round %d: bot captured at %.2fs" % [match_index + 1, simulated_time])
			# Middle round proves respawning does not reset the held team's clock.
			if match_index == 1 and saw_capture and not killed_bot and manager.rules.get_team_seconds(KothRules.AMBER) < 160.0:
				retained_clock = manager.rules.get_team_seconds(KothRules.AMBER)
				bot.apply_damage(bot.maximum_health)
				killed_bot = true
				check(not manager.match_over and manager.player_score == 0, "bot death is not a match win")
			if killed_bot and bot.is_alive:
				check(manager.rules.get_team_seconds(KothRules.AMBER) <= retained_clock, "respawn retains owner clock")
				retained_clock = manager.rules.get_team_seconds(KothRules.AMBER)
			if manager.match_over:
				break
		check(saw_capture, "production bot must capture round %d" % (match_index + 1))
		check(manager.match_over and manager.rules.winner_team == KothRules.AMBER, "production bot must win full 180 second round %d" % (match_index + 1))
		check(not bot.is_physics_processing() and not player.weapon.is_physics_processing(), "real win freezes bot and weapon")
		check(manager.rules.get_team_seconds(KothRules.CYAN) == 180.0, "nonowning cyan clock remains intact")
		print("KOTH eval round %d: %.2fs, owner=%d, amber=%.3f, bot=%s" % [match_index + 1, simulated_time, manager.rules.owner_team, manager.rules.get_team_seconds(KothRules.AMBER), bot.global_position])
		manager.restart_match()
		player.set_physics_process(false)
		player.weapon.set_physics_process(false)
		# Cycle the authored spawn slots on subsequent rounds.
		bot.respawn_at(manager._spawn_transform(manager._bot_spawns, match_index + 1))
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("KOTH long match eval: PASS (3 actual map rounds, full clocks, death/respawn, alternating spawns)")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
