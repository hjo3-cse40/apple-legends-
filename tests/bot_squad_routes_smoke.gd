extends SceneTree

var failures: Array[String] = []

func _init() -> void: call_deferred("run")

func run() -> void:
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
	for tick in 1800: await physics_frame
	for bot in actors:
		var distance := Vector2(bot.position.x, bot.position.z).length()
		print("Squad route team %s slot %s: hill distance %.2f" % [bot.team_id, bot._role_index, distance])
		if distance > 1.8 / .31: failures.append("Bot failed to reach/hold hill: " + str(bot.position))
	for bot in actors: bot.queue_free()
	map.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: six live squad bots navigate both docks and hold capture radius")
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
