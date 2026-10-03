extends SceneTree

const DT := 1.0 / 60.0
var failures: Array[String] = []
var player: FirstPersonPlayer

func _init() -> void: call_deferred(&"run")

func step(direction: Vector2 = Vector2.ZERO, held: bool = false, jump: bool = false) -> void:
	player._movement_input = direction
	player._jump_held = held
	player._jump_requested = jump
	player._simulate_movement(DT)
	await physics_frame

func reset(at: Vector3 = Vector3(0, 0.2, 6)) -> void:
	player.respawn_at(Transform3D(Basis.IDENTITY, at))
	for i in 15: await step()
	check(player.is_on_floor(), "test starts grounded")

func jump_peak(hold_frames: int) -> float:
	await reset()
	await step(Vector2.ZERO, hold_frames > 0, true)
	var peak := player.position.y
	for i in 200:
		await step(Vector2.ZERO, i < hold_frames)
		peak = maxf(peak, player.position.y)
	check(player.is_on_floor(), "jump returns to ground even while Space stays held")
	return peak

func land_on(at: Vector3, top: float, offset: float) -> void:
	await reset(at + Vector3(-offset, 0.2, 0))
	await step(Vector2.ZERO, true, true)
	# Rise clear of the side before traversing onto the actual prop collider.
	for i in 30: await step(Vector2.ZERO, true)
	var landed := false
	for i in 190:
		# Countersteer to brake retained air momentum over a narrow platform.
		var desired_velocity := clampf((at.x - player.position.x) * 4.0, -player.walk_speed, player.walk_speed)
		var direction := Vector2.ZERO
		if player.velocity.x < desired_velocity - 0.15: direction = Vector2.RIGHT
		elif player.velocity.x > desired_velocity + 0.15: direction = Vector2.LEFT
		await step(direction, true)
		if player.is_on_floor() and absf(player.position.y - top) < 0.08:
			landed = true
	check(landed, "held jump lands on prop at height %.2f" % top)
	check(absf(player.position.y - top) < 0.08, "player remains standing on prop")

func run() -> void:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	# Keep accepted calibration measurements independent of the default arena.
	main.get_node("MovementLab").free()
	var baseline := (load("res://scenes/levels/calibration/calibration_bay.tscn") as PackedScene).instantiate()
	baseline.name = "MovementLab"
	main.add_child(baseline)
	root.add_child(main)
	await process_frame
	player = main.get_node("MovementLab/Player") as FirstPersonPlayer
	main.get_node("MovementLab/DuelBot").set_physics_process(false)
	player.set_physics_process(false)
	await reset()
	player._update_sprint_input(true, 0.08)
	check(player.is_sprinting, "Shift press immediately sprints")
	player._update_sprint_input(false, DT)
	check(player.sprint_toggled and player.is_sprinting, "short tap latches sprint")
	for i in 30: await step(Vector2(0, -1))
	check(Vector2(player.velocity.x, player.velocity.z).length() > player.walk_speed, "latched sprint drives actual movement speed")
	player._update_sprint_input(true, 0.08)
	player._update_sprint_input(false, DT)
	check(not player.is_sprinting, "second tap turns sprint off")
	player._update_sprint_input(true, 0.4)
	check(player.is_sprinting, "long hold still sprints")
	player._update_sprint_input(false, DT)
	check(not player.is_sprinting, "releasing long hold restores walking")
	player.sprint_toggled = true
	player._update_sprint_input(true, 0.4)
	player._update_sprint_input(false, DT)
	check(player.sprint_toggled, "hold preserves existing toggle state")
	player._release_mouse()
	check(not player.is_sprinting, "focus/capture release clears sprint")
	var tap := await jump_peak(0)
	var medium := await jump_peak(10)
	var near_full := await jump_peak(20)
	var full := await jump_peak(1000)
	print("JUMP HEIGHTS: tap=", tap, " medium=", medium, " full=", full)
	check(tap > 1.2 and medium > tap + 0.5 and full > medium + 1.0, "hold duration controls jump height")
	check(near_full > medium and full - near_full < 0.4, "height approaches the full hold smoothly")
	check(full > 5.0 and full < 7.0, "full jump clears props without infinite lift")
	await land_on(Vector3(-9, 0, 3.7), 1.285, 2.5)
	await land_on(Vector3(-8, 0, 10), 1.4 * 1.7, 2.0)
	await land_on(Vector3(-9, 0, -5), 1.46 * 1.7, 3.7)
	await land_on(Vector3(11, 0, 13), 2.6 * 1.7, 1.7)
	# No second airborne launch or renewed lift after an early release.
	await reset()
	await step(Vector2.ZERO, true, true)
	await step(Vector2.ZERO, false)
	var before := player.velocity.y
	await step(Vector2.ZERO, true, true)
	check(player.velocity.y < before, "airborne re-press cannot relaunch or restore lift")
	await reset()
	var ceiling := StaticBody3D.new()
	var ceiling_collision := CollisionShape3D.new()
	var ceiling_shape := BoxShape3D.new()
	ceiling_shape.size = Vector3(3, 0.25, 3)
	ceiling_collision.shape = ceiling_shape
	ceiling.add_child(ceiling_collision)
	main.add_child(ceiling)
	ceiling.position = Vector3(0, 3, 6)
	await physics_frame
	await step(Vector2.ZERO, true, true)
	var ceiling_hit := false
	for i in 20:
		await step(Vector2.ZERO, true)
		ceiling_hit = ceiling_hit or player.is_on_ceiling()
	check(ceiling_hit and not player._jump_hold_active, "ceiling impact ends lift")
	ceiling.queue_free()
	await process_frame
	player.sprint_toggled = true
	player.apply_damage(1000)
	check(not player.is_sprinting and not player._jump_hold_active, "death clears locomotion intent")
	player.respawn_at(Transform3D.IDENTITY)
	check(not player.is_sprinting and not player._jump_hold_active, "respawn resets locomotion intent")
	# Drain the dummy audio mixer after the final damage cue before teardown.
	player.get_node("CharacterAudio").hit_feedback.stop()
	await create_timer(0.15).timeout
	main.queue_free()
	player = null
	await process_frame
	await process_frame
	if failures.is_empty():
		print("PASS: hybrid sprint, variable jump height, finite lift, real cargo/planter/charger landing, airborne and lifecycle safety")
		quit(0)
	else:
		for failure in failures: push_error("FAIL: " + failure)
		quit(1)

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
