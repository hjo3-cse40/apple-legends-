extends SceneTree
var failures: Array[String] = []
func _init() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	Input.parse_input_event(event)
	await process_frame
func run() -> void:
	var config_path := "user://controls.cfg"
	var had_config := FileAccess.file_exists(config_path)
	var previous := FileAccess.get_file_as_bytes(config_path) if had_config else PackedByteArray()
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var map := main.get_node("MovementLab")
	var player := map.get_node("Player") as FirstPersonPlayer
	var bot := map.get_node("DuelBot") as CharacterBody3D
	var menu := map.get_node("SettingsMenu")
	await key(KEY_F1)
	check(map.opponent_paused and not bot.is_physics_processing(), "F1 must freeze the test bot")
	player.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 18)))
	for i in 30: await physics_frame
	check(player.is_on_floor(), "Player must land on Garden Circuit paving")
	var start := player.position
	Input.action_press("move_forward")
	for i in 60: await physics_frame
	Input.action_release("move_forward")
	check(start.z - player.position.z > 5.5, "Player must walk along the actual arena lane")
	# Imported ramp surfaces must have upward, sloped contact normals.
	var slopes := 0
	for z in range(-9, 10):
		var query := PhysicsRayQueryParameters3D.create(Vector3(6.1, 1.5, z) * map.UNITS_PER_METER, Vector3(6.1, -1, z) * map.UNITS_PER_METER)
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.normal.y > 0.8 and hit.normal.y < 0.999:
			slopes += 1
	check(slopes >= 2, "Gallery ramp collision must follow sloping visual surfaces")
	var wall := PhysicsRayQueryParameters3D.create(Vector3(0, 1.5, 0), Vector3(40, 1.5, 0))
	check(not player.get_world_3d().direct_space_state.intersect_ray(wall).is_empty(), "Arena perimeter/cover must block travel and shots")
	await key(KEY_ESCAPE)
	check(menu.is_open and paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Esc must open settings and pause gameplay")
	var frozen_position := player.position
	for i in 5: await process_frame
	check(player.position.is_equal_approx(frozen_position), "Menu must hold the world still")
	menu.slider.value = 0.55
	check(is_equal_approx(player.mouse_sensitivity, 0.0018 * 0.55), "Sensitivity slider must update player look")
	var config := ConfigFile.new()
	check(config.load(config_path) == OK and is_equal_approx(float(config.get_value("controls", "sensitivity", 0)), player.mouse_sensitivity), "Sensitivity must persist to disk")
	menu.freeze_button.button_pressed = false
	check(not map.opponent_paused and bot.is_physics_processing(), "Menu freeze toggle must control bot processing")
	menu.freeze_button.button_pressed = true
	await key(KEY_ESCAPE)
	check(not menu.is_open and not paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Esc must resume gameplay and capture mouse")
	check(map.opponent_paused and not bot.is_physics_processing(), "Resume must preserve bot freeze")
	menu.open_menu()
	menu.slider.value = 1.0
	menu.close_menu()
	# Check jump and landing against the imported ground, preserving accepted tuning.
	player.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 18)))
	for i in 30: await physics_frame
	start = player.position
	Input.action_press("jump")
	var peak := start.y
	for i in 110:
		await physics_frame
		peak = maxf(peak, player.position.y)
		if i == 20: Input.action_release("jump")
	check(peak > start.y + 2.0, "Accepted jump must work on map")
	for i in 50: await physics_frame
	check(player.is_on_floor(), "Jump must land back on map")
	main.queue_free()
	await process_frame
	if had_config:
		var file := FileAccess.open(config_path, FileAccess.WRITE)
		file.store_buffer(previous)
		file.close()
	else:
		DirAccess.remove_absolute(config_path)
	if failures.is_empty():
		print("PASS: Garden floor, movement, jump/landing, ramps, solid perimeter, F1 bot freeze, Esc pause/resume, sensitivity persistence, freeze toggle")
	quit(0 if failures.is_empty() else 1)
