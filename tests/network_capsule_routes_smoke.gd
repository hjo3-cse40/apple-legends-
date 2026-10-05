extends SceneTree
## Compare the real60Hz local controller with20Hz host capsule validation.
const DT := 1.0 / 60.0
var failures: Array[String] = []
var player: FirstPersonPlayer
var remote: RemoteActor
var maximum_error := 0.0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func solid(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	root.add_child(body)
	body.position = at
	return body
func move_local(direction: Vector2) -> void:
	player._movement_input = direction
	player._jump_requested = false
	player._jump_held = false
	player._simulate_movement(DT)
	await physics_frame
func route(from: Vector3, direction: Vector2, ticks: int, title: String, yaw := 0.0) -> float:
	player.respawn_at(Transform3D(Basis(Vector3.UP, yaw), from))
	for tick in 30: await move_local(Vector2.ZERO)
	check(player.is_on_floor(), title + " starts grounded")
	remote.respawn_at(player.global_transform)
	await physics_frame
	var error := 0.0
	for tick in ticks:
		await move_local(direction)
		if tick % 3 == 2 or tick == ticks - 1:
			remote.move_authoritative_pose(player.global_position)
			error = maxf(error, remote.global_position.distance_to(player.global_position))
	maximum_error = maxf(maximum_error, error)
	check(error < 0.08, "%s20Hz host diverged %.5f game units from local capsule" % [title, error])
	return error
func run() -> void:
	if "--fast" in OS.get_cmdline_user_args():
		Engine.physics_ticks_per_second = 600
		Engine.time_scale = 10.0
	var floor_body := solid(Vector3(0, -0.5, 0), Vector3(40, 1, 40))
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	remote = RemoteActor.new()
	root.add_child(remote)
	remote.set_process(false)
	player.add_collision_exception_with(remote)
	remote.add_collision_exception_with(player)
	await process_frame
	for height in [0.05, 0.26, 0.34]:
		var ledge := solid(Vector3(3, height / 2, 0), Vector3(3, height, 4))
		await route(Vector3(0, 0.2, 0), Vector2.RIGHT, 40, "Step%.2f" % height)
		check(remote.position.x > 2 and absf(remote.position.y - height) < 0.03, "Host climbs legal low step")
		ledge.queue_free()
		await process_frame
	var tall := solid(Vector3(3, 0.18, 0), Vector3(3, 0.36, 4))
	await route(Vector3(0, 0.2, 0), Vector2.RIGHT, 60, "Tall ledge")
	check(remote.position.x < 1.4 and remote.position.y < 0.03, "Tall ledge still blocks walking")
	tall.queue_free()
	await process_frame
	var ledge := solid(Vector3(3, 0.13, 0), Vector3(3, 0.26, 4))
	var ceiling := solid(Vector3(1.3, 2, 0), Vector3(6, 0.2, 4))
	await route(Vector3(0, 0.1, 0), Vector2.RIGHT, 50, "Low ceiling")
	check(remote.position.x < 1.4, "Host does not step under insufficient ceiling clearance")
	remote.position = Vector3.ZERO
	remote.move_authoritative_pose(Vector3(3, 0.26, 0))
	check(remote.position.x < 1.4 and remote.position.y < 0.15, "Forged step cannot pass low ceiling")
	ceiling.queue_free()
	ledge.queue_free()
	await process_frame
	var wall := solid(Vector3(2, 1, 0), Vector3(0.2, 4, 8))
	await route(Vector3(0, 0.1, 2), Vector2(1, -1).normalized(), 100, "Diagonal wall slide")
	check(player.position.z < -4 and remote.position.z < -4, "Host preserves travel along actual wall")
	remote.position = Vector3.ZERO
	remote.move_authoritative_pose(Vector3(5, 0.3, 0))
	check(remote.position.x < 1.56, "Low positive-rise request cannot pass tall wall")
	wall.queue_free()
	floor_body.queue_free()
	player.queue_free()
	await process_frame
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var map := main.get_node("MovementLab")
	map.get_node("DuelManager").process_mode = Node.PROCESS_MODE_DISABLED
	for timer_name in ["PlayerRespawnTimer", "BotRespawnTimer"]:
		var timer := map.get_node("DuelManager/" + timer_name) as Timer
		timer.stop()
		timer.process_mode = Node.PROCESS_MODE_DISABLED
	player = map.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	var bot := map.get_node("DuelBot") as CharacterBody3D
	bot.set_physics_process(false)
	bot.collision_layer = 0
	bot.collision_mask = 0
	player.add_collision_exception_with(remote)
	remote.add_collision_exception_with(player)
	var u: float = map.UNITS_PER_METER
	for team in ["CYAN", "AMBER"]:
		for index in [1, 2, 3]:
			var marker := map.arena.find_child(team + "_SPAWN_" + str(index) + "*", true, false) as Node3D
			await route(marker.global_position + Vector3(0, 0.3, 2.4), Vector2(0, -1), 75, "%s spawn%d" % [team, index])
	for side in [-1.0, 1.0]:
		for end in [-1.0, 1.0]:
			var yaw: float = 0 if end < 0 else PI
			await route(Vector3(side * 9.5, 0.25, -end * 16) * u, Vector2(0, -1), 340, "Lower ramp%s/%s" % [side, end], yaw)
			check(remote.position.y / u > 1.60, "Host lower ramp reaches gallery")
			await route(Vector3(side * 9.25, 1.78, -end * 5.7) * u, Vector2(0, -1), 195, "Upper ramp%s/%s" % [side, end], -side * PI / 2)
			check(remote.position.y / u > 3.25, "Host upper ramp reaches terrace")
	main.queue_free()
	remote.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("NETWORK_CAPSULE_ROUTES_PASS:60Hz local/20Hz host, low/near-limit steps, tall obstacle/ceiling safety, wall slide, six authored spawn pads, eight ramps; maximum error=%.6f game units" % maximum_error)
	quit(0 if failures.is_empty() else 1)
