extends SceneTree
## Exercises the real UI against a real LAN host session, including slot caps.
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
func run() -> void:
	var session: Node = root.get_node_or_null("LanSession")
	if session == null:
		session = load("res://scenes/network/lan_session.gd").new()
		session.name = "LanSession"
		root.add_child(session)
	var lobby: Control = load("res://scenes/lobby/lobby_screen.tscn").instantiate()
	root.add_child(lobby)
	var background := lobby.get_child(0) as TextureRect
	check(background.texture != null and background.texture.get_width() > 0, "Lobby background must have a usable imported texture")
	check(lobby.hero_portrait.texture != null and lobby.hero_portrait.texture.get_width() > 0, "Lobby portrait must have a usable imported texture")
	check(lobby.auto_fill.get_theme_icon("checked").get_width() > 0, "Lobby fill toggle must have its imported icon")
	lobby.name_input.text = "UI Test Host"
	lobby._host()
	if not session.connected or not session.is_host():
		push_error("Lobby UI test could not acquire LAN port; stop other host tests first")
		quit(1)
		return
	check(lobby.host_button.disabled and lobby.join_button.disabled, "Connected clients cannot host/join a second party")
	check(lobby.team_buttons[0].text == "Your team", "Host starts visibly on Cyan")
	lobby._add_bot(1)
	check(session.team_count(1) == 1 and session.team_count(2) == 1, "UI supports a 1v1 human vs bot")
	lobby._add_bot(0)
	lobby._add_bot(1)
	check(session.team_count(1) == 2 and session.team_count(2) == 2, "UI supports a 2v2 mixed match")
	lobby._fill()
	check(session.roster.size() == 6, "Fill reaches exactly six combatants")
	check(lobby.bot_add_buttons[0].disabled and lobby.bot_add_buttons[1].disabled, "Full teams disable Add bot")
	lobby._add_bot(0)
	check(session.roster.size() == 6, "UI/server retain the 3v3 cap")
	lobby._remove_bot(1)
	check(session.team_count(2) == 2 and not lobby.bot_add_buttons[1].disabled, "Remove bot opens a visible slot")
	lobby._choose_team(1)
	check(session.team_count(1) == 2 and session.team_count(2) == 3, "Human can move to an available team slot")
	check(lobby.team_buttons[1].text == "Your team", "Team choice is reflected in UI")
	lobby._start()
	check(not session.in_match, "Start is guarded until humans ready")
	lobby._toggle_ready()
	check(lobby.ready_button.text == "Ready ✓", "Ready status is reflected in UI")
	lobby._start()
	check(session.in_match, "Ready party can launch a partial 2v3 match")
	session.return_to_lobby()
	check(not session.in_match and not lobby.local_ready, "Return to lobby clears ready status")
	lobby._leave()
	check(not session.connected and not lobby.host_button.disabled, "Leave restores connection controls")
	check(lobby.roster_columns[0].get_child_count() == 3 and lobby.roster_columns[1].get_child_count() == 3, "Empty lobby retains three optional slots per team")
	lobby._host()
	lobby.auto_fill.button_pressed = true
	lobby._toggle_ready()
	lobby._start()
	check(session.in_match and session.roster.size() == 6, "Reference-style fill switch fills before launch")
	session.return_to_lobby()
	lobby._leave()
	lobby.queue_free()
	await process_frame
	if failures.is_empty():
		print("LOBBY_UI_SMOKE_PASS: 1v1, 2v2, 3v3, team move, ready/start, return, leave")
	quit(0 if failures.is_empty() else 1)
