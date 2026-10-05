extends SceneTree
## Regression for acknowledgement history and timestamp interpolation.
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func run() -> void:
	var session := root.get_node("LanSession")
	session.set_local_generation(0)
	# Delayed acknowledgements during 30m/s local travel must never pull the
	# player back to an older, perfectly valid server position.
	for sample in range(1, 101):
		session._pose_history[sample] = Vector3(sample * 1.5, 0, 0)
		if sample > 4:
			var acknowledged := sample - 4
			check(session.reconcile_pose(acknowledged, Vector3(acknowledged * 1.5, 0, 0)).is_zero_approx(), "delayed valid pose preserves live momentum")
	# One actual wall correction, with two newer samples already in flight.
	session.set_local_generation(0)
	session._pose_history = {1: Vector3(1, 0, 0), 2: Vector3(2, 0, 0), 3: Vector3(3, 0, 0)}
	check(session.reconcile_pose(1, Vector3(0.5, 0, 0)).is_equal_approx(Vector3(-0.5, 0, 0)), "actual blocked motion corrects once")
	check(session.reconcile_pose(2, Vector3(2, 0, 0)).is_equal_approx(Vector3(0.5, 0, 0)), "later unconstrained server pose cancels previous correction")
	check(session.reconcile_pose(2, Vector3.ZERO).is_zero_approx(), "duplicate ack ignored")
	check(session.reconcile_pose(3, Vector3(3.01, 0, 0)).is_zero_approx(), "subthreshold physics margin ignored without phantom correction")
	session.set_local_generation(1)
	check(session._pose_history.is_empty() and session.reconcile_pose(3, Vector3.ZERO).is_zero_approx(), "respawn clears previous-life history")
	var actor := RemoteActor.new()
	root.add_child(actor)
	actor.set_process(false)
	actor.interpolate = true
	# Irregular receipt of regular 20Hz host samples: presentation remains
	# exactly20m/s once the100ms buffer has filled, even between packet arrivals.
	var arrivals := [0.0, 0.07, 0.09, 0.16, 0.23, 0.25, 0.31, 0.34, 0.41]
	var next := 0
	var maximum_error := 0.0
	for tick in range(1, 41):
		var elapsed := tick * 0.01
		while next < arrivals.size() and float(arrivals[next]) <= elapsed:
			actor.apply_snapshot({"position": Vector3(next * 1.0, 0, 0), "yaw": 0.0, "generation": 0}, 1.0 + next * 0.05)
			next += 1
		actor._interpolate_presentation(0.01)
		var expected := maxf(0.0, elapsed - 0.10) * 20.0
		maximum_error = maxf(maximum_error, absf(actor.global_position.x - expected))
	check(maximum_error < 0.001, "timestamp buffer smooths uneven arrivals: %.6fm" % maximum_error)
	actor.apply_snapshot({"position": Vector3(6, 0, 0), "yaw": 1.0, "generation": 1}, 2.0)
	check(actor.global_position.is_equal_approx(Vector3(6, 0, 0)) and actor._samples.size() == 1, "nearby respawn flushes old interpolation history")
	# Exercise the real remote capsule against a static wall, then acknowledge
	# the collision-swept result through the production reconciliation path.
	actor.interpolate = false
	actor.global_position = Vector3.ZERO
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 4.0, 4.0)
	shape.shape = box
	wall.add_child(shape)
	root.add_child(wall)
	wall.position = Vector3(2, 1, 0)
	await physics_frame
	actor.move_and_collide(Vector3(5, 0, 0))
	check(actor.global_position.x < 1.56 and actor.global_position.x > 1.45, "host capsule sweep prevents crossing actual static wall")
	session.set_local_generation(0)
	session._pose_history[1] = Vector3(5, 0, 0)
	var corrected: Vector3 = Vector3(5, 0, 0) + session.reconcile_pose(1, actor.global_position)
	check(corrected.is_equal_approx(actor.global_position), "authoritative wall collision still corrects client")
	wall.queue_free()
	actor.queue_free()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("NETWORK_MOTION_PASS:100 delayed high-speed acknowledgements, collision correction, duplicate/respawn history, uneven20Hz interpolation error=%.6fm" % maximum_error)
	quit(0 if failures.is_empty() else 1)
