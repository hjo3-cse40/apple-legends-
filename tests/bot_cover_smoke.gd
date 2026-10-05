extends SceneTree
## Geometry fixture: cover must block enemy sight while remaining capsule-accessible.
var failures: Array[String] = []
var world: Node3D
var bot: DuelBot
var enemy: DuelBot

func _init() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func block(position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.position = position
	world.add_child(body)
	return body

func reset_bot() -> void:
	bot.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0)))
	bot.configure_combatants([bot, enemy])
	bot.set_target(enemy)
	await physics_frame

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	var floor_body := block(Vector3(0, -.5, 0), Vector3(40, 1, 40))
	# A waist-to-head-height solid wall to the left blocks sight from nearby
	# cover but leaves the bot's present enemy sight and walking route open.
	block(Vector3(-2.2, 1.25, 0), Vector3(1.0, 2.5, .4))
	var scene := load("res://scenes/bots/duel_bot.tscn") as PackedScene
	bot = scene.instantiate() as DuelBot
	enemy = scene.instantiate() as DuelBot
	bot.team_id = 1
	enemy.team_id = 2
	bot.hit_chance = 0.0
	bot.movement_enabled = true
	bot.reload_duration = 2.0
	world.add_child(bot)
	world.add_child(enemy)
	enemy.position = Vector3(0, 0.02, -10)
	enemy.set_physics_process(false)
	await physics_frame
	await reset_bot()
	check(bot._has_line_of_sight(), "Fixture enemy starts visibly exposed")
	bot.ammo_in_magazine = 0
	for tick in 3: await physics_frame
	check(bot.reloading and bot.behavior_state == "reload", "Empty magazine selects actual reload behavior")
	check(bot._has_cover, "Reload finds nearby real geometry cover")
	var cover := bot._cover_position
	var initial_distance := bot.global_position.distance_to(cover)
	var sweep := cover - bot.global_position
	sweep.y = 0
	check(not bot.test_move(bot.global_transform, sweep), "Selected reload cover admits complete capsule travel")
	var query := PhysicsRayQueryParameters3D.create(cover + Vector3.UP * bot.eye_height, enemy.position + Vector3.UP * enemy.eye_height)
	query.exclude = [bot.get_rid()]
	var sight := world.get_world_3d().direct_space_state.intersect_ray(query)
	check(sight.get("collider") is StaticBody3D, "Selected cover genuinely blocks enemy sight")
	for tick in 8: await physics_frame
	check(bot.global_position.distance_to(cover) < initial_distance - .05, "Reload behavior actually moves toward cover")
	await reset_bot()
	bot.apply_damage(75.0)
	for tick in 3: await physics_frame
	check(bot.behavior_state == "retreat" and bot._retreat_remaining > 0, "Low health selects bounded retreat")
	check(bot._has_cover, "Low-health retreat also finds accessible cover")
	# A full-height fence intercepts capsule paths toward the useful cover.
	# Cover sight behind it remains blocked, but cannot be reached directly.
	var fence := block(Vector3(-.95, 1.5, 1.0), Vector3(.35, 3.0, 3.0))
	await physics_frame
	await reset_bot()
	bot.ammo_in_magazine = 0
	for tick in 3: await physics_frame
	check(bot.reloading and not bot._has_cover, "Inaccessible cover is rejected, reload continues with fallback")
	check(bot.velocity.is_finite(), "Inaccessible-cover fallback remains finite")
	fence.queue_free()
	floor_body.queue_free()
	await process_frame
	# Only the current robot's little platform remains. Nearby occluded sample
	# positions have no walkable support and must never become cover goals.
	block(Vector3(0, -.5, 0), Vector3(1.5, 1, 1.5))
	await physics_frame
	await reset_bot()
	bot.ammo_in_magazine = 0
	for tick in 3: await physics_frame
	check(not bot._has_cover and bot.reloading, "Unsupported/no-cover destinations use fallback instead of a cover goal")
	bot.combatants.clear()
	enemy.combatants.clear()
	world.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: reload/low-health reachable cover, real sight occlusion, capsule access, movement, inaccessible and unsupported fallback")
	quit(0 if failures.is_empty() else 1)
