extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var session: Node = root.get_node("LanSession")
	if session.host_lobby("Sam") != OK:
		quit(1)
		return
	session.fill_bots()
	session.set_ready(true)
	session.start_match()
	var arena: Node = load("res://scenes/levels/garden/lan_garden.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var manager: Node = arena.get_node("DuelManager")
	var player: FirstPersonPlayer = arena.get_node("Player")
	player.set_physics_process(false)
	player.weapon.set_physics_process(false)
	for id in manager.actors:
		var actor: Node3D = manager.actors[id]
		if actor is DuelBot: actor.hit_chance = 0.0
	# Camera along the existing ground lane: actual bots route and fight in this view.
	player.global_position = Vector3(15.0, 0.30, 16.0)
	player.rotation.y = 0.65
	player.camera_pivot.rotation.x = -0.05
	var sum_fps := 0.0
	var samples := 0
	var min_fps := 9999.0
	for tick in range(60 * 30):
		await physics_frame
		if tick % 60 == 0 and tick > 180:
			var fps := float(Engine.get_frames_per_second())
			sum_fps += fps
			samples += 1
			min_fps = minf(min_fps, fps)
			print("Native tick=%d FPS=%.1f physicsMS=%.2f processMS=%.2f" % [tick,fps,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0,Performance.get_monitor(Performance.TIME_PROCESS)*1000.0])
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("/Users/samjo/Documents/Codex/2026-10-03/for-2/outputs/3v3 Gameplay.png")
	print("NATIVE_TEAM_PASS 3v3 actors=%d meanFPS=%.1f minSampleFPS=%.1f" % [manager.actors.size(), sum_fps / maxf(samples,1), min_fps])
	session.leave_lobby()
	arena.queue_free()
	await process_frame
	quit()
