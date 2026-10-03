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
	var player := map.get_node("Player") as FirstPersonPlayer
	map.get_node("DuelBot").set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var u: float = map.UNITS_PER_METER
	for i in 4: await physics_frame
	var space := player.get_world_3d().direct_space_state
	# Check floor support in the newly expanded ground, outside the old footprint.
	for x in [-14.0, 0.0, 14.0]:
		for z in [-20.0, 20.0]:
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, .35, z)*u, Vector3(x, -.2, z)*u, 1))
			check(not hit.is_empty(), "Expanded ground must support players at %s/%s" % [x,z])
	# Walk all four continuous ground-to-gallery-to-terrace routes with the real capsule.
	for side in [-1.0, 1.0]:
		for end in [-1.0, 1.0]:
			var yaw: float = 0.0 if end < 0.0 else PI
			player.respawn_at(Transform3D(Basis(Vector3.UP,yaw),Vector3(side*9.5,.25,-end*16)*u))
			for i in 30: await physics_frame
			Input.action_press("move_forward")
			for i in 340: await physics_frame
			Input.action_release("move_forward")
			for i in 12: await physics_frame
			check(player.position.y/u > 1.60 and player.position.y/u < 1.72, "Ground ramp must reach the 1.65m gallery: %s/%s (%s)" % [side,end,player.position/u])
			# Start at the upper-ramp foot. It overlaps the lower deck with no step.
			player.respawn_at(Transform3D(Basis(Vector3.UP,-side*PI/2),Vector3(side*9.25,1.78,-end*5.7)*u))
			for i in 20: await physics_frame
			Input.action_press("move_forward")
			for i in 195: await physics_frame
			Input.action_release("move_forward")
			for i in 12: await physics_frame
			check(absf(player.position.x/u)>13.1 and player.position.y/u>3.25, "Upper ramp must reach the 3.3m terrace: %s/%s (%s)" % [side,end,player.position/u])
	# Central underpasses remain traversable beneath the gallery and upper deck.
	for side in [-1.0,1.0]:
		player.respawn_at(Transform3D(Basis(Vector3.UP,-side*PI/2),Vector3(side*6.7,.3,-1.5)*u))
		for i in 30: await physics_frame
		Input.action_press("move_forward")
		for i in 190: await physics_frame
		Input.action_release("move_forward")
		check(absf(player.position.x/u)>12.5 and player.position.y/u<.1, "Ground underpass must stay open beneath both tiers")
	# Drops from the highest tier land on the lower route and then ground.
	player.respawn_at(Transform3D(Basis(Vector3.UP,PI/2),Vector3(14.5,3.45,1.5)*u))
	for i in 30: await physics_frame
	Input.action_press("move_forward")
	var touched_lower := false
	for i in 260:
		await physics_frame
		if player.is_on_floor() and absf(player.position.y/u-1.65)<.08:touched_lower=true
	Input.action_release("move_forward")
	for i in 25: await physics_frame
	check(touched_lower and player.is_on_floor() and player.position.y/u<.1, "Drop shortcut must land safely on gallery then ground")
	# Measure a real spawn-to-hill walk through the screened dock exit.
	player.respawn_at(map.get_node("PlayerSpawnA").global_transform)
	for i in 30: await physics_frame
	var route_frames := 0
	for waypoint in [Vector3(-6.15,0,19.26)*u, Vector3(-6.15,0,4.5)*u, Vector3(0,0,4.5)*u, Vector3(0,0,1.7)*u]:
		var direction: Vector3 = waypoint-player.position
		player.rotation.y=atan2(-direction.x,-direction.z)
		Input.action_press("move_forward")
		var frames := 0
		while Vector2(player.position.x-waypoint.x,player.position.z-waypoint.z).length()>.35 and frames<500:
			direction=waypoint-player.position
			player.rotation.y=atan2(-direction.x,-direction.z)
			await physics_frame
			frames+=1
		Input.action_release("move_forward")
		route_frames+=frames
		check(frames<500,"Spawn-to-hill route must reach waypoint %s (at %s)" % [waypoint/u, player.position/u])
		for i in 10: await physics_frame
	print("MEASURED spawn-to-hill moving time: %.2fs walking" % (float(route_frames)/Engine.physics_ticks_per_second))
	# Four walking entries must cross the old concentric objective lips.
	for entry in [Vector3(0,0,3),Vector3(0,0,-3),Vector3(3,0,0),Vector3(-3,0,0)]:
		player.respawn_at(Transform3D(Basis.IDENTITY,(entry+Vector3.UP*.25)*u))
		for i in 20: await physics_frame
		Input.action_press("move_forward")
		var frames := 0
		while Vector2(player.position.x,player.position.z).length()>1.2*u and frames<160:
			player.rotation.y=atan2(player.position.x,player.position.z)
			await physics_frame
			frames+=1
		Input.action_release("move_forward")
		check(frames<160, "Walking entry must reach hill from %s" % entry)
	# Newly elevated viewpoints must not have direct fire into any dock.
	for team in ["CYAN", "AMBER"]:
		for index in [1,2,3]:
			var spawn := map.arena.find_child(team+"_SPAWN_"+str(index)+"*",true,false) as Node3D
			for x in [-14.5,-9.5,0.0,9.5,14.5]:
				for z in [-5.7,0.0,5.7]:
					var height: float = 3.72 if absf(x)>12 else (2.07 if absf(x)>8 else .42)
					var query := PhysicsRayQueryParameters3D.create(Vector3(x,height,z)*u,spawn.global_position+Vector3.UP*.42*u,1)
					check(not space.intersect_ray(query).is_empty(),"Spawn exposed from new tier: %s/%s x%s z%s" % [team,index,x,z])
	main.queue_free()
	await process_frame
	if failures.is_empty():print("PASS: expanded floor, four full capsule climbs to both tiers, open underpasses, safe tier drops, timed dock-to-hill walk, four walk-in objective approaches, 90 protected spawn sightlines")
	quit(0 if failures.is_empty() else 1)
