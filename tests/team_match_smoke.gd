extends SceneTree
var failures: Array[String] = []
func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func run() -> void:
	Engine.physics_ticks_per_second = 600
	Engine.time_scale = 10.0
	var session := root.get_node("LanSession")
	check(session.host_lobby("Sam") == OK, "host opens")
	for count in [1, 2, 3]:
		# One real local human plus optional bots; no synthetic peer connection.
		for entry in session.roster.duplicate():
			if entry.bot: session.remove_bot(entry.id)
		for i in range(count - 1): session.add_bot(1)
		for i in range(count): session.add_bot(2)
		session.set_ready(true)
		session.start_match()
		var arena := (load("res://scenes/levels/garden/lan_garden.tscn") as PackedScene).instantiate()
		root.add_child(arena)
		await process_frame
		var manager := arena.get_node("DuelManager") as TeamMatchManager
		check(manager.actors.size() == count * 2, "%dv%d actor count" % [count, count])
		var player := arena.get_node("Player") as FirstPersonPlayer
		player.set_physics_process(false)
		player.weapon.set_physics_process(false)
		for actor in manager.actors.values():
			if actor is DuelBot: actor.hit_chance = 0.0
		for tick in range(60 * 40): await physics_frame
		var arrival := 0
		for actor in manager.actors.values():
			if actor is DuelBot and Vector2(actor.global_position.x, actor.global_position.z).length() < 12: arrival += 1
		check(arrival == count * 2 - 1, "%dv%d all bots reach hill neighborhood: %d" % [count,count,arrival])
		manager.set_bots_frozen(true)
		for actor in manager.actors.values():
			if actor is DuelBot: check(not actor.is_physics_processing(), "all bots frozen")
		manager.dev_action("bots_off")
		manager._update_occupancy()
		check(manager.amber_count == 0, "disabled bots don't occupy")
		manager.dev_action("bots_on")
		manager.set_bots_frozen(false)
		var first_enemy: Node3D
		for id in manager.actors:
			if manager.entries[id].team == 2:
				first_enemy = manager.actors[id]
				break
		first_enemy.apply_damage(100)
		manager.dev_action("bots_off")
		check(manager.respawn_remaining.size() == 1, "roster death schedules respawn")
		for tick in range(190): await physics_frame
		check(first_enemy.is_alive, "bot respawns")
		await physics_frame
		check(first_enemy.get_node("CollisionShape3D").disabled and not first_enemy.visible, "disabled bot respawn stays noncolliding and hidden")
		manager.restart_match()
		check(not manager.match_over and manager.respawn_remaining.is_empty(), "restart resets roster lifecycle")
		check(manager.rules.get_team_seconds(1) == 180.0, "restart full clock")
		await physics_frame
		for actor in manager.actors.values():
			if actor is DuelBot:
				check(actor.get_node("CollisionShape3D").disabled and not actor.visible and not actor.is_physics_processing(), "disabled bot restart preserves all disable flags")
		manager.dev_action("bots_on")
		print("TEAM_MATCH %dv%d actors=%d arrivals=%d" % [count,count,manager.actors.size(),arrival])
		session.return_to_lobby()
		arena.queue_free()
		await process_frame
	session.leave_lobby()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("TEAM_MATCH_PASS")
	quit(0 if failures.is_empty() else 1)
