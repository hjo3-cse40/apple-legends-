extends SceneTree
var failures: Array[String] = []
var player: FirstPersonPlayer
var bound_wheel := MOUSE_BUTTON_WHEEL_DOWN
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok: failures.append(message)
func pulse(button: int) -> void:
 for pressed in [true, false]:
  var e := InputEventMouseButton.new()
  e.button_index = button
  e.pressed = pressed
  e.position = root.get_visible_rect().size / 2
  Input.parse_input_event(e)
func run() -> void:
 var session := root.get_node("LanSession")
 check(session.host_lobby("Wheel regression") == OK, "Host session")
 session.add_bot(2)
 session.set_ready(true)
 session.start_match()
 var arena := load("res://scenes/levels/garden/lan_garden.tscn").instantiate() as Node3D
 root.add_child(arena)
 await process_frame
 var manager := arena.get_node("DuelManager") as TeamMatchManager
 manager.set_bots_frozen(true)
 player = manager.player
 for i in 20: await physics_frame
 check(player.is_on_floor(), "Player grounded on actual spawn")
 check(player.is_processing_input(), "Player _input active in full match")
 var label: Label = root.get_node("BuildInfo/VersionLabel")
 var expected := "v%s  •  build %s" % [ProjectSettings.get_setting("application/config/version"), ProjectSettings.get_setting("application/config/build")]
 check(label.text == expected, "Visible exact patch/build label")
 check(label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Build label cannot consume wheel input")
 print("MATCH_BEFORE y=",player.position.y," mode=",Input.mouse_mode," bindings=",InputMap.action_get_events(&"jump"))
 for binding in InputMap.action_get_events(&"jump"):
  if binding is InputEventMouseButton and binding.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
   bound_wheel = binding.button_index
   break
 var start := player.position.y
 pulse(bound_wheel)
 for i in 10: await physics_frame
 check(player.position.y > start + 0.5, "Saved wheel binding lifts player in actual LAN match")
 check(player.wheel_jump_requests == 1 and player.wheel_jump_launches == 1, "One wheel pulse produces exactly one launch")
 print("MATCH_AFTER y=",player.position.y," vy=",player.velocity.y," requests=",player.wheel_jump_requests," launches=",player.wheel_jump_launches)
 for i in 160: await physics_frame
 var settings := arena.get_node("SettingsMenu")
 settings.open_menu()
 pulse(bound_wheel)
 for i in 3: await process_frame
 check(player.wheel_jump_requests == 1, "Menu wheel does not queue jump")
 settings.close_menu()
 for i in 3: await physics_frame
 check(player.wheel_jump_launches == 1, "Closing settings does not trigger queued jump")
 pulse(bound_wheel)
 for i in 10: await physics_frame
 check(player.wheel_jump_launches == 2, "Wheel jump works after closing settings")
 settings.open_menu()
 settings.developer_panel.open_panel()
 check(settings.developer_panel.input_status.text.contains("2 launches"), "Developer panel reports actual input/launch counts")
 settings.developer_panel.close_panel()
 settings.close_menu()
 arena.queue_free()
 session.leave_lobby()
 await process_frame
 for failure in failures: push_error(failure)
 if failures.is_empty(): print("PASS: full LAN scene saved wheel launch, HUD, settings round-trip, exact visible version, input diagnostics")
 quit(0 if failures.is_empty() else 1)
