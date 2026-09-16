extends SceneTree

const START := Vector3(0.0, 0.4, 13.0)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var main_scene := load("res://scenes/main/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame

	var player := main.get_node("MovementLab/Player") as FirstPersonPlayer
	for _step in 12:
		await physics_frame
	_check(player.is_on_floor(), "player should settle on the collision floor")
	player.set_physics_process(false)

	var cardinal_distance := await _measure_travel(player, [&"move_forward"])
	var diagonal_distance := await _measure_travel(player, [&"move_forward", &"move_right"])
	_check(cardinal_distance > 5.0, "forward input should move the player")
	_check(absf(cardinal_distance - diagonal_distance) / cardinal_distance < 0.02, "diagonal travel should be normalized")

	_reset_player(player)
	for _step in 3:
		await physics_frame
	player._jump_requested = true
	player._simulate_movement(1.0 / 60.0)
	await physics_frame
	player._jump_requested = false
	var highest_y := player.position.y
	for _step in 100:
		player._simulate_movement(1.0 / 60.0)
		await physics_frame
		highest_y = maxf(highest_y, player.position.y)
	_check(highest_y > 1.2, "jump should lift the player")
	_check(player.is_on_floor(), "player should land after jumping")

	player.position = Vector3(12.0, 0.2, 0.0)
	player.velocity = Vector3.ZERO
	player._movement_input = Vector2.RIGHT
	for _step in 120:
		player._simulate_movement(1.0 / 60.0)
		await physics_frame
	_check(player.position.x < 13.8, "canyon boundary should stop horizontal movement")

	player.rotation = Vector3.ZERO
	player.camera_pivot.rotation = Vector3.ZERO
	player._apply_look_delta(Vector2(100.0, -100.0))
	_check(player.rotation.y < -0.1, "horizontal mouse input should yaw the player")
	_check(player.camera_pivot.rotation.x > 0.1, "vertical mouse input should pitch the camera")
	player._apply_look_delta(Vector2(0.0, -100000.0))
	_check(player.camera_pivot.rotation.x <= deg_to_rad(player.maximum_pitch_degrees) + 0.0001, "camera pitch should remain clamped")

	if _failures.is_empty():
		print("PASS: movement, normalization, jump/landing, floor/wall collision, and clamped look")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)


func _measure_travel(player: FirstPersonPlayer, actions: Array[StringName]) -> float:
	_reset_player(player)
	for _step in 3:
		player._movement_input = Vector2.ZERO
		player._simulate_movement(1.0 / 60.0)
		await physics_frame
	var start_position := Vector2(player.position.x, player.position.z)
	for action in actions:
		Input.action_press(action)
	for _step in 90:
		player._movement_input = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
		player._simulate_movement(1.0 / 60.0)
		await physics_frame
	for action in actions:
		Input.action_release(action)
	var end_position := Vector2(player.position.x, player.position.z)
	return start_position.distance_to(end_position)


func _reset_player(player: FirstPersonPlayer) -> void:
	Input.action_release(&"move_forward")
	Input.action_release(&"move_back")
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	Input.action_release(&"jump")
	Input.action_release(&"sprint")
	player.position = START
	player.velocity = Vector3.ZERO
	player._movement_input = Vector2.ZERO
	player._jump_requested = false


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
