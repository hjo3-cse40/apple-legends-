extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
func run() -> void:
	var session: Node = root.get_node("LanSession")
	if session.host_lobby("Settings Test") != OK:
		push_error("Settings test could not acquire LAN port; stop other host tests first")
		quit(1)
		return
	session.add_bot(2)
	session.set_ready(true)
	session.start_match()
	var arena: Node = load("res://scenes/levels/garden/lan_garden.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var menu: Node = arena.get_node("SettingsMenu")
	var manager: Node = arena.get_node("DuelManager")
	manager.set_bots_frozen(true)
	menu.open_menu()
	check(menu.is_open and not paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "LAN settings leave match running and release input")
	menu.developer_panel.open_panel(true)
	check(menu.developer_panel.overlay.visible, "Developer tools open")
	for item: Button in menu.developer_panel.authority_buttons:
		check(not item.disabled, "Host can use developer tools")
	menu.developer_panel.action_requested.emit("unfreeze", 0)
	check(not manager.bots_frozen, "Developer tools route resume to all bots")
	menu.developer_panel.action_requested.emit("freeze", 0)
	check(manager.bots_frozen, "Developer tools route freeze to all bots")
	menu.developer_panel.action_requested.emit("bots_off", 0)
	check(not manager.bots_enabled, "Developer tools disable bots")
	menu.developer_panel.action_requested.emit("bots_on", 0)
	check(manager.bots_enabled, "Developer tools enable bots")
	# Simulate respawn recapture while the live round is behind the menu.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await process_frame
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Open settings retain visible mouse after respawn")
	menu.developer_panel.open_panel(false)
	for item: Button in menu.developer_panel.authority_buttons:
		check(item.disabled, "Client developer controls are disabled")
	menu.developer_panel.close_panel()
	menu.close_menu()
	check(not menu.is_open and not paused, "Closing LAN settings leaves the round running")
	if DisplayServer.get_name() != "headless":
		check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Closing LAN settings restores gameplay input")
	arena.queue_free()
	session.leave_lobby()
	await process_frame
	if failures.is_empty(): print("LAN_SETTINGS_PASS: live match, host tools, client restrictions, respawn mouse")
	quit(0 if failures.is_empty() else 1)
