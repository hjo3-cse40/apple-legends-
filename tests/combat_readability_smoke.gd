extends SceneTree
var failures: Array[String] = []
var cues: Array[String] = []

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run() -> void:
	var main := (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var arena := main.get_node("MovementLab")
	var manager := arena.get_node("DuelManager") as KothManager
	var player := manager.player
	var bot := manager.bot as DuelBot
	var weapon := player.weapon
	var enemy_hud := manager.enemy_health_hud
	manager.set_physics_process(false)
	player.set_physics_process(false)
	bot.set_physics_process(false)
	weapon.set_physics_process(false)
	player.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0, 200, 0)))
	bot.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0, 200, -12)))
	await physics_frame
	await physics_frame
	enemy_hud.update_visibility()
	check(enemy_hud.panel.visible and enemy_hud.bar.value == 100, "visible enemy shows full health")
	weapon.enable_fire_sound = false
	var shots := 0
	var elapsed := 0.0
	while bot.is_alive and shots < 10:
		weapon._cooldown_remaining = 0.0
		weapon._try_fire()
		shots += 1
		if shots > 1:
			elapsed += weapon.seconds_between_shots
		enemy_hud.update_visibility()
		if bot.is_alive:
			check(is_equal_approx(enemy_hud.bar.value, bot.current_health), "bar tracks actual hits")
	check(shots == 5 and is_equal_approx(elapsed, 0.88), "five actual hits give 0.88 second ideal TTK")
	check(not enemy_hud.panel.visible, "dead enemy bar hides")
	manager.bot_respawn_timer.stop()
	bot.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0, 200, -12)))
	await physics_frame
	enemy_hud.update_visibility()
	check(enemy_hud.panel.visible and enemy_hud.bar.value == 100, "respawn restores full bar")
	var blocker := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 5, 1)
	shape.shape = box
	blocker.add_child(shape)
	blocker.position = Vector3(0, 201.5, -6)
	main.add_child(blocker)
	await physics_frame
	await physics_frame
	enemy_hud.update_visibility()
	check(not enemy_hud.panel.visible, "wall hides enemy health")
	blocker.queue_free()
	await physics_frame
	bot.position.z = 12
	enemy_hud.update_visibility()
	check(not enemy_hud.panel.visible, "enemy behind camera hides health")
	bot.position.z = -12
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var aim_press := InputEventMouseButton.new()
	aim_press.button_index = MOUSE_BUTTON_RIGHT
	aim_press.pressed = true
	weapon._input(aim_press)
	for tick in 60:
		weapon._update_feedback(1.0 / 60)
	if DisplayServer.get_name() != "headless":
		check(absf(player.camera.fov - 58) < 0.05, "ADS blends to noticeable 58 degree zoom")
	var aim_release := InputEventMouseButton.new()
	aim_release.button_index = MOUSE_BUTTON_RIGHT
	weapon._input(aim_release)
	for tick in 60:
		weapon._update_feedback(1.0 / 60)
	check(absf(player.camera.fov - 80) < 0.05, "releasing ADS returns to hip FOV")
	player.apply_damage(100)
	enemy_hud.update_visibility()
	check(not enemy_hud.panel.visible, "dead viewer cannot see enemy health")
	manager.player_respawn_timer.stop()
	player.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0, 200, 0)))
	var audio := manager.objective_audio
	audio.cue_requested.connect(func(key: String, _caption: String): cues.append(key))
	var rules := manager.rules
	rules.unlock_duration = 0
	for team in [KothRules.CYAN, KothRules.AMBER]:
		for round_index in 8:
			rules.reset_match()
			audio.reset_round(rules.get_snapshot())
			cues.clear()
			rules.advance(12, 1 if team == 1 else 0, 1 if team == 2 else 0)
			audio.observe(rules.get_snapshot(), 12)
			check(cues == ["capture_cyan" if team == 1 else "capture_amber"], "one global capture callout")
			rules.advance(150, 0, 0)
			audio.observe(rules.get_snapshot(), 150)
			check(cues[-1] == ("cyan_30" if team == 1 else "amber_30"), "30 second warning identifies team")
			var count_before := cues.size()
			rules.advance(60, 1, 1)
			audio.observe(rules.get_snapshot(), 60)
			check(cues.size() == count_before + 1 and cues[-1] == "contest", "contest pauses countdown without repeated threshold")
			for tick in 120:
				audio.observe(rules.get_snapshot(), 1.0 / 60)
			check(cues.size() == count_before + 1, "held contest does not spam cues")
			rules.advance(20, 0, 0)
			audio.observe(rules.get_snapshot(), 20)
			check(cues[-1] == ("cyan_10" if team == 1 else "amber_10"), "10 second warning")
			for tick in 9:
				rules.advance(1, 0, 0)
				audio.observe(rules.get_snapshot(), 1)
			check(cues.slice(-5) == ["five", "four", "three", "two", "one"], "global final five countdown exactly once")
			rules.advance(1, 0 if team == 1 else 1, 1 if team == 1 else 0)
			audio.observe(rules.get_snapshot(), 1)
			check(cues[-1] == "overtime" and rules.overtime, "overtime interrupts final countdown")
			rules.advance(10, 1, 1)
			audio.observe(rules.get_snapshot(), 10)
			check(cues.count("overtime") == 1, "held overtime announced once")
			rules.advance(0, 0, 0)
			audio.observe(rules.get_snapshot(), 0)
			check(not audio.voice.playing and manager.match_over, "win stops stale countdown voice")
			manager.restart_match()
			check(not (arena.get_node("KothHUD") as KothHUD).announcement.visible, "restart clears old announcement")
			manager.set_physics_process(false)
			player.set_physics_process(false)
			bot.set_physics_process(false)
			weapon.set_physics_process(false)
	# Recapture retains a team's warnings; the other team gets its own warning.
	rules.reset_match()
	audio.reset_round(rules.get_snapshot())
	cues.clear()
	for step in [[12,1,0], [150,0,0], [12,0,1], [150,0,0], [12,1,0]]:
		rules.advance(step[0], step[1], step[2])
		audio.observe(rules.get_snapshot(), step[0])
	check(cues.count("cyan_30") == 1 and cues.count("amber_30") == 1, "recaptures preserve independent warning history")
	check(audio.voice is AudioStreamPlayer and audio.chime is AudioStreamPlayer, "objective sounds are map-wide non-spatial players")
	for stream in audio._streams.values():
		check(stream is AudioStreamWAV and stream.get_length() > 0, "all portable callout assets load")
	if DisplayServer.get_name() != "headless":
		manager.restart_match()
		manager.set_physics_process(false)
		player.set_physics_process(false)
		bot.set_physics_process(false)
		weapon.set_physics_process(false)
		player.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.08, 18)))
		bot.respawn_at(Transform3D(Basis.IDENTITY, Vector3(0, 0.08, 6)))
		bot.apply_damage(44)
		for aiming in [false, true]:
			weapon.set_aiming(aiming)
			for tick in 60:
				weapon._update_feedback(1.0/60)
			for frame in 8:
				await process_frame
			enemy_hud.update_visibility()
			check(enemy_hud.panel.visible, "native garden enemy health visible in hip and ADS")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/Users/samjo/Documents/Codex/2026-10-03/focus-on-core-gameplay-first-then-2/outputs/%s.png" % ("ads-health" if aiming else "hip-health"))
	# Let transient impact timers release their bound references before shutdown.
	await create_timer(0.4).timeout
	for sound in main.find_children("*", "AudioStreamPlayer", true, false):
		(sound as AudioStreamPlayer).stop()
	for sound in main.find_children("*", "AudioStreamPlayer3D", true, false):
		(sound as AudioStreamPlayer3D).stop()
	main.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: actual five-hit TTK, LOS health/death/respawn, ADS, 16 audio rounds, contest, overtime, recapture and portable global assets")
	quit(0 if failures.is_empty() else 1)
