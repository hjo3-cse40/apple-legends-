extends SceneTree

var failures: Array[String] = []
var shots: int = 0
var friendly_shots: int = 0

func _init() -> void:
	call_deferred("run")

func run() -> void:
	Engine.physics_ticks_per_second = 600
	Engine.time_scale = 10.0
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	var scene := load("res://scenes/bots/duel_bot.tscn") as PackedScene
	for size in [1, 2, 3]:
		var actors: Array[Node3D] = []
		shots = 0
		friendly_shots = 0
		for team in [1, 2]:
			for slot in size:
				var bot := scene.instantiate() as DuelBot
				bot.team_id = team
				bot.position = Vector3((slot - 1) * 5.0, 0, -5.0 if team == 1 else 5.0)
				bot.maximum_health = 1000
				bot.magazine_size = 2
				bot.reload_duration = 0.3
				bot.reaction_delay = 0.1
				bot.aim_duration = 0.1
				bot.fire_interval = 0.12
				bot.hit_chance = 1.0
				world.add_child(bot)
				actors.append(bot)
				bot.shot_fired.connect(_record_shot.bind(bot))
		for index in actors.size():
			var bot := actors[index] as DuelBot
			bot.configure_combatants(actors, index % size)
		await physics_frame
		for tick in 240: await physics_frame
		check(shots > 2 * size, "%sv%s must fire and finish reloads" % [size, size])
		check(friendly_shots == 0, "%sv%s must never select a teammate" % [size, size])
		for actor in actors:
			check(actor.get("current_health") < 1000, "%sv%s all bots must participate in combat" % [size, size])
		var survivor := actors[0] as DuelBot
		for actor in actors:
			if actor.team_id != survivor.team_id: actor.set_meta("combat_enabled", false)
		survivor._decision_remaining = 0
		survivor._refresh_target()
		check(not survivor._has_valid_target(), "Disabled enemies must not be targeted even before deferred collision update")
		var disabled := actors[-1] as DuelBot
		check(not disabled.apply_damage(1.0), "Disabled bot must reject damage")
		for actor in actors: actor.set_meta("combat_enabled", true)
		for actor in actors:
			if actor.team_id != survivor.team_id: actor.apply_damage(10000)
		survivor._decision_remaining = 0
		survivor._refresh_target()
		check(not survivor._has_valid_target(), "Dead enemies must not remain valid targets")
		print("Bot team fixture %sv%s: %s shots, %s friendly selections" % [size, size, shots, friendly_shots])
		for actor in actors: actor.queue_free()
		await process_frame
	world.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: 1v1, 2v2, 3v3 team selection, damage, reload, and dead enemy rejection")
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _record_shot(target: Node3D, shooter: DuelBot) -> void:
	shots += 1
	if target.get("team_id") == shooter.team_id: friendly_shots += 1
