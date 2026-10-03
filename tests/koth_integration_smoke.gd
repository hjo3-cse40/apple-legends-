extends SceneTree

var failures: Array[String] = []
var manager: KothManager
var arena: Node3D
var player: FirstPersonPlayer
var bot: DuelBot
var finish_count := 0

func _init() -> void:
	call_deferred(&"_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func place_on_point(body: CharacterBody3D, offset := Vector3.ZERO) -> void:
	body.global_position = manager.point_position + offset + Vector3.UP * 0.03
	for tick in range(10):
		body.velocity = Vector3.DOWN * 2.0
		body.move_and_slide()
	body.velocity = Vector3.ZERO

func _run() -> void:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	arena = main.get_node("MovementLab")
	manager = arena.get_node("DuelManager") as KothManager
	player = arena.get_node("Player") as FirstPersonPlayer
	bot = arena.get_node("DuelBot") as DuelBot
	check(manager != null, "garden runs KothManager")
	manager.set_physics_process(false)
	player.set_physics_process(false)
	bot.set_physics_process(false)
	manager.match_finished.connect(func(_won: bool): finish_count += 1)
	check(manager.respawn_delay == 3.0 and manager.rules.round_duration == 180.0, "production 3 second respawn and 3 minute team clocks")
	check(manager.rules.capture_duration == 12.0 and manager.rules.unlock_duration == 15.0, "production capture and unlock pacing")
	check(player.is_in_group(&"koth_participant") and bot.is_in_group(&"koth_participant"), "living actors registered as objective participants")
	manager.rules.unlock_duration = 0.0
	manager.rules.reset_match()
	place_on_point(player)
	place_on_point(bot, Vector3(0.8, 0, 0))
	manager._physics_process(6.0)
	check(manager.cyan_count == 1 and manager.amber_count == 1, "both grounded bodies counted")
	check(manager.rules.contested and manager.rules.capture_progress == 0.0, "live opposing bodies contest")
	bot.global_position += Vector3.RIGHT * 20.0
	manager._physics_process(6.0)
	check(manager.cyan_count == 1 and manager.amber_count == 0 and is_equal_approx(manager.rules.capture_progress, 0.5), "sole cyan progresses")
	player.global_position += Vector3.UP * 5.0
	player.velocity = Vector3.ZERO
	player.move_and_slide()
	manager._physics_process(1.0)
	check(manager.cyan_count == 0, "airborne body cannot capture")
	place_on_point(player)
	manager._physics_process(7.0)
	check(manager.rules.owner_team == KothRules.CYAN, "actual hill geometry permits full capture")
	var before_pause := manager.rules.get_team_seconds(KothRules.CYAN)
	manager.set_physics_process(true)
	paused = true
	await process_frame
	await process_frame
	check(manager.rules.get_team_seconds(KothRules.CYAN) == before_pause, "Esc tree pause freezes objective clock")
	paused = false
	manager.set_physics_process(false)
	player.apply_damage(player.maximum_health)
	check(manager.player_score == 0 and manager.bot_score == 0 and not manager.match_over, "player death does not award score or finish objective match")
	check(not manager.player_respawn_timer.is_stopped(), "player death starts respawn")
	manager._update_occupancy()
	check(manager.cyan_count == 0, "dead body excluded from capture")
	manager.player_respawn_timer.start(0.01)
	await manager.player_respawn_timer.timeout
	check(player.is_alive, "player death actually respawns")
	bot.apply_damage(bot.maximum_health)
	check(not manager.bot_respawn_timer.is_stopped() and manager.player_score == 0, "bot death starts respawn without score")
	manager.bot_respawn_timer.start(0.01)
	await manager.bot_respawn_timer.timeout
	check(bot.is_alive and bot.objective_enabled, "bot respawns still pursuing objective")
	# Saved F1 preference survives both terminal freeze and Enter restart.
	arena.set("opponent_paused", true)
	bot.set_physics_process(false)
	player.set_physics_process(true)
	manager.rules.round_duration = 0.2
	manager.rules.reset_match()
	bot.get_node("Visuals/MuzzleFlash").show()
	manager.rules.advance(12.2, 1, 0)
	check(not (bot.get_node("Visuals/MuzzleFlash") as Node3D).visible, "winner clears active bot muzzle flash")
	check(manager.match_over and finish_count == 1, "rules victory finishes integrated match once")
	check(not player.is_physics_processing() and not bot.is_physics_processing() and not player.weapon.is_physics_processing(), "victory freezes movement and firing")
	check(not player.is_processing_unhandled_input() and not player.weapon.is_processing_input(), "victory freezes player and rifle input")
	check(not manager.hud.match_message.visible, "legacy elimination message hidden at victory")
	check(not (arena.get_node("KothHUD") as KothHUD).result.text.is_empty(), "KOTH winner visible")
	var settings := arena.get_node("SettingsMenu")
	settings.open_menu()
	settings.close_menu()
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "winner Esc settings keeps cursor visible")
	settings._freeze_changed(false)
	check(not player.is_physics_processing() and not bot.is_physics_processing() and not player.weapon.is_physics_processing(), "winner settings cannot reenable combat or bot")
	# Restore the intended F1 preference after the settings guard test.
	arena.set("opponent_paused", true)
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	manager._unhandled_input(enter)
	check(not manager.match_over and not manager.rules.match_over and manager.rules.owner_team == KothRules.NEUTRAL, "Enter restarts objective state")
	check(player.is_physics_processing() and player.weapon.is_physics_processing() and player.weapon.is_processing_input(), "restart restores player and rifle")
	check(not bot.is_physics_processing() and bool(arena.get("opponent_paused")), "restart preserves F1 bot freeze")
	# Run repeated accelerated integrated wins for both teams; no kill score can end a round.
	for index in range(24):
		manager.set_physics_process(false)
		manager.rules.round_duration = 0.13 + float(index % 5) * 0.17
		manager.rules.reset_match()
		manager.rules.advance(12.0 + manager.rules.round_duration, 1 if index % 2 == 0 else 0, 1 if index % 2 == 1 else 0)
		check(manager.match_over and manager.rules.winner_team == (KothRules.CYAN if index % 2 == 0 else KothRules.AMBER), "repeat win cycle %s" % index)
		manager.restart_match()
	check(finish_count == 25, "one terminal event per repeated round")
	await physics_frame
	# Full production clock transfer through a two-minute stalemate and two recaptures.
	manager.set_physics_process(false)
	player.set_physics_process(false)
	bot.set_physics_process(false)
	manager.rules.round_duration = 180.0
	manager.rules.reset_match()
	place_on_point(player)
	bot.global_position += Vector3.RIGHT * 40.0
	manager._physics_process(42.0)
	check(is_equal_approx(manager.rules.get_team_seconds(KothRules.CYAN), 150.0), "full round cyan30 second hold")
	place_on_point(bot, Vector3.RIGHT * 0.8)
	manager._physics_process(120.0)
	check(is_equal_approx(manager.rules.get_team_seconds(KothRules.CYAN), 150.0), "full round120 second contest freezes clock")
	player.global_position += Vector3.LEFT * 20.0
	manager._physics_process(102.0)
	check(manager.rules.owner_team == KothRules.AMBER and is_equal_approx(manager.rules.get_team_seconds(KothRules.AMBER), 90.0), "full round amber captures then holds90 seconds")
	check(is_equal_approx(manager.rules.get_team_seconds(KothRules.CYAN), 138.0), "full round former owner retains138 seconds")
	place_on_point(player)
	bot.global_position += Vector3.RIGHT * 20.0
	manager._physics_process(12.0)
	check(manager.rules.owner_team == KothRules.CYAN and is_equal_approx(manager.rules.get_team_seconds(KothRules.CYAN), 138.0), "full round recapture restores retained138 seconds")
	manager._physics_process(138.0)
	check(manager.match_over and manager.rules.winner_team == KothRules.CYAN, "full round contest and recapture scenario wins correctly")
	for sound in main.find_children("*", "AudioStreamPlayer3D", true, false):
		(sound as AudioStreamPlayer3D).stop()
	for sound in main.find_children("*", "AudioStreamPlayer", true, false):
		(sound as AudioStreamPlayer).stop()
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("KOTH integration smoke: PASS (grounded contest, capture, pause, respawn, victory, Esc, Enter, F1,24 rounds and full-clock recaptures)")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
