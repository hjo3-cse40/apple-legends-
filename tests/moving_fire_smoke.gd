extends SceneTree
## Native test: headless cannot capture the mouse. Inject real Godot input events.
var failures: Array[String] = []

func _init() -> void: call_deferred(&"run")

func key(code: Key, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)

func click(pressed: bool, shifted: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.shift_pressed = shifted
	event.position = root.size / 2
	Input.parse_input_event(event)

func run() -> void:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var player := main.get_node("MovementLab/Player") as FirstPersonPlayer
	main.get_node("MovementLab/DuelBot").set_physics_process(false)
	await create_timer(0.3).timeout
	player._capture_mouse()
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "test needs a native window with capture")
	var start := player.position
	var weapon := player.weapon
	# A deliberately blocking UI surface verifies captured combat arrives first.
	var overlay := Control.new()
	overlay.size = root.size
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	main.get_node("MovementLab/DebugHUD").add_child(overlay)
	key(KEY_W, true)
	key(KEY_SHIFT, true)
	await create_timer(0.2).timeout
	var ammo := weapon.ammo_in_magazine
	click(true, true)
	for i in 3: await physics_frame
	check(weapon.ammo_in_magazine == ammo - 1, "Shift + W + mouse click fires through HUD")
	check(player.position.distance_to(start) > 0.5, "movement continues during firing")
	check(Vector2(player.velocity.x, player.velocity.z).length() > player.walk_speed, "sprint continues during firing")
	click(false, true)
	await create_timer(0.22).timeout
	ammo = weapon.ammo_in_magazine
	key(KEY_V, true)
	for i in 3: await physics_frame
	check(weapon.ammo_in_magazine == ammo - 1, "V fallback fires while moving")
	await create_timer(0.22).timeout
	key(KEY_V, true, true)
	for i in 3: await physics_frame
	check(weapon.ammo_in_magazine == ammo - 1, "keyboard repeat does not auto-fire the semi-auto rifle")
	key(KEY_V, false)
	key(KEY_W, false)
	key(KEY_SHIFT, false)
	overlay.queue_free()
	await process_frame
	player._release_mouse()
	ammo = weapon.ammo_in_magazine
	click(true)
	for i in 3: await physics_frame
	check(weapon.ammo_in_magazine == ammo, "cursor recapture click does not fire")
	click(false)
	main.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: native moving/sprinting mouse fire, blocking HUD, V fallback, key-repeat and recapture safety")
		quit(0)
	else:
		for failure in failures: push_error("FAIL: " + failure)
		quit(1)

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
