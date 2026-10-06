extends SceneTree

var failures: Array[String] = []
var difficulty: int = 1

func _init() -> void: call_deferred("run")

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--difficulty="):
			difficulty = clampi(int(argument.trim_prefix("--difficulty=")), 0, 2)
	Engine.physics_ticks_per_second = 600
	Engine.time_scale = 10.0
	var map := Node3D.new()
	root.add_child(map)
	var arena := (load("res://art/maps/garden_circuit/GardenCircuit.glb") as PackedScene).instantiate() as Node3D
	arena.scale = Vector3.ONE / .31
	map.add_child(arena)
	add_collision(arena)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(32, .2, 44) / .31
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0, -.085, 0) / .31
	map.add_child(floor_body)
	var scene := load("res://scenes/bots/duel_bot.tscn") as PackedScene
	var actors: Array[Node3D] = []
	for team in [1, 2]:
		for slot in 3:
			var bot := scene.instantiate() as DuelBot
			bot.team_id = team
			bot.set_difficulty(difficulty)
			bot.hit_chance = 0.0
			bot.movement_enabled = true
			map.add_child(bot)
			var prefix := "CYAN" if team == 1 else "AMBER"
			var marker := arena.find_child(prefix + "_SPAWN_" + str(slot + 1) + "*", true, false) as Node3D
			bot.respawn_at(marker.global_transform)
			bot.configure_objective(Vector3(0, .09, 0) / .31, arena)
			actors.append(bot)
	for index in actors.size():
		actors[index].configure_combatants(actors, index % 3)
		actors[index].detection_range = .1
	for variant in [0, 1]:
		var reached: Dictionary = {}
		for index in actors.size():
			var actor := actors[index] as DuelBot
			var prefix := "CYAN" if actor.team_id == 1 else "AMBER"
			var marker := arena.find_child(prefix + "_SPAWN_" + str(index % 3 + 1) + "*", true, false) as Node3D
			actor.respawn_at(marker.global_transform)
			actor.route_variant = variant
			actor._build_objective_route()
		for tick in 2400:
			await physics_frame
			for index in actors.size():
				var actor := actors[index] as DuelBot
				var distance := Vector2(actor.position.x, actor.position.z).length()
				if actor.position.y < -1: failures.append("Route fell through/out of map")
				if distance < 1.8 / .31 and not reached.has(index): reached[index] = float(tick) / 60.0
			if reached.size() == 6 and tick > 1800: break
		for index in actors.size():
			var actor := actors[index] as DuelBot
			var distance := Vector2(actor.position.x, actor.position.z).length()
			print("ENTRY_ROUTE variant%s team%s slot%s firsthill%s finaldistance%.2f" % [variant, actor.team_id, index % 3, reached.get(index, -1), distance])
			if not reached.has(index) or distance > 1.8 / .31: failures.append("Ground entry failed reach/hold: %s" % actor.position)
			if actor.route_variant != variant: failures.append("Route changed without a new life/difficulty")
	for bot in actors: bot.queue_free()
	map.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: both ground entry routes from all six docks, real capsule movement, held capture radius, stable per-life route")
	quit(0 if failures.is_empty() else 1)

func add_collision(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		var extras: Dictionary = mesh.get_meta("extras", {})
		if bool(extras.get("collision_only", false)) or (not "Planting" in mesh.name and not "Signage" in mesh.name and not "Ground" in mesh.name):
			var shape := mesh.mesh.create_trimesh_shape()
			shape.backface_collision = true
			var body := StaticBody3D.new()
			var collider := CollisionShape3D.new()
			collider.shape = shape
			body.add_child(collider)
			mesh.add_child(body)
	for child in node.get_children():
		if not child is StaticBody3D: add_collision(child)
