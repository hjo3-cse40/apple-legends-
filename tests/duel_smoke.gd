extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var main_scene := load("res://scenes/main/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame

	var level := main.get_node("MovementLab")
	var player := level.get_node("Player") as FirstPersonPlayer
	var bot := level.get_node("DuelBot") as DuelBot
	var manager := level.get_node("DuelManager") as DuelManager
	var hud := level.get_node("DebugHUD") as DebugHUD
	bot.set_physics_process(false)
	manager.target_score = 2
	manager.player_respawn_timer.wait_time = 0.05
	manager.bot_respawn_timer.wait_time = 0.05

	_check(player.is_alive and is_equal_approx(player.current_health, 100.0), "player should start alive at full health")
	_check(bot.is_alive and bot.movement_enabled, "integrated bot should start alive with movement enabled")
	_check(manager.player_score == 0 and manager.bot_score == 0, "duel should start scoreless")

	player.weapon.ammo_in_magazine = 2
	_check(player.apply_damage(player.maximum_health), "player should accept lethal damage")
	# Death and HUD signals are synchronous; inspect before the short respawn timer can fire.
	_check(not player.is_alive, "lethal damage should kill the player")
	_check(manager.bot_score == 1, "player death should award the bot one point")
	_check(hud.match_message.visible and "ELIMINATED" in hud.match_message.text, "player death should explain the temporary input lockout")
	await manager.player_respawn_timer.timeout
	_check(player.is_alive and is_equal_approx(player.current_health, player.maximum_health), "player should respawn at full health")
	_check(player.weapon.ammo_in_magazine == player.weapon.magazine_size, "player respawn should refill the rifle")
	_check(not hud.match_message.visible, "respawn should clear the elimination message")

	_check(bot.apply_damage(bot.maximum_health), "bot should accept lethal damage")
	_check(manager.player_score == 1, "bot death should award the player one point")
	await manager.bot_respawn_timer.timeout
	_check(bot.is_alive and is_equal_approx(bot.current_health, bot.maximum_health), "bot should respawn at full health")

	bot.apply_damage(bot.maximum_health)
	await process_frame
	_check(manager.player_score == 2 and manager.match_over, "target score should finish the match")
	_check(hud.match_message.visible and "VICTORY" in hud.match_message.text, "HUD should announce victory")

	manager.restart_match()
	await process_frame
	_check(not manager.match_over and manager.player_score == 0 and manager.bot_score == 0, "restart should clear the match and score")
	_check(player.is_alive and bot.is_alive, "restart should respawn both combatants")
	_check("YOU  0" in hud.score_readout.text and "0  BOT" in hud.score_readout.text, "HUD should show reset score")

	main.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: player damage/death, respawns, scoring, match finish, HUD, and restart")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
