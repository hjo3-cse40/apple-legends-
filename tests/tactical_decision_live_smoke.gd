extends SceneTree
## Real local Laya worker, actual host manager and production bot APIs.
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func run() -> void:
	var session: Node = root.get_node("LanSession")
	check(session.host_lobby("Laya live smoke") == OK, "Host opens real LAN session")
	session.add_bot(2)
	session.set_ready(true)
	session.start_match()
	var arena: Node3D = load("res://scenes/levels/garden/lan_garden.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var manager := arena.get_node("DuelManager") as TeamMatchManager
	manager.player.set_physics_process(false)
	manager.player.weapon.set_physics_process(false)
	var client: TacticalDecisionClient = manager.tactical_decisions
	var bot_id := str(manager.tactical_bot_ids()[0])
	var context := manager.build_tactical_context(bot_id)
	var own_team := int(context.team)
	var enemy_team := KothRules.AMBER if own_team == KothRules.CYAN else KothRules.CYAN
	check(context.request.observation.own_clock_seconds == manager.rules.get_team_seconds(own_team), "Own public objective clock included")
	check(context.request.observation.enemy_clock_seconds == manager.rules.get_team_seconds(enemy_team), "Enemy public objective clock included")
	manager.rules.owner_team = enemy_team
	manager.rules.team_seconds_remaining[enemy_team] = 29.0
	check(manager.build_tactical_context(bot_id).request.observation.objective_urgency == "critical", "Near-win enemy objective clock is critical")
	manager.rules.reset_match()
	manager.rules.contested = true
	check(manager.build_tactical_context(bot_id).request.observation.objective_urgency == "critical", "Contested public objective is critical")
	manager.rules.reset_match()
	check(manager.build_tactical_context(bot_id).request.observation.objective_urgency == "normal", "Reset objective urgency is normal")
	client.set_mode(TacticalDecisionClient.Mode.SHADOW)
	await create_timer(7.0).timeout
	var shadow := client.get_metrics()
	check(shadow.worker_ready and shadow.completed > 0 and shadow.comparisons > 0, "Actual model completes shadow decisions")
	check(shadow.applied == 0, "Actual shadow mode leaves bot actions local")
	client.set_mode(TacticalDecisionClient.Mode.LOCAL)
	client.reset_metrics()
	client.set_mode(TacticalDecisionClient.Mode.ENABLED)
	await create_timer(7.0).timeout
	var enabled := client.get_metrics()
	check(enabled.worker_ready and enabled.applied > 0, "Actual model applies valid production bot decision")
	manager.set_bots_frozen(true)
	check(client._active.is_empty() and client._queued.is_empty(), "Freeze cancels real queued/inflight requests")
	for actor in manager.actors.values():
		if actor is DuelBot: check(actor.tactical_policy_action.is_empty(), "Freeze clears applied bot commitment")
	manager.set_bots_frozen(false)
	manager.dev_action("bots_off")
	check(not manager.tactical_requests_available(), "Disabled bots stop inference")
	manager.dev_action("bots_on")
	manager.restart_match()
	check(client._active.is_empty() and client._queued.is_empty(), "Restart clears prior-life inference")
	var report := {"shadow": shadow, "enabled": enabled, "real_model": true, "limits": "14 realtime seconds, actual host+one bot, model service preloaded externally; not policy quality or frame-time benchmark"}
	var file := FileAccess.open("res://work/laya-live-client-smoke.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	manager.dev_action("return_lobby")
	check(client._active.is_empty() and client._queued.is_empty(), "Lobby cancels inference")
	arena.queue_free()
	session.leave_lobby()
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("TACTICAL_LIVE_PASS: real Laya shadow%d/enabled%d applied%d, freeze/disable/restart/lobby cleanup, reportwork/laya-live-client-smoke.json" % [shadow.completed, enabled.completed, enabled.applied])
	quit(0 if failures.is_empty() else 1)
