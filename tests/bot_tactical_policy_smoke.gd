extends SceneTree
## Bounded tactical requests: no hidden knowledge or shadow simulation mutations.
var failures: Array[String] = []
var world: Node3D
var bot: DuelBot
var enemy: DuelBot
var hidden: DuelBot
var scene: PackedScene
func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func box(size: Vector3, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.position = position
	world.add_child(body)
	return body
func state() -> Array:
	return [bot.position, bot.velocity, bot._random.state, bot._fire_cooldown, bot._reload_remaining, bot._cover_remaining, bot._strafe_direction, bot._decision_remaining, bot._objective_index, bot._goal_best_distance, bot.reloading, bot._has_cover, bot.tactical_policy_action]
func reset(position: Vector3 = Vector3(-12, .02, 0), target_position: Vector3 = Vector3(0, .02, -10)) -> void:
	bot.respawn_at(Transform3D(Basis.IDENTITY, position))
	enemy.position = target_position
	bot.configure_combatants([bot, enemy, hidden], 0)
	bot.set_difficulty(1)
	bot.set_tactical_context(1, false)
	bot._random.seed = 173
	bot.configure_objective(Vector3(30, 0, 0), world)
	bot._objective_route = [Vector3(30, 0, 0)]
	bot._jump_remaining = 100
	bot.set_target(enemy)
	for tick in 5:
		bot._update_movement(1.0 / 60)
		await physics_frame
	bot.velocity = Vector3.ZERO
func run() -> void:
	Engine.physics_ticks_per_second = 600
	Engine.time_scale = 10
	world = Node3D.new()
	root.add_child(world)
	box(Vector3(200, 1, 200), Vector3(0, -.5, 0))
	box(Vector3(2, 4, .5), Vector3(4, 2, 8))
	scene = load("res://scenes/bots/duel_bot.tscn")
	bot = scene.instantiate() as DuelBot
	enemy = scene.instantiate() as DuelBot
	hidden = scene.instantiate() as DuelBot
	bot.team_id = 1
	enemy.team_id = 2
	hidden.team_id = 2
	hidden.position = Vector3(12, .02, 12)
	for actor in [bot, enemy, hidden]:
		world.add_child(actor)
		actor.set_physics_process(false)
	bot.movement_enabled = true
	await reset()
	var pure_before := state()
	var request := bot.build_tactical_request()
	check(request.observation.visible_enemies.size() == 1, "Request contains only actually visible enemy")
	check(request.candidates.size() <= 6, "Model receives bounded candidate list")
	check(request._bindings.has("engage_left") and request._bindings.has("engage_right"), "Visible combat supplies meaningful posture alternatives")
	check(bot.validate_tactical_candidate("engage_left", request), "Shadow validates feasible tactical posture")
	check(state() == pure_before, "Request and shadow validation do not mutate movement, RNG, cover, reload, route or combat")
	var compact := {"observation": request.observation, "candidates": request.candidates, "local_candidate": request.local_candidate}
	check(JSON.parse_string(JSON.stringify(compact)) is Dictionary and not JSON.stringify(compact).contains("_bindings"), "Model-facing state is compact JSON without local goal references")
	check(not bot.apply_tactical_candidate("invent_a_teleport", request), "Invented model action is rejected")
	var left := await posture_trial("engage_left")
	var right := await posture_trial("engage_right")
	check(absf(float(left.z) - float(right.z)) > 1.0, "Selected opposite postures cause different actual swept movement")
	check(float(left.x) > -12 and float(right.x) > -12, "Tactical postures keep forward objective progress")
	print("POLICY_POSTURES left=", left, " right=", right)
	await reset()
	request = bot.build_tactical_request()
	var obstruction := box(Vector3(30, 4, 1), Vector3(-6, 2, -5))
	await physics_frame
	check(not bot.validate_tactical_candidate("engage_left", request) and not bot.apply_tactical_candidate("engage_left", request), "Delayed posture is rejected when its enemy is now hidden")
	obstruction.queue_free()
	await process_frame
	await reset()
	request = bot.build_tactical_request()
	request._guard.issued_msec -= 801
	check(not bot.apply_tactical_candidate("continue_objective", request), "Expired response is rejected")
	request = bot.build_tactical_request()
	bot.clear_tactical_policy()
	check(not bot.apply_tactical_candidate("continue_objective", request), "Mode/freeze clearing invalidates pending responses")
	request = bot.build_tactical_request()
	bot.respawn_at(Transform3D(Basis.IDENTITY, Vector3(-12, .02, 0)))
	check(not bot.apply_tactical_candidate("continue_objective", request), "Previous-life decision cannot affect respawn")
	await reset()
	bot.ammo_in_magazine = 0
	request = bot.build_tactical_request()
	check(not request._bindings.has("engage_left") and not request._bindings.has("engage_right"), "Empty ammo cannot propose engagement")
	check(bot.apply_tactical_candidate("continue_objective", request), "Objective intent remains a feasible bounded choice")
	bot._physics_process(1.0 / 60)
	check(bot.reloading, "Model objective cannot bypass mandatory local reload")
	await reset()
	request = bot.build_tactical_request()
	bot.ammo_in_magazine = 1
	check(not bot.apply_tactical_candidate("engage_left", request), "Stale full-magazine response cannot commit engagement after ammo falls low")
	await defense_trial()
	await cover_trial()
	await route_trial()
	world.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: perceived-only requests, pure shadow, real posture/cover/route control, expiry/life/visibility/geometry guards, local reload and bounded commitments")
	quit(0 if failures.is_empty() else 1)
func posture_trial(candidate: String) -> Vector3:
	await reset()
	var request := bot.build_tactical_request()
	check(bot.apply_tactical_candidate(candidate, request), "Posture applies: " + candidate)
	for tick in 75:
		bot._physics_process(1.0 / 60)
		await physics_frame
	var end := bot.position
	for tick in 60:
		bot._physics_process(1.0 / 60)
		await physics_frame
	check(bot.tactical_policy_remaining <= 0 and bot.tactical_policy_action.is_empty(), "Posture expires after2s; local physics continues")
	return end
func cover_trial() -> void:
	var cover := box(Vector3(1, 2.5, .4), Vector3(-2.2, 1.25, 0))
	await reset(Vector3(0, .02, 0), Vector3(0, .02, -10))
	bot.ammo_in_magazine = 1
	var before := state()
	var request := bot.build_tactical_request()
	check(request._bindings.has("reload_cover"), "Low ammo offers real reachable occluding cover")
	check(state() == before, "Cover proposal is read-only in shadow")
	var goal: Vector3 = request._bindings.reload_cover.goal
	var start := bot.position.distance_to(goal)
	check(bot.apply_tactical_candidate("reload_cover", request), "Verified reload cover applies")
	for tick in 45:
		bot._physics_process(1.0 / 60)
		await physics_frame
	check(bot.reloading and bot.position.distance_to(goal) < start - .5, "Enabled cover action starts actual reload and moves capsule toward cover")
	await reset(Vector3(0, .02, 0), Vector3(0, .02, -10))
	bot.ammo_in_magazine = 1
	request = bot.build_tactical_request()
	var fence := box(Vector3(.4, 3, 3), Vector3(-1, 1.5, 1))
	await physics_frame
	check(not bot.apply_tactical_candidate("reload_cover", request), "Cover response rejected after access becomes blocked")
	fence.queue_free()
	await process_frame
	await reset(Vector3(0, .02, 0), Vector3(0, .02, -10))
	bot.current_health = 25
	request = bot.build_tactical_request()
	check(request._bindings.has("retreat_safe") and bot.apply_tactical_candidate("retreat_safe", request), "Low-health retreat binds a safe escape")
	check(bot._retreat_remaining > 0 and bot._retreat_remaining <= 2, "Retreat bounded by2s")
	cover.queue_free()
	await process_frame
func route_trial() -> void:
	await reset(Vector3(-7.15 / .31, .02, 4.5 / .31), Vector3(0, .02, -30))
	# Restore canonical ground clearance after the manually stepped fixture
	# settles; floor contact remains from the preceding real physics ticks.
	bot.position.y = .02
	bot.route_variant = 0
	bot._objective_position = Vector3.ZERO
	bot._objective_route = [Vector3(-7.15 / .31, 0, 4.5 / .31), Vector3(0, 0, 4.5 / .31), Vector3.ZERO]
	bot._objective_index = 1
	var request := bot.build_tactical_request()
	check(request._bindings.has("entry_side"), "Safe gateway offers alternate authored entry")
	check(bot.apply_tactical_candidate("entry_side", request), "Alternate entry changes executable route suffix at commitment boundary")
	check(bot.route_variant == 1 and bot._objective_route.size() == 4 and bot._objective_route[1].x < -20 and bot._objective_route[1].z < 6, "Chosen entry binds actual side waypoints")
	var before := bot.position
	for tick in 30:
		bot._physics_process(1.0 / 60)
		await physics_frame
	check(bot.position.z < before.z - 1 and absf(bot.position.x - before.x) < 1, "Route choice changes actual movement toward side gateway")
	request = bot.build_tactical_request()
	check(not request._bindings.has("entry_direct") and not request._bindings.has("entry_side"), "After leaving gateway routes stay committed")

func defense_trial() -> void:
	await reset(Vector3(0, .02, 0), Vector3(0, .02, -10))
	bot._objective_position = Vector3.ZERO
	bot._objective_route = [Vector3.ZERO]
	bot._objective_index = 0
	bot.configure_combatants([bot, enemy, hidden], 1)
	bot._objective_route = [Vector3.ZERO]
	bot._objective_index = 0
	bot.set_target(enemy)
	bot._strafe_direction = 1.0
	bot._combat_bias = 0.0
	var base := Vector3.ZERO
	var local_motion := bot._tactical_velocity(base, 1.0 / 60)
	var request := bot.build_tactical_request()
	check(bot.apply_tactical_candidate("continue_objective", request), "Hill defense objective intent applies")
	var selected_motion := bot._tactical_velocity(base, 1.0 / 60)
	check(local_motion.length() > 1.0 and selected_motion.is_equal_approx(local_motion), "Objective defense preserves exact local lateral engagement motion")
	var start := bot.position
	var traveled := 0.0
	for tick in 60:
		var previous := bot.position
		bot._tick_tactical_policy(1.0 / 60)
		bot._update_movement(1.0 / 60)
		await physics_frame
		traveled += bot.position.distance_to(previous)
	check(traveled > 1.0 and bot.position.distance_to(Vector3.ZERO) < 4.8, "Defending objective intent moves actual capsule while retaining hill occupancy")
	print("POLICY_DEFENSE displacement=", bot.position.distance_to(start), " local_velocity=", local_motion, " policy_velocity=", selected_motion)
