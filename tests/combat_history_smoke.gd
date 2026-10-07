extends SceneTree
const History = preload("res://scenes/network/combat_history.gd")
var failures: Array[String] = []
func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func add_actor(world: Node3D, name_value: String, position_value: Vector3, team: int) -> RemoteActor:
	var actor := RemoteActor.new()
	actor.name = name_value
	world.add_child(actor)
	actor.set_team(team)
	actor.position = position_value
	var head := CombatHitbox.new()
	head.name = "CombatHead"
	head.actor = actor
	actor.add_child(head)
	actor.set_process(false)
	return actor
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var shooter := add_actor(world, "Shooter", Vector3(0, 0, 10), 1)
	var target := add_actor(world, "Human", Vector3.ZERO, 2)
	var ally := add_actor(world, "Ally", Vector3(20, 0, 5), 1)
	var actors := {"shooter": shooter, "human": target, "ally": ally}
	var generations := {"shooter": 0, "human": 0, "ally": 0}
	await create_timer(0.6).timeout
	var history := History.new()
	var now := Time.get_ticks_msec() / 1000.0
	# Identical20Hz snapshots feed the real client interpolation and host history.
	var proxy := RemoteActor.new()
	world.add_child(proxy)
	proxy.interpolate = true
	proxy.set_process(false)
	proxy.collision_layer = 0
	proxy._shape.disabled = true
	var baseline_hits := 0
	var corrected_hits := 0
	var cases := 0
	for speed in [6.0, 12.0, 20.0]:
		for delay in [0.10, 0.20, 0.30]:
			history.samples.clear()
			proxy.respawn_at(Transform3D.IDENTITY)
			for index in range(9):
				var sample_time := now - 0.40 + index * 0.05
				target.position = Vector3(speed * index * 0.05, 0, 0)
				history.record(actors, generations, sample_time)
				proxy.apply_snapshot({"position": target.position, "yaw": 0.0, "generation": 0}, sample_time)
			proxy._timeline_time = now - delay + RemoteActor.INTERPOLATION_DELAY
			proxy._interpolate_presentation(0)
			await physics_frame
			var origin := Vector3(proxy.position.x, 1.3, 10)
			var query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.FORWARD * 20)
			query.exclude = [shooter.get_rid(), ally.get_rid(), proxy.get_rid()]
			var baseline := world.get_world_3d().direct_space_state.intersect_ray(query)
			if not baseline.is_empty() and baseline.collider == target: baseline_hits += 1
			var before := target.position
			var views := {"human": {"time": proxy.presentation_time, "generation": 0}}
			# Use host clock independent of wall time spent waiting for each physics tick.
			var hit := history.intersect_view(world.get_world_3d(), actors, generations, "shooter", origin, Vector3.FORWARD, 20, views)
			if not hit.is_empty() and hit.collider == target: corrected_hits += 1
			check(target.position == before and target.current_health == 100, "rewind leaves live pose and health untouched")
			cases += 1
			# Keep synthetic timestamps relative to real host time for bounded age.
			now = Time.get_ticks_msec() / 1000.0
	check(baseline_hits == 0 and corrected_hits == cases, "moving rendered human targeted: baseline0/%d vs fixed%d/%d" % [cases, corrected_hits, cases])
	# Current host hits need no rewind; use actual Area/capsule physics geometry.
	target.position = Vector3.ZERO
	await physics_frame
	var origin := Vector3(0.25, 1.80, 10)
	var head_query := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.FORWARD * 20)
	head_query.exclude = [shooter.get_rid(), shooter.get_node("CombatHead").get_rid(), proxy.get_rid()]
	head_query.collide_with_areas = true
	var head_hit := world.get_world_3d().direct_space_state.intersect_ray(head_query)
	check(not head_hit.is_empty() and head_hit.collider == target.get_node("CombatHead"), "host hits visible human upper helmet")
	head_query.from.x = 0.6
	head_query.to.x = 0.6
	check(world.get_world_3d().direct_space_state.intersect_ray(head_query).is_empty(), "deliberately wide head shot misses")
	# Fresh controlled history with wall, nearer teammate, lifetime and age guards.
	now = Time.get_ticks_msec() / 1000.0
	history.samples.clear()
	for time in [now - 0.20, now - 0.10, now]: history.record(actors, generations, time)
	var views := {"human": {"time": now - 0.1, "generation": 0}}
	origin = Vector3(0, 1.3, 10)
	check(not history.intersect_view(world.get_world_3d(), actors, generations, "shooter", origin, Vector3.FORWARD, 20, views).is_empty(), "fresh history hits")
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 3, 0.2)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	world.add_child(wall)
	wall.position = Vector3(0, 1.5, 5)
	await physics_frame
	check(history.intersect_view(world.get_world_3d(), actors, generations, "shooter", origin, Vector3.FORWARD, 20, views).is_empty(), "world wall occludes rewound human")
	wall.queue_free()
	await physics_frame
	ally.position = Vector3(0, 0, 5)
	history.record(actors, generations, now + 0.001)
	await physics_frame
	var ally_hit := history.intersect_view(world.get_world_3d(), actors, generations, "shooter", origin, Vector3.FORWARD, 20, views)
	check(not ally_hit.is_empty() and ally_hit.collider == ally, "nearer teammate blocks enemy")
	views.ally = {"time": -1.0, "generation": 0}
	check(history.intersect_view(world.get_world_3d(), actors, generations, "shooter", origin, Vector3.FORWARD, 20, views).is_empty(), "invalid ally view cannot remove blocker")
	ally.position.x = 20
	check(not history.intersect_view(world.get_world_3d(), actors, generations, "shooter", origin, Vector3.FORWARD, 20, views).is_empty(), "unrelated stale/off-ray actor does not invalidate enemy hit")
	views.erase("ally")
	generations.human = 1
	check(history.intersect_view(world.get_world_3d(), actors, generations, "shooter", origin, Vector3.FORWARD, 20, views).is_empty(), "old-life shot cannot damage respawn")
	var fresh := Time.get_ticks_msec() / 1000.0
	history.record(actors, generations, fresh)
	check(history.position_at("human", {"time": fresh, "generation": 1}, 1, fresh) == target.position, "first new-life exact snapshot accepted")
	check(history.position_at("human", {"time": fresh - 1, "generation": 1}, 1, fresh) == null, "old view beyond budget rejected")
	check(history.position_at("human", {"time": fresh + 1, "generation": 1}, 1, fresh) == null, "future view rejected")
	check(history.position_at("human", {"time": Vector3.ZERO, "generation": 1}, 1, fresh) == null, "malformed timestamp rejected")
	target.apply_damage(100)
	await physics_frame
	check(target.get_node("CombatHead").collision_layer == 0, "dead head cannot block shots")
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("COMBAT_HISTORY_PASS: visible moving humans baseline%d/%d fixed%d/%d;100/200/300ms views,6/12/20units/s; stationary helmet, outside miss, wall, ally, generation, exact respawn, age/type guards, live-state preservation" % [baseline_hits, cases, corrected_hits, cases])
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
