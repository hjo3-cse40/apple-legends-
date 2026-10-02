extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("run")

func press_key(bay: Node, key: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	bay._unhandled_input(event)

func run() -> void:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var bay := main.get_node("MovementLab")
	var player := bay.get_node("Player") as FirstPersonPlayer
	var bot := bay.get_node("DuelBot") as DuelBot
	check(bay.get_node_or_null("DisplayRobot") != null, "inspection chassis exists")
	check(bay.robot_visual.get_node_or_null("MiniBot/Helmet") != null, "Blender helmet imported")
	check(not bot.get_node("Visuals/Body").visible, "old bot mesh hidden")
	check(player.weapon.model_root.find_child("PowerWindow", true, false) != null, "rifle model integrated")
	press_key(bay, KEY_F1)
	check(not bot.is_physics_processing() and bay.opponent_paused, "inspection mode disables opponent shooting")
	for i in 12: await physics_frame
	check(player.is_on_floor(), "player settles on calibration floor")
	player.set_physics_process(false)
	press_key(bay, KEY_F2)
	check(is_equal_approx(player.field_of_view, 58.7155), "reference FOV converts horizontal to vertical")
	press_key(bay, KEY_F2)
	check(is_equal_approx(player.field_of_view, 80.0), "baseline FOV restored")
	check(is_equal_approx(player.weapon.ads_field_of_view, 67.0), "baseline ADS restored")
	press_key(bay, KEY_F3)
	check(bay.get_node("DebugHUD/ReadoutPanel").visible, "debug toggle works")
	# Actual hitscan must reach the damageable bot through the new visual layer.
	player.position = Vector3(0, 0, 6)
	player.rotation = Vector3.ZERO
	player.camera_pivot.rotation = Vector3.ZERO
	bot.position = Vector3(0, 0, 0)
	player.weapon.request_fire()
	for i in 3: await physics_frame
	check(bot.current_health < bot.maximum_health, "new robot remains hittable")
	press_key(bay, KEY_F1)
	check(bot.is_physics_processing(), "duel resumes")
	if failures.is_empty():
		print("PASS: calibration import, floor, bot hit, inspect toggle, FOV/ADS restore, diagnostics")
		quit(0)
	else:
		for failure in failures: push_error("FAIL: " + failure)
		quit(1)

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
