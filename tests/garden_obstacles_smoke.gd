extends SceneTree
var failures: Array[String] = []
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func run() -> void:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var map := main.get_node("MovementLab")
	# Isolate geometry/input checks from round clocks and delayed respawns.
	map.get_node("DuelManager").process_mode = Node.PROCESS_MODE_DISABLED
	for timer_name in ["PlayerRespawnTimer", "BotRespawnTimer"]:
		var timer := map.get_node("DuelManager/"+timer_name) as Timer
		timer.stop()
		timer.process_mode = Node.PROCESS_MODE_DISABLED
	var player := map.get_node("Player") as FirstPersonPlayer
	map.get_node("DuelBot").set_physics_process(false)
	for i in 3: await physics_frame
	var space := player.get_world_3d().direct_space_state
	var audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/maps/garden_circuit/obstacle-audit.json"))
	var tested := 0
	for obstacle in audit.obstacles:
		var p: Array = obstacle.point
		var n: Array = obstacle.normal
		var point: Vector3 = Vector3(p[0], p[2], -p[1]) * map.UNITS_PER_METER
		var normal := Vector3(n[0], n[2], -n[1])
		for side in [1.0, -1.0]:
			# Exact art lives on query layer 2 where the hill uses cheap capsule geometry.
			var query := PhysicsRayQueryParameters3D.create(point + normal * 0.01 * side, point - normal * 0.01 * side, 3)
			var hit := space.intersect_ray(query)
			check(not hit.is_empty(), "Missing obstacle collision (%s): %s" % [side, obstacle.source])
		tested += 1
	# Follow an open paving lane across five module seams with real player motion.
	player.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 20)))
	for i in 30: await physics_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.action_press("move_forward")
	var low := player.position.y
	var high := low
	for i in 80:
		await physics_frame
		low = minf(low, player.position.y)
		high = maxf(high, player.position.y)
	Input.action_release("move_forward")
	check(high - low < 0.005, "Floor collider must stay level across decorative tile seams")
	# Approach the authored cyan ceramic basin with the actual player capsule.
	var planter: Dictionary = {}
	for obstacle in audit.obstacles:
		if obstacle.source == "CYAN approach planter • ceramic basin":
			planter = obstacle
	check(not planter.is_empty(), "Planting audit must include ceramic basins")
	var minimum: Array = planter.bounds.min
	var maximum: Array = planter.bounds.max
	var center_x: float = (minimum[0] + maximum[0]) * 0.5 * map.UNITS_PER_METER
	var front_z: float = -minimum[1] * map.UNITS_PER_METER
	player.respawn_at(Transform3D(Basis.IDENTITY, Vector3(center_x, 0.6, front_z + 4)))
	for i in 30: await physics_frame
	Input.action_press("move_forward")
	for i in 90: await physics_frame
	Input.action_release("move_forward")
	check(player.position.z > front_z, "Player must stop at the ceramic planter instead of crossing it")
	main.queue_free()
	await process_frame
	if failures.is_empty(): print("PASS: %d authored obstacle faces block rays from both sides, level paving traversal, capsule blocked by solid planter" % tested)
	quit(0 if failures.is_empty() else 1)
