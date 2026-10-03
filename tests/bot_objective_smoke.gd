extends SceneTree
var failures: Array[String] = []
func _init() -> void: call_deferred("run")
func run() -> void:
	Engine.physics_ticks_per_second = 600
	Engine.time_scale = 10.0
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var map := main.get_node("MovementLab")
	var player := map.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	player.collision_layer = 0
	player.position = Vector3(40, 1, 0)
	var bot := map.get_node("DuelBot") as DuelBot
	bot.set_physics_process(false)
	bot.hit_chance = 0.0
	var u: float = map.UNITS_PER_METER
	bot.configure_objective(Vector3(0, .09, 0)*u, map.arena)
	bot.movement_enabled = true
	# Keep match clocks and automatic respawn timers out of this isolated AI fixture.
	var manager := map.get_node_or_null("DuelManager")
	if manager != null:
		manager.process_mode = Node.PROCESS_MODE_DISABLED
		for timer_name in ["PlayerRespawnTimer", "BotRespawnTimer"]:
			var timer := main.find_child(timer_name, true, false) as Timer
			if timer != null:
				timer.stop()
				timer.process_mode = Node.PROCESS_MODE_DISABLED
	for cadence in [60, 120]:
		Engine.physics_ticks_per_second = cadence * 10
		var delta := 1.0 / float(cadence)
		await physics_frame
		for team in ["AMBER", "CYAN"]:
			for dock in [1, 2, 3]:
				var marker := map.arena.find_child(team+"_SPAWN_"+str(dock)+"*",true,false) as Node3D
				bot.respawn_at(marker.global_transform)
				await physics_frame
				var reached := false
				var arrival_seconds := 0.0
				for tick in int(30.0/delta):
					bot._physics_process(delta)
					await physics_frame
					if Vector2(bot.position.x,bot.position.z).length() < .8:
						reached = true
						arrival_seconds = float(tick + 1)*delta
						break
				if not reached:
					for collision_index in bot.get_slide_collision_count():
						var collision := bot.get_slide_collision(collision_index)
						print("Blocked collider: ", collision.get_collider().get_path(), " normal: ", collision.get_normal())
					failures.append("%s dock %s route blocked at %s waypoint %s" % [team, dock, bot.position/u, bot._objective_index])
				print("Objective route %s dock %s at %sHz: %.2fs" % [team, dock, cadence, arrival_seconds])
				# A valid visible enemy outside the hill never changes the hold destination.
				player.position = Vector3(0, 1, 12)*u
				bot.set_target(player)
				for tick in int(3.0/delta):
					bot._physics_process(delta)
					await physics_frame
				if Vector2(bot.position.x,bot.position.z).length() > 1.8*u:
					failures.append("Bot must remain on the objective after arrival")
	Engine.physics_ticks_per_second = 600
	await physics_frame
	# Visible opponent on the hill can be shot without abandoning the objective.
	player.respawn_at(Transform3D(Basis.IDENTITY, bot.position + Vector3(2.0, 0.0, 0.0)))
	player.collision_layer = 1
	await physics_frame
	bot.hit_chance = 1.0
	bot.damage_per_shot = 5.0
	bot.fire_interval = 0.2
	bot.reaction_delay = 0.1
	bot.aim_duration = 0.1
	var starting_health := player.current_health
	for tick in 120:
		bot._physics_process(1.0/60.0)
		await physics_frame
	if player.current_health >= starting_health:
		failures.append("Objective bot must fire at a visible hill opponent")
	if Vector2(bot.position.x,bot.position.z).length() > 1.8*u:
		failures.append("Combat must not pull bot off the hill")
	player.collision_layer = 0
	# Dead bots cannot advance an objective route before respawn.
	bot.apply_damage(bot.maximum_health)
	var dead_position := bot.position
	for tick in 30:
		bot._physics_process(1.0/60.0)
		await physics_frame
	if bot.position != dead_position: failures.append("Dead bot must not navigate")
	bot.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0, .3, 0)*u))
	for tick in 30:
		bot._physics_process(1.0/60.0)
		await physics_frame
	# Frozen movement must preserve position and not chase a target.
	bot.movement_enabled = false
	var frozen := bot.position
	for tick in 60:
		bot._physics_process(1.0/60.0)
		await physics_frame
	if Vector2(bot.position.x-frozen.x,bot.position.z-frozen.z).length() > .01:
		failures.append("F1 movement freeze must stop objective movement")
	main.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: objective bot walks from all six docks, holds hill, respawns and freezes")
	quit(0 if failures.is_empty() else 1)
