extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func run() -> void:
	Engine.physics_ticks_per_second = 600
	Engine.time_scale = 10.0
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := make_box(world, Vector3(60, 1, 60), Vector3(0, -0.5, 0))
	var scene := load("res://scenes/bots/duel_bot.tscn") as PackedScene
	var bot := scene.instantiate() as DuelBot
	var enemy := scene.instantiate() as DuelBot
	bot.movement_enabled = true
	bot.position = Vector3(-10, 0.05, 0)
	enemy.team_id = 1
	enemy.position = Vector3(5, 0.05, 0)
	world.add_child(bot)
	world.add_child(enemy)
	enemy.set_physics_process(false)
	bot.configure_combatants([bot, enemy], 0)
	bot.configure_objective(Vector3(20, 0, 0), world)
	bot.set_difficulty(0)
	bot.set_physics_process(false)
	for tick in 80:
		bot._physics_process(1.0 / 60.0)
		await physics_frame
	check(Vector3(bot.velocity.x, 0, bot.velocity.z).length() <= 4.6, "Simple bots remain walking speed")
	check(not bot.sprinting, "Simple bots do not sprint")
	check(not bot._should_tactical_jump(Vector3(6, 0, 0)), "Simple bots do not tactical jump")
	bot.set_difficulty(1)
	enemy.set_meta("combat_enabled", false)
	enemy.position = Vector3(0, 0, -20)
	bot._target = null
	for tick in 60:
		bot._physics_process(1.0 / 60.0)
		await physics_frame
	check(bot.sprinting and Vector3(bot.velocity.x, 0, bot.velocity.z).length() > 8, "Normal bot actually accelerates to sprint on travel")
	bot.position = Vector3(0, 0.02, 0)
	bot.velocity = Vector3.ZERO
	enemy.position = Vector3(8, 0, 0)
	enemy.set_meta("combat_enabled", true)
	bot.set_target(enemy)
	bot.objective_enabled = false
	for tick in 5:
		bot._update_movement(1.0 / 60.0)
		await physics_frame
	check(bot.is_on_floor(), "Jump fixture bot starts grounded")
	check(bot._jump_path_is_safe(Vector3(4, 0, 0)), "Supported clear floor permits tactical hop")
	var ceiling := make_box(world, Vector3(10, 0.5, 10), Vector3(0, 2.2, 0))
	await physics_frame
	check(not bot._jump_path_is_safe(Vector3(4, 0, 0)), "Full capsule hop rejects low ceiling")
	ceiling.queue_free()
	await physics_frame
	bot.position = Vector3(29, 0, 0)
	check(not bot._jump_path_is_safe(Vector3(7, 0, 0)), "Hop refuses unsupported landing beyond floor")
	bot.position = Vector3.ZERO
	bot.velocity = Vector3(4, 0, 0)
	bot._jump_remaining = 10
	for tick in 5:
		bot._update_movement(1.0 / 60.0)
		await physics_frame
	bot._jump_remaining = 0
	bot._update_movement(1.0 / 60.0)
	await physics_frame
	bot._jump_remaining = 0
	bot._update_movement(1.0 / 60.0)
	check(bot.velocity.y > 0, "Normal bot launches a real physics jump during combat")
	bot.position = Vector3.ZERO
	bot.movement_enabled = false
	enemy.position = Vector3(8, 0, 0)
	enemy.current_health = 10000
	var shot_counts: Array[int] = []
	var shots: Array[int] = [0]
	bot.shot_fired.connect(func(_target: Node3D): shots[0] += 1)
	for level in [0, 1, 2]:
		bot.set_difficulty(level)
		bot._random.seed = 43
		bot._target = enemy
		bot._visible_target_time = 0
		bot._aim_time = 0
		bot._fire_cooldown = 0
		bot.ammo_in_magazine = bot.magazine_size
		bot.reloading = false
		shots[0] = 0
		for tick in 360:
			bot._physics_process(1.0 / 60.0)
			await physics_frame
		shot_counts.append(shots[0])
	check(shot_counts[0] < shot_counts[1] and shot_counts[1] < shot_counts[2], "Actual perceived combat cadence scales through all three difficulties")
	print("Difficulty combat six seconds, Simple/Normal/Expert shots: ", shot_counts)
	bot.set_difficulty(2)
	check(bot.reaction_delay < 0.45 and bot.hit_chance > 0.65 and bot.hit_chance < 1.0, "Expert faster but imperfect")
	bot.respawn_at(Transform3D(Basis.IDENTITY, Vector3.ZERO))
	check(bot.velocity == Vector3.ZERO and bot._jump_remaining > 0, "Respawn clears momentum and postpones fresh hop")
	var panel := DeveloperPanel.new()
	root.add_child(panel)
	panel.open_panel(false)
	check(not panel.difficulty_slider.editable, "Joining player cannot change host bot difficulty")
	panel.open_panel(true)
	var request: Array = []
	panel.action_requested.connect(func(action: String, value: int): request.assign([action, value]))
	panel.difficulty_slider.value = 2
	check(request == ["bot_difficulty", 2], "Difficulty scale dispatches host action")
	panel.queue_free()
	floor_body.queue_free()
	world.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: difficulty speed, sprint, real combat jump, ceiling/edge safety, expert tuning, respawn, host slider")
	quit(0 if failures.is_empty() else 1)

func make_box(world: Node3D, size: Vector3, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	body.position = position
	world.add_child(body)
	return body

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
