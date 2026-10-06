extends SceneTree
## Actual movement/combat trials away from the point, plus purposeful cover.
var failures: Array[String] = []
var world: Node3D
var scene: PackedScene
func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func box(size: Vector3, position: Vector3) -> void:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.position = position
	world.add_child(body)
func run() -> void:
	Engine.physics_ticks_per_second = 600
	Engine.time_scale = 10
	world = Node3D.new()
	root.add_child(world)
	box(Vector3(100, 1, 100), Vector3(0, -.5, 0))
	scene = load("res://scenes/bots/duel_bot.tscn")
	var baseline_path := "res://work/baseline_duel_bot.gd.txt"
	var baseline: GDScript
	if FileAccess.file_exists(baseline_path):
		baseline = GDScript.new()
		baseline.source_code = FileAccess.get_file_as_string(baseline_path).replace("class_name DuelBot\n", "")
		check(baseline.reload() == OK, "Baseline source loads for real comparison")
	var before := await transit_trial(baseline) if baseline != null else {}
	var after := await transit_trial(null)
	if baseline != null:
		check(float(before.lateral_distance) < .01, "Baseline target firing does not alter transit lane")
		check(float(after.lateral_distance) > .5, "Improved transit combat makes actual lateral displacement")
	check(int(after.engage_ticks) > 30 and int(after.shots) > 0, "Improved transit engages while moving/firing")
	check(float(after.objective_progress) > 14, "Urgent transit engagement retains substantial objective progress")
	var defending := await transit_trial(null, 1)
	check(float(defending.lateral_distance) > float(after.lateral_distance), "Owned hill permits stronger lateral engagement than urgent capture")
	var behind := await transit_trial(null, 0, Vector3(-18, .02, 5))
	check(float(behind.objective_progress) > 14, "Enemy behind the waypoint cannot cancel objective intent")
	print("TRANSIT_DEFENDING ", JSON.stringify(defending))
	print("TRANSIT_ENEMY_BEHIND ", JSON.stringify(behind))
	if baseline != null: print("TRANSIT_BEFORE ", JSON.stringify(before))
	print("TRANSIT_AFTER ", JSON.stringify(after))
	var waypoint := await occupied_waypoint_trial(null)
	check(int(waypoint.index) == 1 and float(waypoint.progress) > 2.5, "Shared occupied waypoint advances rather than orbiting a teammate")
	if baseline != null:
		var old_waypoint := await occupied_waypoint_trial(baseline)
		check(int(old_waypoint.index) == 0, "Baseline tight arrival radius reproduces blocked shared waypoint")
		print("OCCUPIED_WAYPOINT_BEFORE ", JSON.stringify(old_waypoint))
	print("OCCUPIED_WAYPOINT_AFTER ", JSON.stringify(waypoint))
	await cover_trial()
	world.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: transit engagement changes real path/fires, objective progress, persistent real cover outside hill")
	quit(0 if failures.is_empty() else 1)
func transit_trial(baseline: GDScript, owner: int = 0, enemy_position: Vector3 = Vector3(-5, .02, -9)) -> Dictionary:
	var bot: Node3D = scene.instantiate()
	if baseline != null: bot.set_script(baseline)
	var enemy: DuelBot = scene.instantiate()
	bot.set("team_id", 1)
	enemy.team_id = 2
	bot.position = Vector3(-12, .02, 0)
	enemy.position = enemy_position
	world.add_child(bot)
	world.add_child(enemy)
	bot.set_physics_process(false)
	enemy.set_physics_process(false)
	enemy.current_health = 10000
	bot.set("movement_enabled", true)
	bot.call("configure_combatants", [bot, enemy] as Array[Node3D], 0)
	bot.call("set_difficulty", 1)
	bot.set("hit_chance", 0)
	bot.call("configure_objective", Vector3(35, 0, 0), world)
	bot.call("set_tactical_context", owner, false)
	bot.set("_objective_route", [Vector3(35, 0, 0)] as Array[Vector3])
	bot.get("_random").seed = 173
	bot.set("_jump_remaining", 100)
	var shots: Array[int] = [0]
	bot.connect("shot_fired", func(_target: Node3D): shots[0] += 1)
	var start := bot.position
	var lateral := 0.0
	var engage_ticks := 0
	for tick in 180:
		bot.call("_physics_process", 1.0 / 60)
		lateral = maxf(lateral, absf(bot.position.z))
		if bot.get("behavior_state") in ["flank", "engage"]: engage_ticks += 1
		await physics_frame
	var result := {"lateral_distance": lateral, "objective_progress": bot.position.x - start.x, "engage_ticks": engage_ticks, "shots": shots[0]}
	bot.queue_free()
	enemy.queue_free()
	await process_frame
	return result
func cover_trial() -> void:
	box(Vector3(1, 2.5, .4), Vector3(-2.2, 1.25, 0))
	var bot := scene.instantiate() as DuelBot
	var enemy := scene.instantiate() as DuelBot
	bot.team_id = 1
	enemy.team_id = 2
	bot.position = Vector3(0, .02, 0)
	enemy.position = Vector3(0, .02, -10)
	world.add_child(bot)
	world.add_child(enemy)
	enemy.set_physics_process(false)
	bot.movement_enabled = true
	bot.configure_combatants([bot, enemy], 2)
	bot.configure_objective(Vector3(40, 0, 0), world)
	bot.set_target(enemy)
	bot.ammo_in_magazine = 0
	bot.reload_duration = 3
	for tick in 4: await physics_frame
	check(bot._has_cover and bot.reloading, "Reload during transit finds capsule-reachable real cover")
	var goal := bot._cover_position
	var initial := bot.global_position.distance_to(goal)
	# Losing sight/target must not abandon the already verified cover goal.
	enemy.set_meta("combat_enabled", false)
	bot.set_target(null)
	for tick in 45: await physics_frame
	check(bot.reloading and bot._has_cover and bot.global_position.distance_to(goal) < initial - .5, "Reload persists toward cover after target leaves sight")
	bot.queue_free()
	enemy.queue_free()
	await process_frame

func occupied_waypoint_trial(baseline: GDScript) -> Dictionary:
	var bot: Node3D = scene.instantiate()
	if baseline != null: bot.set_script(baseline)
	var enemy := scene.instantiate() as DuelBot
	var ally := scene.instantiate() as DuelBot
	bot.set("team_id", 1)
	ally.team_id = 1
	enemy.team_id = 2
	bot.position = Vector3(-12, .02, 0)
	ally.position = Vector3(-10, .02, 0)
	enemy.position = Vector3(-15, .02, 5)
	for actor: Node3D in [bot, ally, enemy]:
		world.add_child(actor)
		actor.set_physics_process(false)
	bot.set("movement_enabled", true)
	bot.call("configure_combatants", [bot, ally, enemy] as Array[Node3D], 0)
	bot.call("set_difficulty", 1)
	bot.set("hit_chance", 0)
	bot.call("configure_objective", Vector3(20, 0, 0), world)
	bot.set("_objective_route", [Vector3(-10, 0, 0), Vector3(20, 0, 0)] as Array[Vector3])
	bot.get("_random").seed = 173
	bot.set("_jump_remaining", 100)
	for tick in 180:
		bot.call("_physics_process", 1.0 / 60)
		await physics_frame
	var result := {"index": bot.get("_objective_index"), "progress": bot.position.x + 12, "position": str(bot.position)}
	for actor: Node3D in [bot, ally, enemy]: actor.queue_free()
	await process_frame
	return result
