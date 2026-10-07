extends SceneTree
const DT := 1.0 / 60.0
var failures: Array[String] = []
var player: FirstPersonPlayer
var saved: PackedByteArray
var had_saved := false
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func step(held := false, jump := false) -> void:
	player._jump_held = held
	player._jump_requested = jump
	player._simulate_movement(DT)
	await physics_frame
func ground() -> void:
	player.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)))
	for i in 8: await step()
	check(player.is_on_floor(), "Fixture grounded")
func wheel(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = pressed
	Input.parse_input_event(event)
func jump_measure(hold_frames: int, wheel_jump := false) -> Vector2:
	await ground()
	player.velocity = Vector3(0, 0, -7)
	var start := player.position
	player._movement_input = Vector2(0, -1)
	player._jump_requested_by_wheel = wheel_jump
	await step(hold_frames > 0, true)
	var peak := player.position.y
	for i in 180:
		await step(i < hold_frames)
		peak = maxf(peak, player.position.y)
		if player.is_on_floor(): break
	return Vector2(peak - start.y, absf(player.position.z - start.z))
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://work")
	PlayerInputBindings.save_path = "res://work/input-bindings-test.cfg"
	had_saved = FileAccess.file_exists(PlayerInputBindings.save_path)
	if had_saved: saved = FileAccess.get_file_as_bytes(PlayerInputBindings.save_path)
	PlayerInputBindings.reset()
	check(InputMap.action_get_events(&"jump").size() == 2, "Space and wheel jump defaults coexist")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_J
	check(PlayerInputBindings.set_slot(&"jump", 0, key).is_empty(), "Rebind jump")
	PlayerInputBindings.load_saved()
	check(InputMap.action_get_events(&"jump")[0].physical_keycode == KEY_J, "Saved binding reload")
	check(not PlayerInputBindings.set_slot(&"move_left", 0, key).is_empty(), "Duplicate action binding rejected")
	key.physical_keycode = KEY_ESCAPE
	check(not PlayerInputBindings.set_slot(&"jump", 0, key).is_empty(), "Escape reserved")
	PlayerInputBindings.reset()
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	shape.shape = box
	body.add_child(shape)
	root.add_child(body)
	body.position.y = -0.5
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	await process_frame
	await ground()
	# Native event delivery: press AND release before simulation must survive.
	player._capture_mouse()
	# Full-screen decorative HUD controls can handle wheel events before
	# _unhandled_input; reproduce this through native viewport dispatch.
	var hud_blocker := Control.new()
	hud_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(hud_blocker)
	hud_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_blocker.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton: hud_blocker.accept_event())
	await process_frame
	wheel(true)
	wheel(false)
	await process_frame
	check(player._wheel_jump_pending, "Wheel pulse survives HUD controls before physics sampling")
	hud_blocker.queue_free()
	player._sample_movement_input(DT)
	check(player._jump_requested and not player._jump_held, "Released pulse requests jump without persistent hold")
	player._simulate_movement(DT)
	await physics_frame
	check(player.velocity.y > 10 and player._jump_hold_from_wheel, "Wheel pulse launches full lift")
	player._sample_movement_input(DT)
	check(not player._jump_requested, "Wheel pulse consumed once")
	player._release_mouse()
	check(not player._wheel_jump_pending and not player._jump_hold_from_wheel, "Menu/focus reset clears wheel state")
	wheel(true)
	wheel(false)
	await process_frame
	check(not player._wheel_jump_pending, "Wheel while uncaptured cannot queue a later jump")
	await ground()
	player._capture_mouse()
	for pressed in [true, false]:
		var key_pulse := InputEventKey.new()
		key_pulse.physical_keycode = KEY_SPACE
		key_pulse.pressed = pressed
		Input.parse_input_event(key_pulse)
	await process_frame
	player._sample_movement_input(DT)
	check(player._jump_requested and not player._jump_held, "Fast keyboard tap also latches between physics ticks")
	player._simulate_movement(DT)
	await physics_frame
	check(player.velocity.y > 10 and not player._jump_hold_from_wheel, "Keyboard pulse retains variable release policy")
	var tap := await jump_measure(0)
	var middle := await jump_measure(10)
	var full := await jump_measure(30)
	var scroll := await jump_measure(0, true)
	check(tap.x < middle.x and middle.x < full.x, "Variable release produces distinct jump heights")
	check(absf(scroll.x - full.x) < 0.001, "Scroll gives reproducible full-height jump")
	print("MEASURE jump apex/distance game units: tap=", tap, " 10-frame hold=", middle, " full=", full, " wheel=", scroll)
	# Two real grounded launches. Choose the optimal perpendicular wish direction
	# each physics tick (idealized mouse+A/D), not a human performance claim.
	await ground()
	player.velocity = Vector3(0, 0, -7)
	var speeds: Array[float] = []
	for hop in 2:
		player._movement_input = Vector2(0, -1)
		player._jump_requested_by_wheel = true
		await step(false, true)
		for i in 180:
			var horizontal := Vector3(player.velocity.x, 0, player.velocity.z)
			var wish := Vector3(-horizontal.z, 0, horizontal.x).normalized()
			player.rotation.y = atan2(-wish.z, wish.x)
			player._movement_input = Vector2.RIGHT
			await step()
			if player.is_on_floor(): break
		var speed := Vector2(player.velocity.x, player.velocity.z).length()
		speeds.append(speed)
	check(speeds[0] > 9 and speeds[1] > speeds[0], "Two grounded bhops preserve and build strafe momentum")
	print("MEASURE idealized full-jump air-strafe speed: initial 7, first landing=", speeds[0], " second landing=", speeds[1])
	# Verify real panel capture and return without disturbing the gameplay actions.
	var panel := BindingsPanel.new()
	root.add_child(panel)
	await process_frame
	panel.open_panel()
	if OS.get_cmdline_user_args().has("--screenshot"):
		await process_frame
		await process_frame
		root.get_texture().get_image().save_png("res://work/bindings-panel.png")
	panel.waiting_action = &"reload"
	panel.waiting_slot = 0
	var capture := InputEventKey.new()
	capture.physical_keycode = KEY_T
	capture.pressed = true
	Input.parse_input_event(capture)
	await process_frame
	check(panel.waiting_action == &"" and InputMap.action_get_events(&"reload")[0].physical_keycode == KEY_T, "Panel captures native key event")
	panel.close_panel()
	check(not panel.visible, "Bindings panel returns to settings")
	player.queue_free()
	panel.queue_free()
	await process_frame
	PlayerInputBindings.reset()
	if had_saved:
		var file := FileAccess.open(PlayerInputBindings.save_path, FileAccess.WRITE)
		file.store_buffer(saved)
		file.close()
	else: DirAccess.remove_absolute(PlayerInputBindings.save_path)
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: saved dual bindings, conflicts/reserved keys, actual wheel pulse events, full-height scroll/variable keyboard, lifecycle safety, two-hop momentum and panel key capture")
	quit(0 if failures.is_empty() else 1)
