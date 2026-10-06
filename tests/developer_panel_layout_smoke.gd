extends SceneTree

var failures: Array[String] = []

func _init() -> void: call_deferred("run")

func run() -> void:
	var panel := DeveloperPanel.new()
	root.add_child(panel)
	panel.open_panel(false)
	check(panel.tactical_selector.disabled, "Joining peer cannot change host tactical mode")
	panel.open_panel(true)
	check(not panel.tactical_selector.disabled, "Host can select tactical mode")
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		for tick in 5: await process_frame
		var surface := panel.overlay.get_child(1).get_child(0) as Control
		var rect := surface.get_global_rect()
		var logical_size := root.get_visible_rect().size
		check(rect.position.y >= 0 and rect.end.y <= logical_size.y, "Developer surface fits viewport height %s" % dimensions.y)
		check(rect.position.x >= 0 and rect.end.x <= logical_size.x, "Developer surface fits viewport width %s" % dimensions.x)
		print("Developer panel %s: %s" % [dimensions, rect])
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var rendered := root.get_texture().get_image()
			check(rendered.get_size() == dimensions, "Native screenshot renders at requested pixel size")
			rendered.save_png("res://work/developer-panel-%s.png" % dimensions.y)
	panel.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: developer controls fit 720p/1080p")
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
