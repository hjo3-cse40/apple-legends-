extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var main_scene := load("res://scenes/main/main.tscn") as PackedScene
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame

	var level := main.get_node("MovementLab")
	var player := level.get_node("Player") as FirstPersonPlayer
	var bot := level.get_node("DuelBot") as DuelBot
	var hud := level.get_node("DebugHUD") as DebugHUD
	bot.set_physics_process(false)
	player.rotation = Vector3.ZERO
	player.camera_pivot.rotation = Vector3.ZERO
	await process_frame

	var origin := player.global_position
	var east := hud.direction_to_indicator_offset(origin + Vector3.RIGHT * 10.0)
	var west := hud.direction_to_indicator_offset(origin + Vector3.LEFT * 10.0)
	var front := hud.direction_to_indicator_offset(origin + Vector3.FORWARD * 10.0)
	var behind := hud.direction_to_indicator_offset(origin + Vector3.BACK * 10.0)
	_check(east.x > 90.0 and absf(east.y) < 0.01, "east/right damage should place the mark on the right")
	_check(west.x < -90.0 and absf(west.y) < 0.01, "west/left damage should place the mark on the left")
	_check(front.y < -90.0 and absf(front.x) < 0.01, "front damage should place the mark above the crosshair")
	_check(behind.y > 90.0 and absf(behind.x) < 0.01, "rear damage should place the mark below the crosshair")
	_check(is_equal_approx(east.length(), hud.damage_indicator_radius), "indicator should remain on its configured compact radius")

	player.rotate_y(deg_to_rad(63.0))
	await process_frame
	var camera_forward := -player.camera.global_basis.z
	camera_forward.y = 0.0
	var camera_right := player.camera.global_basis.x
	camera_right.y = 0.0
	var rotated_front := hud.direction_to_indicator_offset(player.global_position + camera_forward.normalized() * 10.0)
	var rotated_right := hud.direction_to_indicator_offset(player.global_position + camera_right.normalized() * 10.0)
	_check(rotated_front.y < -90.0 and absf(rotated_front.x) < 0.01, "indicator should stay camera-relative after yaw")
	_check(rotated_right.x > 90.0 and absf(rotated_right.y) < 0.01, "camera-right damage should remain on screen-right after yaw")

	player.rotation = Vector3.ZERO
	await process_frame
	player._movement_input = Vector2(0.4, -0.8)
	var movement_before := player._movement_input
	_check(player.apply_damage(5.0, player.global_position + Vector3.RIGHT * 8.0), "directional damage should be accepted")
	_check(player._movement_input == movement_before, "damage indication must not modify movement input")
	_check(hud.damage_indicator.visible, "directional damage should show the compact mark immediately")
	_check(hud.damage_indicator.position.x > 0.0, "east/right source should display the live mark on the right")
	_check(hud.damage_indicator.mouse_filter == Control.MOUSE_FILTER_IGNORE, "damage mark must never intercept input")

	hud._process(hud.damage_indicator_duration + 0.01)
	_check(not hud.damage_indicator.visible, "damage mark should fade away after its short duration")

	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("PASS: cardinal and rotated hit direction, compact placement, input safety, and fade")
		quit(0)
	else:
		for failure in _failures:
			push_error("FAIL: " + failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
